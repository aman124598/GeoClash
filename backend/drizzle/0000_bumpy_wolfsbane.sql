CREATE TABLE "accounts" (
	"id" text PRIMARY KEY NOT NULL,
	"accountId" text NOT NULL,
	"providerId" text NOT NULL,
	"userId" text NOT NULL,
	"accessToken" text,
	"refreshToken" text,
	"idToken" text,
	"accessTokenExpiresAt" timestamp,
	"refreshTokenExpiresAt" timestamp,
	"scope" text,
	"password" text,
	"createdAt" timestamp NOT NULL,
	"updatedAt" timestamp NOT NULL
);
--> statement-breakpoint
CREATE TABLE "active_trails" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "active_trails_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"user_id" text NOT NULL,
	"h3_index" text NOT NULL,
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "daily_stats" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "daily_stats_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"user_id" text NOT NULL,
	"date" date NOT NULL,
	"tiles_captured" integer DEFAULT 0,
	"distance_traveled" real DEFAULT 0,
	"steps" integer DEFAULT 0,
	"updated_at" timestamp DEFAULT now(),
	CONSTRAINT "unique_user_date" UNIQUE("user_id","date")
);
--> statement-breakpoint
CREATE TABLE "sessions" (
	"id" text PRIMARY KEY NOT NULL,
	"expiresAt" timestamp NOT NULL,
	"token" text NOT NULL,
	"createdAt" timestamp NOT NULL,
	"updatedAt" timestamp NOT NULL,
	"ipAddress" text,
	"userAgent" text,
	"userId" text NOT NULL,
	CONSTRAINT "sessions_token_unique" UNIQUE("token")
);
--> statement-breakpoint
CREATE TABLE "tile_events" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "tile_events_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"h3_index" text NOT NULL,
	"actor_id" text,
	"previous_owner_id" text,
	"event_type" text NOT NULL,
	"strength_delta" integer,
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "tiles" (
	"h3_index" text PRIMARY KEY NOT NULL,
	"owner_id" text,
	"strength" integer DEFAULT 100,
	"captured_at" timestamp,
	"last_updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"email" text NOT NULL,
	"emailVerified" boolean DEFAULT false NOT NULL,
	"image" text,
	"createdAt" timestamp NOT NULL,
	"updatedAt" timestamp NOT NULL,
	"color" text DEFAULT '#FF6B6B',
	"totalTiles" integer DEFAULT 0,
	"totalDistance" real DEFAULT 0,
	"totalSteps" integer DEFAULT 0,
	"currentStreak" integer DEFAULT 0,
	"longestStreak" integer DEFAULT 0,
	"lastActiveAt" timestamp,
	"last_lat" real,
	"last_lng" real,
	CONSTRAINT "users_email_unique" UNIQUE("email")
);
--> statement-breakpoint
CREATE TABLE "verifications" (
	"id" text PRIMARY KEY NOT NULL,
	"identifier" text NOT NULL,
	"value" text NOT NULL,
	"expiresAt" timestamp NOT NULL,
	"createdAt" timestamp NOT NULL,
	"updatedAt" timestamp NOT NULL
);
--> statement-breakpoint
ALTER TABLE "accounts" ADD CONSTRAINT "accounts_userId_users_id_fk" FOREIGN KEY ("userId") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "active_trails" ADD CONSTRAINT "active_trails_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "daily_stats" ADD CONSTRAINT "daily_stats_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_userId_users_id_fk" FOREIGN KEY ("userId") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tile_events" ADD CONSTRAINT "tile_events_actor_id_users_id_fk" FOREIGN KEY ("actor_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tiles" ADD CONSTRAINT "tiles_owner_id_users_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "active_trail_user_h3_idx" ON "active_trails" USING btree ("user_id","h3_index");--> statement-breakpoint
CREATE INDEX "active_trail_user_order_idx" ON "active_trails" USING btree ("user_id","id");--> statement-breakpoint
CREATE INDEX "daily_user_date_idx" ON "daily_stats" USING btree ("user_id","date");--> statement-breakpoint
CREATE INDEX "event_h3_idx" ON "tile_events" USING btree ("h3_index");--> statement-breakpoint
CREATE INDEX "event_actor_idx" ON "tile_events" USING btree ("actor_id");--> statement-breakpoint
CREATE INDEX "tile_owner_idx" ON "tiles" USING btree ("owner_id");