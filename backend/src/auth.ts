import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { db } from "./db";
import * as schema from "./db/schema";
import { dash } from "@better-auth/infra";
import { bearer } from "better-auth/plugins";

export const auth = betterAuth({
    database: drizzleAdapter(db, {
        provider: "pg", // use 'pg' for postgres
        schema: {
            user: schema.users,
            session: schema.sessions,
            account: schema.accounts,
            verification: schema.verifications,
        }
    }),
    emailAndPassword: {
        enabled: true,
    },
    plugins: [
        dash(),
        bearer(),
    ],
    baseURL: process.env.BETTER_AUTH_URL || "https://geoclash.onrender.com",
    trustedOrigins: [
        "http://localhost:*", 
        "http://127.0.0.1:*",
        "https://geoclash.onrender.com",
        "https://*.geoclash.onrender.com",
        "capacitor://*", // For mobile-like origins
        "http://localhost" // Android emulator
    ],
    advanced: {
        disableCSRFCheck: true // Essential for mobile app requests
    }
});
