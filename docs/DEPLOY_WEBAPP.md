# PalTuro webapp deployment

The `palturo-webapp` branch is the cross-platform build of the same Flutter UI.
It is a compatibility target for phones and desktop browsers, not a second
design system. The mobile app remains the source of truth.

## Domain

Proposed production origin:

```
https://app.palturo.app
```

Keep the auth landing page at `https://palturo.app`. Email links still land
there; the page opens the native app or the webapp.

## Build and deploy

```powershell
flutter pub get
flutter build web --release `
  --dart-define-from-file=.env.production `
  --base-href /
```

Then either:

```powershell
.\tools\deploy_webapp.ps1
```

or:

```powershell
npx --yes vercel@latest deploy build/web --prod
```

The first deploy creates the Vercel project. `.env.production` must contain:

```
SUPABASE_URL=...
SUPABASE_PUBLISHABLE_KEY=...
APP_PUBLIC_URL=https://palturo.app
```

Never add `SUPABASE_PAT` or a service-role key. `--dart-define-from-file`
compiles every value into the client.

## Vercel domain

In **Project → Settings → Domains**, add:

```
app.palturo.app
```

Then add the DNS record Vercel shows. For a subdomain the usual record is:

| Host | Type | Value |
| --- | --- | --- |
| `app` | CNAME | `cname.vercel-dns.com` |

Use DNS-only (grey cloud) for the first verification, then enable Cloudflare
proxying only if the SSL mode is Full (strict).

Do not replace the Resend SPF/DKIM records on `palturo.app`.

## Recovery links

The webapp reads `token_hash` from its own URL and opens the same
`ForgotPasswordType` screen used by the native deep link:

```
https://app.palturo.app/?token_hash=...&type=recovery
```

The auth page should offer this as the web fallback while keeping **Open in
App** as the primary action:

```
Open in App        -> palturo://auth/reset-callback?token_hash=...
Use PalTuro on web -> https://app.palturo.app/?token_hash=...&type=recovery
```

The webapp verifies the token, shows the in-app reset form, and updates the
password. No browser password form exists in the auth page.

## Web compatibility notes

- The existing `ResponsiveShell` keeps the mobile-width column on desktop.
- The viewport uses `viewport-fit=cover` for notched phones.
- The PWA manifest uses `standalone`, `start_url: "/"` and the PalTuro icons.
- Push delivery remains unavailable on web; in-app banners, Activity, chat and
  presence still work through Supabase realtime.
- iOS browser limitations (no push, install via Add to Home Screen) are
  expected.
- The Flutter service worker provides offline caching; `index.html` and the
  service worker are marked no-cache on Vercel.

## Verification

- [ ] `https://app.palturo.app` loads the login screen.
- [ ] Sign in works and the session survives reload.
- [ ] Phone layout at 390 and 360 has no horizontal overflow.
- [ ] Desktop retains the centred mobile shell.
- [ ] Recovery link opens the reset screen inside the webapp.
- [ ] A new password can be saved and used to sign in.
- [ ] PWA install prompt / Add to Home Screen shows the PalTuro icon.
- [ ] Realtime chat, Activity, presence and typing still work.
