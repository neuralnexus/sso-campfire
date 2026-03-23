# Campfire

Campfire is a web-based chat application. It supports many of the features you'd
expect, including:

- Multiple rooms, with access controls
- Direct messages
- File attachments with previews
- Search
- Notifications (via Web Push)
- @mentions
- API, with support for bot integrations

## Deploying with Docker

Campfire's Docker image contains everything needed for a fully-functional,
single-machine deployment. This includes the web app, background jobs, caching,
file serving, and SSL.

To persist storage of the database and file attachments, map a volume to `/rails/storage`.

To configure additional features, you can set the following environment variables:

- `SSL_DOMAIN` - enable automatic SSL via Let's Encrypt for the given domain name
- `DISABLE_SSL` - alternatively, set `DISABLE_SSL` to serve over plain HTTP
- `VAPID_PUBLIC_KEY`/`VAPID_PRIVATE_KEY` - set these to a valid keypair to
  allow sending Web Push notifications. You can generate a new keypair by running
  `/script/admin/create-vapid-key`
- `SENTRY_DSN` - to enable error reporting to sentry in production, supply your
  DSN here

For example:

    docker build -t campfire .

    docker run \
      --publish 80:80 --publish 443:443 \
      --restart unless-stopped \
      --volume campfire:/rails/storage \
      --env SECRET_KEY_BASE=$YOUR_SECRET_KEY_BASE \
      --env VAPID_PUBLIC_KEY=$YOUR_PUBLIC_KEY \
      --env VAPID_PRIVATE_KEY=$YOUR_PRIVATE_KEY \
      --env TLS_DOMAIN=chat.example.com \
      campfire

## Enterprise identity (OIDC + SCIM)

Campfire includes a native enterprise identity subsystem with:

- OIDC for authentication
- SCIM 2.0 for user and group lifecycle
- Identity modes via `IDENTITY_MODE`: `local_only`, `local_plus_oidc`, `oidc_required`

Production setup requirements:

- Set `LOCKBOX_MASTER_KEY` (or `credentials[:lockbox][:master_key]`) so provider client secrets can be encrypted at rest.
- Set `credentials[:scim_hmac_key]` for SCIM token fingerprinting. In production this key is required and there is no fallback.

Recommended rollout:

1. Start in `IDENTITY_MODE=local_only`.
2. Create an identity provider at `/admin/identity_providers/new`.
3. Save it disabled, then use **Refresh metadata** to fetch discovery endpoints (token/JWKS/userinfo).
4. Enable provider and switch to `IDENTITY_MODE=local_plus_oidc`.
5. Validate enterprise login and break-glass local admin login.
6. Switch to `IDENTITY_MODE=oidc_required`.

Notes:

- OIDC callback uses cached provider metadata from the database and does not fetch discovery documents live during login.
- SCIM `DELETE /scim/v2/Users/:id` soft-deactivates users and revokes sessions; it does not hard-delete history.
- Break-glass admins remain exempt from OIDC enforcement and SCIM deprovisioning.

Metadata refresh can be scheduled with `config/identity_metadata_cron.example`.

## Running in development

    bin/setup
    bin/rails server

## Worth Noting

When you start Campfire for the first time, you’ll be guided through
creating an admin account.
The email address of this admin account will be shown on the login page
so that people who forget their password know who to contact for help.
(You can change this email later in the settings)

Campfire is single-tenant: any rooms designated "public" will be accessible by
all users in the system. To support entirely distinct groups of customers, you
would deploy multiple instances of the application.
