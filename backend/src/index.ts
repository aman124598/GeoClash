import 'dotenv/config';
import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import { auth } from './auth';
import { toNodeHandler } from "better-auth/node";
import { latLngToCell } from 'h3-js';
import { db } from './db';
import { tiles, users, tileEvents } from './db/schema';
import { eq, sql, and, asc } from 'drizzle-orm';
import { activeTrails } from './db/schema';
import * as h3 from 'h3-js';

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: '*', // For dev
  }
});

app.use(cors());
app.use(express.json());

// Better Auth routes
app.use("/api/auth", toNodeHandler(auth));

app.get('/', (req, res) => {
  res.send('GeoClash API Running');
});

// Get tiles by H3 indexes
app.post('/api/tiles', async (req, res) => {
  try {
    const { h3Indexes } = req.body;
    if (!Array.isArray(h3Indexes) || h3Indexes.length === 0) {
      return res.status(400).json({ error: 'Missing or empty h3Indexes array' });
    }
    
    // Fetch from Neon DB
    // Limit to 500 max array to prevent abuse
    const limitedIndexes = h3Indexes.slice(0, 500);
    // Drizzle requires `inArray`
    const { inArray } = await import('drizzle-orm');
    const result = await db.select().from(tiles).where(inArray(tiles.h3Index, limitedIndexes)).execute();
    
    res.json({ success: true, tiles: result });
  } catch(err: any) {
    console.error('Error fetching tiles:', err);
    res.status(500).json({ error: err.message });
  }
});

// Leaderboard endpoint
app.get('/api/leaderboard', async (req, res) => {
  try {
    // Get top 50 users by totalTiles
    const { desc } = await import('drizzle-orm');
    const topUsers = await db.select({
      id: users.id,
      name: users.name,
      totalTiles: users.totalTiles,
      color: users.color,
    }).from(users).orderBy(desc(users.totalTiles)).limit(50).execute();
    
    res.json({ success: true, leaderboard: topUsers });
  } catch(err: any) {
    console.error('Error fetching leaderboard:', err);
    res.status(500).json({ error: err.message });
  }
});

// Capture endpoint
app.post('/api/capture', async (req, res) => {
  try {
    const session = await auth.api.getSession({
      headers: req.headers,
    });
    if (!session) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { lat, lng, speed, accuracy } = req.body;
    if (!lat || !lng) {
      return res.status(400).json({ error: 'Missing lat or lng' });
    }

    // ANTI-CHEAT CHECKS
    // 1. Accuracy must be reasonable (e.g. better than 50 meters)
    if (accuracy && accuracy > 50) {
      return res.status(400).json({ error: 'GPS accuracy too low' });
    }
    // 2. Speed limiting (running/walking maxes out around 8-10 m/s ~ 36 km/h max for sprinters)
    // If a user is in a car, they are moving > 10 m/s usually.
    if (speed && speed > 10) {
       return res.status(400).json({ error: 'Moving too fast (vehicle detected)' });
    }

    const userId = session.user.id;
    const h3Index = h3.latLngToCell(lat, lng, 10);

    // 1. Check if this completes a loop
    const existingTrail = await db.select()
      .from(activeTrails)
      .where(eq(activeTrails.userId, userId))
      .orderBy(asc(activeTrails.id))
      .execute();

    const loopStartIndex = existingTrail.findIndex(t => t.h3Index === h3Index);

    if (loopStartIndex !== -1) {
      // LOOP DETECTED!
      const loop = existingTrail.slice(loopStartIndex);
      // Add the current point to close it visually if needed, though polygonToCells handles it
      
      // Convert hex centers to [lat, lng] for polygon filling
      const polygonCoords = loop.map(t => h3.cellToLatLng(t.h3Index));
      // Ensure it's a closed loop for the library
      polygonCoords.push(h3.cellToLatLng(h3Index));

      // Get all cells inside the perimeter
      const filledHexes = h3.polygonToCells(polygonCoords, 10);
      
      // Bulk update/insert into tiles
      if (filledHexes.length > 0) {
        // Limit to 1000 for safety as per plan
        const safeHexes = filledHexes.slice(0, 1000);
        
        await db.transaction(async (tx) => {
           // Insert/Update tiles
           for (const hex of safeHexes) {
             await tx.insert(tiles).values({
               h3Index: hex,
               ownerId: userId,
               strength: 100,
               capturedAt: new Date(),
             }).onConflictDoUpdate({
               target: tiles.h3Index,
               set: { ownerId: userId, strength: 100, lastUpdatedAt: new Date() }
             });
           }
           // Clear trail
           await tx.delete(activeTrails).where(eq(activeTrails.userId, userId));
        });

        // Broadcast capture
        io.emit('territory_captured', {
          userId,
          hexes: safeHexes,
          color: (await db.select({ color: users.color }).from(users).where(eq(users.id, userId)).limit(1).execute())[0]?.color
        });
      }

      return res.json({ success: true, mode: 'capture_completed', hexCount: filledHexes.length });
    } else {
      // No loop, just add to trail
      await db.insert(activeTrails).values({
        userId,
        h3Index,
      }).execute();

      // Emit trail update for real-time path marking
      io.emit('trail_update', {
        userId,
        h3Index,
        lat,
        lng
      });

      // Also do a simple singular tile capture/attack as baseline
      // (This ensures tiles they walk on are captured even if no loop is closed)
      const existingTile = await db.select().from(tiles).where(eq(tiles.h3Index, h3Index)).execute();
      
      if (existingTile.length === 0) {
        await db.insert(tiles).values({ h3Index, ownerId: userId, strength: 100 }).onConflictDoNothing();
        io.emit('tile_update', { h3Index, ownerId: userId, strength: 100 });
      } else if (existingTile[0].ownerId !== userId) {
        // Simple attack logic (15 points per tick)
        const newStrength = Math.max(0, (existingTile[0].strength ?? 100) - 15);
        if (newStrength === 0) {
           await db.update(tiles).set({ ownerId: userId, strength: 100 }).where(eq(tiles.h3Index, h3Index));
           io.emit('tile_update', { h3Index, ownerId: userId, strength: 100 });
        } else {
           await db.update(tiles).set({ strength: newStrength }).where(eq(tiles.h3Index, h3Index));
           io.emit('tile_update', { h3Index, ownerId: existingTile[0].ownerId, strength: newStrength });
        }
      }

      res.json({ success: true, mode: 'trail_extended', h3Index });
    }
  } catch (err: any) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

// Socket logic
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);
  // Join specific regional rooms here later
  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
  });
});

const PORT = process.env.PORT || 3000;
httpServer.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
