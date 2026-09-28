# Supabase Custom SMTP setup

## What this repo currently uses

Supabase Auth email-based flows found in this repo:

- Sign-up with email/password:
  - `main_project_app/lib/src/features/auth/presentation/login_screen.dart`
  - Uses `Supabase.instance.client.auth.signUp(...)`
- Login with password:
  - `main_project_app/lib/src/features/auth/presentation/login_screen.dart`
  - Uses `signInWithPassword(...)`
  - This does not send email
- Password reset:
  - `main_project_app/lib/src/features/auth/presentation/login_screen.dart`
  - Uses `resetPasswordForEmail(...)`

Not currently implemented in app code:

- Magic link login
- OTP email login
- Email change flow
- Explicit email verification handling route in app code

## Important boundary

Custom SMTP for a hosted Supabase project is primarily an operational configuration in Supabase, not an application code change.

This repo does **not** change your hosted Supabase Auth SMTP settings automatically.

## Required SMTP values from your provider

You need these from Mailtrap, Postmark, SES, SendGrid, Resend SMTP, Brevo, or another SMTP provider:

- SMTP host
- SMTP port
- SMTP user
- SMTP password
- Sender email (`From`)
- Sender name

TLS guidance:

- Port `587`: usually STARTTLS
- Port `465`: usually implicit TLS
- Use the provider's documented default
- Supabase hosted config asks for host/port/user/pass/from values; choose the provider's recommended secure option

## Supabase dashboard setup

Dashboard path:

1. Supabase Dashboard
2. Project
3. `Authentication`
4. `SMTP Settings`

Fill these fields:

- Enable custom SMTP
- Sender email
- Sender name
- SMTP host
- SMTP port
- SMTP user
- SMTP password

Recommended related settings to review:

1. `Authentication` -> `Providers` -> `Email`
   - Whether email confirmations are enabled
   - Whether secure email change is enabled
2. `Authentication` -> `URL Configuration`
   - `Site URL`
   - Redirect URLs used in confirmation and recovery emails
3. `Authentication` -> `Email Templates`
   - Confirmation template
   - Recovery template
   - Email change template if you later enable that flow
4. `Authentication` -> `Rate Limits`
   - Increase email-related limits after custom SMTP is enabled

## Safe Management API example

Use placeholders only. Never commit real secrets.

```bash
export SUPABASE_ACCESS_TOKEN="your-supabase-management-access-token"
export PROJECT_REF="your-project-ref"

curl -X PATCH "https://api.supabase.com/v1/projects/$PROJECT_REF/config/auth" \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "external_email_enabled": true,
    "mailer_autoconfirm": false,
    "mailer_secure_email_change_enabled": true,
    "smtp_admin_email": "no-reply@example.com",
    "smtp_host": "smtp.example.com",
    "smtp_port": 587,
    "smtp_user": "smtp-user",
    "smtp_pass": "smtp-password",
    "smtp_sender_name": "Avoid Call"
  }'
```

Notes:

- `external_email_enabled: true` enables custom SMTP usage
- `mailer_autoconfirm: false` means email confirmation remains required
- If you intentionally do not want signup confirmation, adjust the Email provider settings in dashboard

## Development/testing mode

Recommended provider:

- Mailtrap sandbox inbox

Suggested approach:

1. Create a Mailtrap account and inbox
2. Copy sandbox SMTP credentials
3. Configure Supabase custom SMTP with the Mailtrap sandbox credentials
4. Keep email confirmation enabled while testing templates and links
5. Trigger:
   - signup confirmation
   - password reset
6. Verify delivery in Mailtrap inbox UI instead of a real mailbox

What to verify:

- Subject line is correct
- Sender email/name are correct
- Email template branding is acceptable
- Confirmation and reset links point to the correct Supabase/Auth URL flow
- Rate-limit errors from built-in provider disappear

## Real-delivery mode

Recommended approach:

1. Use a real transactional email provider
2. Verify domain ownership with the provider
3. Configure SPF, DKIM, and ideally DMARC
4. Configure Supabase custom SMTP with production credentials
5. Send test emails to real inboxes on multiple providers:
   - Gmail
   - Outlook
   - iCloud or another independent mailbox
6. Check spam/junk placement

## Rate limits

After custom SMTP is enabled, Supabase applies a low default hourly limit and expects you to review `Authentication -> Rate Limits`.

Review at least:

- Signup confirmation requests
- Password recovery requests
- General email-send hourly limits

If you plan a public launch, coordinate provider-side sending limits too.

## Delivery failure checks

If emails fail:

1. Supabase Dashboard -> Logs -> Auth logs
2. SMTP provider dashboard logs / activity feed
3. Check provider-side suppression / bounce / blocklist state
4. Check SPF, DKIM, DMARC alignment
5. Check sender address is allowed by provider
6. Check SMTP port/TLS mode matches provider requirements

## Security notes

- Do not commit SMTP credentials into git
- Store secrets only in:
  - Supabase dashboard config
  - provider dashboard
  - CI/CD secret manager
  - local untracked `.env` files if absolutely necessary

## Checking for committed credentials

Keep `backend/.env` and `main_project_app/.env` local and untracked. Share only
example or template files with empty values or clearly marked placeholders.

A file name or an old warning does not establish that a credential was exposed.
Check the current tracked files and relevant Git history before reporting a leak.
Do not paste suspected secret values into issues, screenshots, or review comments.

`.gitignore` prevents new untracked files from being added accidentally. It does
not untrack an existing file, remove a value from history, or revoke a credential.

If a sensitive credential is confirmed to have been committed:

1. Revoke or rotate it with its provider and update the services that use it.
2. Remove the tracked secret or stop tracking the affected local-only file,
   keeping a placeholder-only example where needed.
3. Assess whether history cleanup is necessary and coordinate it with anyone
   using an existing clone. Rewriting history does not invalidate leaked keys.
4. Recheck the result and enable available secret scanning and push protection.

See [GitHub’s guidance on removing sensitive data](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository).
