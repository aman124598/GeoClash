import { neon } from '@neondatabase/serverless';
import * as dotenv from 'dotenv';
dotenv.config();

async function aggressiveFix() {
  const sql = neon(process.env.DATABASE_URL!);
  console.log('--- AGGRESSIVE DATABASE RESET ---');
  
  try {
    // 1. Drop all tables that might have Better Auth metadata or GeoClash data
    // This ensures a clean slate with the new Drizzle schema types.
    console.log('Dropping existing tables...');
    
    // Ordered by dependencies
    const tables = [
      'active_trails',
      'tile_events',
      'tiles',
      'sessions',
      'accounts',
      'verifications',
      'users'
    ];

    for (const table of tables) {
      console.log(`Dropping table: ${table}`);
      await sql(`DROP TABLE IF EXISTS "${table}" CASCADE`);
    }

    console.log('--- SUCCESS ---');
    console.log('All auth and game tables have been dropped.');
    console.log('Better Auth will recreate them with the correct types (boolean for emailVerified) on the next restart.');
    
  } catch (e) {
    console.error('Critical Error during DB Reset:', e);
    process.exit(1);
  }
}

aggressiveFix();
