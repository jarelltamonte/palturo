# Deploy the web app to Vercel

The production origin is `https://palturo.app`. Supabase Auth is already pointed
at it:

- **Site URL:** `https://palturo.app/`
- **Redirect URLs:** `https://palturo.app`, `https://palturo.app/**`,
  `https://www.palturo.app`, `https://www.palturo.app/**`,
  `http://localhost:5317`, `http://localhost:5317/**`,
  `palturo://auth/callback`, `palturo://auth/reset-callback`

The app is a static Flutter web build. Vercel only needs to serve `build/web`;
no Node server or second backend is involved.

## 1. Build the production bundle

`.env.production` contains the Supabase URL, the publishable key, and:

```
APP_PUBLIC_URL=https://palturo.app
```

Never put `SUPABASE_PAT` or a service-role key in that file.

```powershell
flutter build web --release `
  --dart-define-from-file=.env.production `
  --base-href /
```

Flutter copies `web/vercel.json` into `build/web/vercel.json`. That file adds
the SPA fallback rewrite and no-cache headers for `index.html` and the service
worker.

## 2. Deploy

One-time login:

```powershell
npx --yes vercel@latest login
```

Then either run the helper:

```powershell
.\tools\deploy_web.ps1
```

or deploy the already-built folder directly:

```powershell
npx --yes vercel@latest deploy build/web --prod
```

The first deploy creates the Vercel project. Later deploys reuse it.

## 3. Attach the domain

In the Vercel dashboard: **Project → Settings → Domains → Add**.

Add both:

```
palturo.app
www.palturo.app
```

Vercel will show the exact DNS records. Typical values are:

| Host | Type | Value |
| --- | --- | --- |
| `@` | A | `76.76.21.21` |
| `www` | CNAME | `cname.vercel-dns.com` |

Use the values Vercel displays, not these, if they differ. Keep the existing
Resend SPF/DKIM records for `palturo.app`; do not replace the whole DNS zone.

## 4. Verify

```powershell
Resolve-DnsName palturo.app -Type A
Invoke-WebRequest https://palturo.app -UseBasicParsing
```

Then request a password reset and confirm:

- The email subject is `Reset your PalTuro password`.
- The link host is `palturo.app`.
- The link opens the in-app reset form.
- The new password works and the old one does not.

Also test signup confirmation. It uses the same Site URL.

## Preview deployments

Preview URLs look like `https://<project>-<hash>-<team>.vercel.app`. If you need
auth emails from previews, add that exact host to the Supabase redirect
allowlist. Do not add a blanket `https://*.vercel.app/**` rule; it would let any
Vercel deployment receive auth links.

## Rollback

Vercel keeps every deployment. Use **Deployments → Promote to Production** on a
previous build. The Supabase URL configuration does not need to change.
