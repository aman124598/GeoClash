import { neon } from '@neondatabase/serverless';
import * as dotenv from 'dotenv';
dotenv.config();

async function fix() {
  const sql = neon(process.env.DATABASE_URL!);
  console.log('--- DB FIX START (Tagged Template) ---');
  try {
    // Correct usage for newer @neondatabase/serverless
    await sql`ALTER TABLE "users" DROP COLUMN IF EXISTS "emailVerified" CASCADE`;
    console.log('Drop column done.');
    
    await sql`ALTER TABLE "users" ADD COLUMN "emailVerified" boolean NOT NULL DEFAULT false`;
    console.log('Add column boolean done.');
    
    // Reset sessions to clear any weird cached types
    await sql`DROP TABLE IF EXISTS sessions CASCADE`;
    console.log('Sessions reset done.');
    
    console.log('--- DB FIX SUCCESS ---');
  } catch (e) {
    console.error('CRITICAL ERROR:', e);
  }
}

fix();
