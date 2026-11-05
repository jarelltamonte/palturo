# Auth email links and redirects

## Short answer

No separate backend is required. Supabase Auth creates the tokens and sends the
mail through Resend. `https://palturo.app` is a small static auth page that
verifies those tokens, lets the user choose a new password in the browser, and
confirms signups.

## Current flow

The recovery and confirmation templates now link directly to the auth page with
a Supabase token hash:

| Email | Link |
| --- | --- |
| Password reset | `https://palturo.app/reset?token_hash={{ .TokenHash }}&type=recovery` |
| Signup confirmation | `https://palturo.app/confirm?token_hash={{ .TokenHash }}&type=signup` |

`/reset` calls `supabase.auth.verifyOtp({ type: 'recovery' })`, shows the new
password form, then calls `supabase.auth.updateUser({ password })`. The reset is
completed in the browser and works on desktop or mobile.

`/confirm` calls `verifyOtp({ type: 'signup' })` and shows the confirmation
state.

The old `{{ .ConfirmationURL }}` style links still fall back to the app handoff:
the page forwards the `code` or session fragment to
`palturo://auth/reset-callback` / `palturo://auth/callback`.

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

- [x] Reset link opens the password form, not a dead end.
- [x] New password can be saved and used to sign in.
- [x] Confirmation link marks the account confirmed.
- [x] Expired or reused token shows the expired state.
- [x] Requesting from localhost still produces a `palturo.app` email link.
- [ ] Request a real reset from a production app build and open the email on a
      phone and a desktop browser.
