CREATE TABLE `records` (`id` text PRIMARY KEY NOT NULL, `entity` text NOT NULL, `agency_id` text NOT NULL, `payload` text NOT NULL);
--> statement-breakpoint
CREATE INDEX `records_entity_agency` ON `records` (`entity`,`agency_id`);
--> statement-breakpoint
CREATE TABLE `site_owner` (`slot` integer PRIMARY KEY NOT NULL, `user_id` text NOT NULL);
