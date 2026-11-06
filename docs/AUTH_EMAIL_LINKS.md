# Auth email links and redirects

## Short answer

No separate backend is required. Supabase Auth creates the tokens and sends the
mail through Resend. `https://palturo.app` is a small static auth page that
verifies those tokens, shows the new-password form, and confirms signups.

## Current flow

The recovery and confirmation templates link directly to the auth page with a
Supabase token hash:

| Email | Link |
| --- | --- |
| Password reset | `https://palturo.app/reset?token_hash={{ .TokenHash }}&type=recovery` |
| Signup confirmation | `https://palturo.app/confirm?token_hash={{ .TokenHash }}&type=signup` |

`/reset` calls `verifyOtp({ type: 'recovery' })`, shows the new-password form,
then calls `updateUser({ password })`. Password reset is completed in the browser
on desktop and mobile. No app is required.

`/confirm` calls `verifyOtp({ type: 'signup' })` and shows the confirmation
state.

Legacy `{{ .ConfirmationURL }}` links that only carry a `code` or session
fragment show a “request a new link” state because the browser cannot complete
the PKCE exchange without the original verifier.

## Supabase settings

**Authentication → URL Configuration**

- Site URL: `https://palturo.app/`
- Redirect URLs:
  `https://palturo.app/**`, `https://www.palturo.app/**`,
  `http://localhost:5317/**`,
  `palturo://auth/callback`, `palturo://auth/reset-callback`

**Authentication → Email Templates**

- Reset Password uses the `/reset` token-hash link.
- Confirm signup uses the `/confirm` token-hash link.

Both templates were updated in the project. The `{{ .ConfirmationURL }}` links
were replaced, so the app no longer depends on the GitHub Pages auth page.

## App configuration

The app still sets `emailRedirectTo` to the auth page for compatibility:

```
https://palturo.app/reset
https://palturo.app/confirm
```

`APP_PUBLIC_URL` defaults to `https://palturo.app` when it is not set, so a reset
requested from localhost cannot produce a localhost email link.

## Email delivery

Resend is the SMTP host and `team@palturo.app` is the sender. Keep the
`palturo.app` domain verified in Resend with SPF and DKIM.

## Deployment

The page is a separate project at `../palturo-auth-web`, served by Cloudflare:

```powershell
cd ..\palturo-auth-web
npx --yes wrangler@latest deploy
```

Custom domains `palturo.app` and `www.palturo.app` are attached to the Worker
`palturo-auth`. The Resend DNS records are untouched.

## Verification checklist

- [x] Reset link opens the browser password form on desktop and mobile.
- [x] Invalid passwords show one inline message, not a rules list.
- [x] New password can be saved and used to sign in.
- [x] Confirmation link marks the account confirmed.
- [x] Expired or reused token shows the expired state.
- [x] Requesting from localhost still produces a `palturo.app` email link.
- [ ] Request a real reset from a production build and open it in a browser.
