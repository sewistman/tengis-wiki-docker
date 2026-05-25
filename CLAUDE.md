# Tengis Wiki — Claude Code Rules

## Product Branding

The product name is **Tengis Wiki**. Replace all user-facing instances of "Seafile" with "Tengis Wiki".

### Scope of branding changes — ALLOWED
- Visible UI strings (button labels, headings, paragraphs, tooltips, help text)
- Page `<title>` tags
- `<meta>` tag content values (e.g. `og:site_name`)
- Copyright notices (e.g. `© {year} Tengis Wiki`)
- Email template body text
- `gettext(...)` / `{% trans %}` / `{% blocktrans %}` strings that are rendered to users
- Locale `.po` file `msgstr` values for strings that are rendered to users

### Scope of branding changes — NEVER TOUCH
- Function names, method names, variable names, class names
- API endpoint paths or URL route strings
- CSS class names (e.g. `.seahub-modal-btn`, `.seahub-io-dialog`, `.seafile-multicolor-icon`)
- Backend Python logic, Django views, models, serializers, or middleware
- Import paths, module names, or package names
- Config file keys (only values visible to end users may change)
- `msgid` strings in `.po` files (these are lookup keys, not displayed text)
- Internal comments in code unless they are doc-comments rendered to users

## Color Palette

When changing color values, use only these brand colors:

| Role | Value |
|------|-------|
| Primary / accent | `#4A4EC7` |
| Black / foreground | `#0D0D0D` |
| Surface gray / background | `#F4F4F6` |

Only change color values in CSS or inline styles that are user-visible. Do not rename CSS custom properties or class names.

## Copyright

Copyright owner is **Tengis Wiki**. The copyright line should read:
```
© {year} Tengis Wiki
```

## External URLs

Any URL referencing `seafile.com`, `seafileltd.com`, or `manual.seafile.com` — anywhere in either repo (UI templates, JS, email templates, Docker files, config files, documentation) — must be replaced with `https://redirish.global`.

### Domains to replace (all variants)
| Original domain | Replacement |
|-----------------|-------------|
| `seafile.com` (any subdomain or path) | `https://redirish.global` |
| `seafileltd.com` (any subdomain or path) | `https://redirish.global` |
| `manual.seafile.com` (any path) | `https://redirish.global` |
| `forum.seafile.com` | `https://redirish.global` |
| `www.seafile.com` (any path) | `https://redirish.global` |

### Scope
- **ALLOWED**: replacing `href` values, visible link text, `image:` pull URLs in Docker files, hardcoded URL strings in config or compose files, and any URL in email template body text pointing to the above domains
- **NEVER TOUCH**: internal Django `{% url %}` tags, `SITE_ROOT`-relative paths, API base URLs, or any URL that routes within the application itself

## Email Templates

These rules apply to all email templates (`*.html`, `*.txt`) under `seahub/templates/` and any subdirectory.

### ALLOWED — replace in email templates
- All visible body text containing "Seafile" → "Tengis Wiki"
- Email subject lines containing "Seafile" → "Tengis Wiki"
- `{{ site_name }}` usage is already brand-neutral (dynamic); leave template variables as-is
- Any hardcoded `seafile.com` / `seafileltd.com` URLs in email body → `https://redirish.global`

### NEVER TOUCH in email templates
- Template variable names (e.g. `{{ site_name }}`, `{{ user }}`, `{{ email }}`)
- Django template tags (`{% load %}`, `{% block %}`, `{% url %}`, `{% blocktrans %}`, `{% trans %}`)
- Email routing logic, SMTP configuration, or backend sending code
- `From:` / `Reply-To:` header values set in Python code (not templates)

## Docker Naming (Docker repo)

These rules apply to all `Dockerfile`, `docker-compose.yml`, and related config files in the Docker repo.

### Container and image names
- All container names must use the `tengis` prefix (e.g. `tengis-backend`, `tengis-db`, `tengis-nginx`)
- Image names must not reference `seafile` or `seafileltd` — use `tengis` equivalents
- Version labels and image metadata must read "Tengis Wiki" not "Seafile"

### Service names in docker-compose files
- Service keys must use `tengis` naming (e.g. `tengis-server`, `tengis-db`) not `seafile-*`

### What NOT to change in Docker files
- Internal environment variable names passed to application code (these are backend config keys)
- Volume mount paths that the application code reads by convention
- Network names used only internally between containers (unless user-visible)
- Port mappings and other non-naming configuration

## General Rules

- Never modify function names, API endpoints, URL routes, or backend logic.
- Never modify CSS class names.
- Only change visible UI strings, page titles, copyright notices, color values, external seafile.com/seafileltd.com URLs, and Docker naming as described above.
- When in doubt about whether something is "user-facing" or "naming" vs "internal config", do not change it and ask first.

## docker.seafile.top Registry — NEVER TOUCH

The hostname `docker.seafile.top` is a third-party mirror registry, not a Seafile brand
identifier. It is not used in the Tengis Wiki deployment and is intentionally preserved in
scripts where it appears (e.g. `image/pro_seafile_13.0/docker-build-push.sh`). Do not
replace it with `https://redirish.global` or any other value. It is not covered by the
External URLs replacement rule above, which applies only to `seafile.com`, `seafileltd.com`,
and their listed subdomains.

## Before Making Any Changes — Read PATHS.md First

`PATHS.md` in the root of this repo contains the full categorized map of every file
audited for branding: which files were changed, which must never be touched, and the
reason for each classification. Always read it before making any branding edits to avoid
modifying internal paths, env var names, binary names, nginx identifiers, or volume paths
that must remain unchanged.
