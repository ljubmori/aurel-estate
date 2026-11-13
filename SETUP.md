# AUREL Estate — Sites edition

This edition uses React, TypeScript and Vite with a Sites Worker, D1 database and R2 file storage. ChatGPT sign-in replaces Supabase passwords. The original Supabase schema remains in supabase/ as an alternative, not the active production database.

## First use
Open the deployed Site with the owner's ChatGPT account, then open /admin. The first owner API request initializes five fictional sample properties. The known owner's verified identity is bound once to the Site-specific user ID; server authorization uses that ID thereafter. Other users cannot edit, upload, read inquiries or confirm viewings. The Site stays owner-private by default.

## Content management
Properties → Add property → required details → images → choose Draft or Published → Save. JPEG, PNG and WebP uploads up to 10 MB are validated on the server and stored in R2. The first image is the cover; arrows reorder images. Changes persist in D1. Draft, Pending, Unpublished, Sold and Rented listings are excluded from public results. Drafts have a private content preview. Refresh public pages after saving. Delete requires confirmation. Removing an image detaches it; originals remain in storage.

Agents and Website settings are editable. Requests are saved as new; viewing requests are never automatically confirmed. Only the administrator can set confirmed_by_agency. No automatic email/SMS is sent. Confirm appointment and timezone directly with the visitor.

## Development and deployment
Run npm install, npm run build, npm test. For local preview run node scripts/preview.mjs and open http://127.0.0.1:5173. The localhost-only preview simulates owner identity and uses SQLite/R2-compatible local storage in ignored .local/. This is not production authentication.

Preserve .openai/hosting.json. D1 binding: DB; R2 binding: BUCKET. Schema-only migrations: drizzle/. Demo records: worker/seed.json. Publish the built Worker via Sites, using its existing project ID. Do not overwrite applied migrations. No Supabase keys are needed for this Sites edition.

## Implemented
Public homepage, searchable catalog, detail pages, fullscreen gallery, about/contact, English/Serbian core interface, admin overview and property CRUD, persisted uploads/cover/reordering, agents, settings, inquiries/viewings, optional HTTPS tour links, responsive styling and reduced-motion animations. Multi-currency originals are retained; no exchange rates are invented.

## Remaining limitations
Admin and some public labels remain English. Currency conversion is unavailable; filters compare original numeric amounts, as disclosed. Catalog currently filters fetched records locally; indexed fields and server pagination are recommended for growth. Uploaded photos lack automatic thumbnail generation. Gallery focus trapping and fuller accessibility testing remain. SEO is basic client metadata plus core sitemap, not complete server-rendered property Open Graph. No outgoing email, sophisticated spam protection, subscriptions, advanced roles, custom domain or custom 3D engine. Images are illustrative and properties fictional. Media files are public property photographs; do not upload confidential documents.
