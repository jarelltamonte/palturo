# Auth email links and redirects

## Short answer

No separate backend is required. Supabase Auth creates the confirmation and
recovery tokens and sends the mail through Resend. The GitHub domain appeared
because the Supabase project's **Site URL** was still the old GitHub Pages auth
page. It is now:

```
https://palturo.app/
```

`https://palturo.app` is a small static auth page, not the Flutter app. It
handles confirmation and reset links, then hands the user to the app through the
`palturo://` deep link.

## Why the reset email looked like a confirmation email

The recovery template is correct (`Reset your password`, with a
`{{ .ConfirmationURL }}` button). The problem was the destination:

1. Supabase verified the recovery token.
2. It redirected to the `redirect_to` value if allowlisted.
3. Otherwise it fell back to **Site URL** — the GitHub Pages “Email confirmed”
   page.
4. That page is not the app's reset screen, so the flow dead-ended.

The Flutter client also sent `palturo://auth/reset-callback` on web, which a
browser cannot open.

## How redirects work now

Production builds set:

```
APP_PUBLIC_URL=https://palturo.app
```

That makes auth emails use the static site:

| Flow | Redirect target | Final destination |
| --- | --- | --- |
| Signup confirmation | `https://palturo.app/confirm` | `palturo://auth/callback` |
| Password reset | `https://palturo.app/reset` | `palturo://auth/reset-callback` |

The static page preserves the query string and fragment when forwarding, so the
app still receives the Supabase code or tokens.

Auth emails always use the static site, even when the reset was requested from
localhost. `APP_PUBLIC_URL` can override the origin for a staging deployment; if
it is absent, the app defaults to `https://palturo.app`.

## Mobile-first limitation

The reset is completed in the app, not in the browser. That keeps PKCE intact
and avoids a second password form.

- On a phone, the page tries the deep link automatically and keeps an **Open
  PalTuro** button as fallback.
- On desktop, it shows **Copy link for your phone**. The user opens that link on
  the device with PalTuro installed.
- A desktop-only password reset is not supported by this page. That would
  require a browser reset form and a different auth flow.

## Supabase settings

Open **Authentication → URL Configuration**.

- **Site URL:** `https://palturo.app/`
- **Redirect URLs:**
  `https://palturo.app/**`, `https://www.palturo.app/**`,
  `http://localhost:5317/**`,
  `palturo://auth/callback`, `palturo://auth/reset-callback`

These are already applied.

## Production build

`.env.production` contains `APP_PUBLIC_URL=https://palturo.app`. Build the mobile
app with that file when you want email links to use the web auth page:

```sh
flutter build apk --release --dart-define-from-file=.env.production
```

Local development uses `.env`, where `APP_PUBLIC_URL` is empty.

## Deployment

The static page lives beside this repo in `palturo-auth-web` and is deployed to
Cloudflare:

```powershell
cd ..\palturo-auth-web
npx wrangler deploy
```

Custom domains `palturo.app` and `www.palturo.app` are attached to the Worker
`palturo-auth`. DNS is managed in Cloudflare; the Resend SPF/DKIM records are
untouched.

## Email delivery

Resend is the SMTP host and `team@palturo.app` is the sender. Keep the
`palturo.app` domain verified in Resend with SPF and DKIM.

The recovery template is under **Authentication → Email Templates → Reset
Password**. The confirmation template is separate.

## Verification checklist

- [ ] Request a reset for a real account.
- [ ] The email subject is `Reset your PalTuro password`.
- [ ] The link host is `palturo.app`, not `github.io` or `supabase.co`.
- [ ] `/reset` shows the reset state and forwards to the app.
- [ ] `/confirm` shows the confirmation state and forwards to the app.
- [ ] A new password can be saved and the old password no longer works.
- [ ] Expired or reused links show the expired-reset state.
- [ ] A desktop reset shows the copy-link fallback.
