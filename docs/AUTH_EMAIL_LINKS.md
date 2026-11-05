# Auth email links and redirects

## Short answer

No separate backend is required. Supabase Auth creates the tokens and sends the
mail through Resend. `https://palturo.app` is a small static auth page that
verifies confirmation tokens, hands password resets to the app on phones, and
provides a browser reset form on desktop.

## Current flow

The recovery and confirmation templates link directly to the auth page with a
Supabase token hash:

| Email | Link |
| --- | --- |
| Password reset | `https://palturo.app/reset?token_hash={{ .TokenHash }}&type=recovery` |
| Signup confirmation | `https://palturo.app/confirm?token_hash={{ .TokenHash }}&type=signup` |

`/reset` is hybrid:

- **Phone:** the page forwards the token hash to
  `palturo://auth/reset-callback`. `ForgotPasswordType` verifies it with
  `verifyOTP(type: recovery)` and shows the in-app reset form.
- **Desktop:** the page verifies the token hash with the Supabase JS client and
  shows the same reset form in the browser.
- **Phone fallback:** “Continue in this browser” reveals the desktop form if the
  app is not installed.

`/confirm` calls `verifyOtp({ type: 'signup' })` and shows the confirmation
state on the page.

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

- [x] Desktop reset link opens the password form.
- [x] New password can be saved and used to sign in.
- [x] Confirmation link marks the account confirmed.
- [x] Expired or reused token shows the expired state.
- [x] Requesting from localhost still produces a `palturo.app` email link.
- [x] Phone view forwards the reset token to `palturo://auth/reset-callback`
      and offers “Continue in this browser” as a fallback.
- [ ] In-app token verification on a physical phone with a production build.
