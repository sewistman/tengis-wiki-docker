# Tengis Wiki Rebranding Guide
**Version 1.7 — May 2026**
**Based on live session: sewistman / akinkarakaya**

---

## SECTION 1 — Start From Scratch: Complete Setup & What We Did

This section covers every real command run during the session, in order, with actual output context.

---

### 1.1 Understanding Your Machine

Before doing anything, understand what you are working with.

```bash
sw_vers && uname -m && sysctl -n hw.memsize | awk '{print $1/1024/1024/1024 " GB RAM"}' && df -h /
```

**Our machine:**
- macOS 15.7.7 Sequoia
- Intel x86_64 (not Apple Silicon)
- 8 GB RAM
- 233 GB disk, ~10 GB used

**Key constraint:** 8 GB RAM on Intel means we never run Docker or heavy build tools on this Mac. All compilation and server running happens on the VMware server.

---

### 1.2 Installing Claude Code

Claude Code requires a **Claude Pro or Max subscription** ($20/month minimum). Free accounts do not work.

**Step 1 — Install:**
```bash
curl -fsSL https://claude.ai/install.sh | sh
```

**Step 2 — Fix PATH (required after install):**
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

**Step 3 — Launch:**
```bash
claude
```

On first launch: select Dark mode, select "Claude account with subscription", select "Yes, use recommended settings". Log in via browser.

**Step 4 — Verify:**
```bash
claude --version
claude doctor
```

---

### 1.3 Setting Up Git

**Check if Git is installed:**
```bash
git --version
```
Our result: `git version 2.39.5 (Apple Git-154)` — already installed.

**Configure Git identity:**
```bash
git config --global user.name "sewistman"
git config --global user.email "sewistman@gmail.com"
```

---

### 1.4 Setting Up SSH for GitHub

Required for cloning private repositories.

**Generate SSH key:**
```bash
ssh-keygen -t ed25519 -C "sewistman@gmail.com"
# Press Enter for all prompts
```

**Get the public key:**
```bash
cat ~/.ssh/id_ed25519.pub
```

**Add to GitHub:**
1. Go to `https://github.com/settings/ssh/new`
2. Title: `my mac`
3. Paste the key
4. Click **Add SSH key**

---

### 1.5 Forking the Repos

We forked two repos from Seafile's GitHub organization. Both set to **Private**.

| Original Repo | Our Fork | Purpose |
|---|---|---|
| `haiwen/seahub` | `sewistman/tengis-wiki-fr` | Web UI rebranding |
| `haiwen/seafile-docker` | `sewistman/tengis-wiki-docker` | Docker rebranding |

> **Visibility history:** `tengis-wiki-fr` was initially set to **Public** during the 25 May 2026 test deployment session (which is why the test session log clones it over HTTPS without auth). It was changed to **Private** after that session. The current state for both repos is Private.

**Why these two only:**
- `haiwen/seahub` = everything users see in the browser (JavaScript + Python)
- `haiwen/seafile-docker` = Docker Compose files, container names, image names
- `haiwen/seafile` = sync daemon (C code) — not needed, users never see this
- `haiwen/seafile-server` = server core — we use the official pre-built Docker image, no fork needed

---

### 1.6 Cloning the Repos

```bash
mkdir ~/tengiswiki && cd ~/tengiswiki

git clone git@github.com:sewistman/tengis-wiki-fr.git
git clone git@github.com:sewistman/tengis-wiki-docker.git
```

**Verify sync with GitHub:**
```bash
cd ~/tengiswiki/tengis-wiki-fr && git status && git log --oneline -3
cd ~/tengiswiki/tengis-wiki-docker && git status && git log --oneline -3
```

Both should show: `nothing to commit, working tree clean`

---

### 1.7 Current Situation & Next Steps

**What is done:**
- ✅ Claude Code installed and authenticated
- ✅ Git configured with SSH
- ✅ Both repos forked (private) and cloned locally
- ✅ `tengis-wiki-fr` fully rebranded (see Section 3)
- ✅ `tengis-wiki-docker` fully rebranded (see Section 4)
- ✅ CLAUDE.md and PATHS.md committed to both repos

**What is remaining:**
- ⬜ VMware server setup and Docker deployment
- ⬜ End-to-end test in browser

---

## SECTION 2 — The Approach: How to Rebrand Any Seafile Repo

This section explains the thinking behind every decision. Use this as your methodology for the docker repo and any future repos.

---

### 2.1 Why We Analyzed Before Touching Anything

The first thing Claude Code did was **read, not write**. We asked it to find every instance of "Seafile" in user-facing files and list them before making a single change.

This matters because:
- A large codebase has hundreds of "Seafile" occurrences
- Most of them are internal — function names, class names, import paths
- Changing internal identifiers **breaks the application**
- Only a small subset are visible to users

**The rule:** If a user cannot read it in their browser, do not touch it.

---

### 2.2 What We Touch vs What We Never Touch

| Touch ✅ | Never Touch ❌ |
|---|---|
| UI string literals in `gettext()` / `{% trans %}` | Function names |
| HTML template visible text | CSS class names |
| Page titles and headings | API endpoint paths |
| Copyright notices | Internal variable names |
| Help page content | Import paths / npm packages |
| Email body text | Django URL routes |
| `msgstr` lines in `.po` files | `msgid` lines in `.po` files |
| `href` values pointing to seafile.com | Internal environment variables |
| Logo and favicon image files | Volume mount paths in Docker |
| CSS color variable values in `:root` | Bootstrap utility class names |
| Docker container names (user-visible) | Docker internal network names |
| Docker service display names | Port mappings |

---

### 2.3 Why We Created CLAUDE.md First

Before making any changes, we created a `CLAUDE.md` file at the root of the repo. This file is automatically read by Claude Code at the start of every session.

**Why this is important:**
- Rules are enforced consistently across all sessions
- No need to repeat instructions every time
- Claude Code references CLAUDE.md when unsure about edge cases
- The rules travel with the repo on GitHub

Always create CLAUDE.md **before** starting changes, not after.

---

### 2.4 Working in Batches, Not All at Once

We never said "change everything". We worked in this order:

1. JS source strings (6 files) — reviewed diffs one by one
2. Help templates (25 files) — batched with grep/sed
3. CSS color tokens — targeted only `:root` block
4. Download page and email templates
5. Locale `.po` files — Turkish and Indonesian only
6. Logo and favicon images
7. Final verification grep

**Why batches:** Each batch is reviewable, committable, and reversible. If something breaks, you know exactly which commit caused it.

---

### 2.5 The Token-Efficient Way to Use Claude Code

Reading files costs tokens. These patterns save the most:

- **List before reading:** Ask for file paths first, then read only relevant ones
- **Use grep/sed for bulk changes:** One shell command replacing 25 files costs far fewer tokens than Claude reading each file individually
- **Scope your prompts:** "Find Seafile in the frontend folder only" is cheaper than "Find Seafile everywhere"
- **Batch commits:** Stage multiple changes in one commit instead of committing file by file

---

### 2.6 Checklist for Rebranding Any New Repo

Use this checklist when starting work on `tengis-wiki-docker` or any future repo:

**Step 1 — Setup:**
- [ ] Copy `CLAUDE.md` from `tengis-wiki-fr` into the new repo root
- [ ] Launch Claude Code from the repo folder: `cd ~/tengiswiki/<repo> && claude`

**Step 2 — Analyze:**
- [ ] Ask Claude Code to find all "Seafile" occurrences, list file paths only
- [ ] Ask it to categorize: user-facing vs internal
- [ ] Do not make any changes yet

**Step 3 — Change in order:**
- [ ] Text strings first
- [ ] URLs (replace seafile.com with redirish.global)
- [ ] Color variables if applicable
- [ ] Image/logo files if applicable
- [ ] Locale files (msgstr only, never msgid)
- [ ] Delete unused locale folders (keep: en, en_US, tr, id)

**Step 4 — For Docker repos specifically:**
- [ ] Container names → use `tengis-` prefix
- [ ] Image names → remove all `seafile` / `seafileltd` references
- [ ] Service names in docker-compose → use `tengis-*`
- [ ] Version labels → "Tengis Wiki"
- [ ] Any seafile.com, seafileltd.com, manual.seafile.com URLs → redirish.global
- [ ] Never touch internal env variable names
- [ ] Never touch volume mount paths

**Step 5 — Verify:**
- [ ] Run final grep to confirm zero user-facing "Seafile" strings
- [ ] Review the categorized output — every remaining hit should be explainable
- [ ] Commit and push

---

## SECTION 3 — tengis-wiki-fr: Complete Reference Map

This section documents everything that was changed in the `tengis-wiki-fr` repo.

---

### 3.1 Repo Overview

| Item | Value |
|---|---|
| GitHub URL | `https://github.com/sewistman/tengis-wiki-fr` |
| Forked from | `haiwen/seahub` |
| Visibility | Private |
| Local path | `~/tengiswiki/tengis-wiki-fr` |
| Primary language | JavaScript (52.8%) + Python (38.5%) |
| Latest commit | `c1fc94` |

---

### 3.2 Commit History (Rebranding Session)

| Commit | Message |
|---|---|
| `24f911` | rebrand: replace Seafile with Tengis Wiki in UI strings and help templates |
| `67681d` | rebrand: apply Tengis Wiki color palette |
| `986991` | rebrand: fix download.html brand strings and URLs |
| `603a6d` | rebrand: update Turkish and Indonesian locale files, update CLAUDE.md rules |
| `649190` | chore: remove unsupported locale folders, update CLAUDE.md with supported locales |
| `ace5d3` | rebrand: replace brand logos and favicon with Tengis Wiki artwork |
| `c1fc94` | rebrand: fix remaining Seafile msgstr strings in en locale |

---

### 3.3 Important Directory Map

```
tengis-wiki-fr/
├── CLAUDE.md                          ← Branding rules (see Section 3.6)
├── frontend/
│   └── src/
│       ├── assets/
│       │   └── seafile-logo.png       ← REPLACED with tengis_256.png (256×64)
│       ├── css/
│       │   └── layout.css             ← Uses Bootstrap vars, no direct colors
│       └── components/
│           └── dialog/
│               └── about-dialog.js    ← Copyright changed to © Tengis Wiki
├── media/
│   ├── css/
│   │   └── seafile-ui.css             ← COLOR VARIABLES CHANGED (see 3.4)
│   ├── img/
│   │   ├── seafile-logo.png           ← REPLACED with tengis_256.png (256×64)
│   │   └── seafile-logo-dark.png      ← REPLACED with tengis_dark.png (256×64)
│   └── favicons/
│       └── favicon.png                ← REPLACED with tengis_512.png (512×512)
├── seahub/
│   ├── templates/
│   │   └── download.html              ← Brand text + URLs changed
│   └── help/
│       └── templates/
│           └── help/
│               └── *.html             ← 25 files — all "Seafile" → "Tengis Wiki"
└── locale/
    ├── en/LC_MESSAGES/djangojs.po     ← msgstr lines fixed
    ├── en_US/                         ← Kept
    ├── tr/LC_MESSAGES/                ← Turkish — msgstr lines changed
    └── id/LC_MESSAGES/                ← Indonesian — msgstr lines changed
    # All other 48 locale folders DELETED
```

---

### 3.4 Color Changes

**File:** `media/css/seafile-ui.css` — `:root` block only

| CSS Variable | Before | After |
|---|---|---|
| `--bs-primary` | `#ff8000` | `#4A4EC7` |
| `--bs-link-color` | `#ff8000` | `#4A4EC7` |
| `--bs-link-hover-color` | `#c60` | `#3a3ea0` |
| `--bs-body-color` | `#212529` | `#0D0D0D` |
| `--bs-body-bg` | `#fff` | `#fff` (unchanged) |

---

### 3.5 Image Files Reference

| File Path | Dimensions | Source File | Notes |
|---|---|---|---|
| `frontend/src/assets/seafile-logo.png` | 256×64 px | `tengis_256.png` | React app logo |
| `media/img/seafile-logo.png` | 256×64 px | `tengis_256.png` | Server-rendered pages logo |
| `media/img/seafile-logo-dark.png` | 256×64 px | `tengis_dark.png` | Dark mode logo |
| `media/favicons/favicon.png` | 512×512 px | `tengis_512.png` | Browser tab favicon |

**Note:** All files were resized using Python Pillow to exact required dimensions after copying.

---

### 3.6 CLAUDE.md Full Reference

```markdown
# Tengis Wiki — Rebranding Rules

## Product Name
- Replace all user-facing instances of "Seafile" with "Tengis Wiki"
- Never modify function names, API endpoints, URL routes, or backend logic
- Never modify CSS class names

## What To Change
- Visible UI strings in gettext() / {% trans %} / {% blocktrans %}
- Page titles, headings, copyright notices
- Color values in CSS :root blocks
- Logo and favicon image files
- msgstr lines in .po locale files
- href values and link text pointing to seafile.com

## What To Never Touch
- Function names, method names, class names
- Import paths and npm package names
- Internal JS variable names (enableSeafileAI, isSeafilePlus, etc.)
- API endpoint paths and Django URL routes
- msgid lines in .po files (lookup keys)
- Internal environment variable names in Docker/config files
- Volume mount paths in Docker files
- CSS class names (even if they contain "seafile")

## Colors (Tengis Brand Palette)
- Primary / buttons / links: #4A4EC7 (Tengis Blue)
- Body text / headings: #0D0D0D (Tengis Black)
- Surface background: #F4F4F6
- Hover state: #3a3ea0
- Copyright owner: Tengis Wiki

## External URLs
All URLs referencing the following domains must be replaced with https://redirish.global:
- seafile.com
- www.seafile.com
- seafileltd.com
- manual.seafile.com

This applies to: help templates, download pages, email templates, docker files.

## Email Templates
- Replace "Seafile" with "Tengis Wiki" in body text and subject lines
- Never touch {{ site_name }} or any template variables
- Never touch Django template tags, SMTP config, or routing logic

## Docker Naming (Docker repo)
- Container names must use tengis prefix (e.g. tengis-backend, tengis-db)
- Image names must not reference seafile or seafileltd
- Version labels must say "Tengis Wiki"
- Service keys in docker-compose must use tengis-* naming
- Never touch internal env variable names or volume mount paths

## Locale / Translation Files
- Supported locales: tr (Turkish), id (Indonesian), en, en_US only
- All other locale folders have been deleted and must not be recreated
- In .po files: only replace "Seafile" in msgstr lines
- Never touch msgid lines — they are lookup keys

## Post-Session Verification
After any rebranding session, always run a final grep across all user-facing
files to confirm zero "Seafile" strings remain in visible UI.
Report any remaining hits with category explanation before closing.
```

---

### 3.7 What Was NOT Changed (Intentionally)

| Item | Reason |
|---|---|
| `X-Seafile-Signature` HTTP header | Protocol identifier sent by server — renaming in UI would mislead developers |
| `seahub-db` database reference in admin settings | Actual database name — admins need to find it by this name |
| `enableSeafileAI`, `isSeafilePlus` JS variables | Internal boolean flags, never rendered as text |
| CSS class names (`.seafile-mask` etc.) | Internal styling hooks, not visible to users |
| `@seafile/comment-editor` npm package | Package dependency name, cannot be changed without forking the package |
| All `msgid` lines in `.po` files | Translation lookup keys used by Django — changing breaks translations |

---

## SECTION 4 — tengis-wiki-docker: Complete Reference Map

This section documents everything that was changed in the `tengis-wiki-docker` repo.

---

### 4.1 Repo Overview

| Item | Value |
|---|---|
| GitHub URL | `https://github.com/sewistman/tengis-wiki-docker` |
| Forked from | `haiwen/seafile-docker` |
| Visibility | Private |
| Local path | `~/tengiswiki/tengis-wiki-docker` |
| Primary language | Shell scripts + Dockerfiles |

---

### 4.2 Commit History (Rebranding Session)

| Commit | Message |
|---|---|
| `8373537` | rebrand: replace image names, operator messages, seafile.com URLs, add CLAUDE.md and PATHS.md |
| `f65347e` | docs(CLAUDE.md): add docker.seafile.top exemption and PATHS.md pre-edit rule |
| `671d90d` | rebrand: replace Seafile product name in README and build/README.md |
| `18ce4eb` | build: add custom image Dockerfile |
| `7d40ed3` | build: add .dockerignore for custom image build |

---

### 4.3 Important Directory Map

```
tengis-wiki-docker/
├── CLAUDE.md                              ← Branding rules (see Section 4.6)
├── PATHS.md                               ← Full path audit map (changed vs internal)
├── README.md                              ← CHANGED — product name rebranded
├── README.pro.md                          ← CHANGED — product name rebranded
├── LICENSE.txt                            ← NOT CHANGED — legal attribution (see 4.7)
├── image/
│   ├── docker-manifest-push.sh            ← CHANGED — image names
│   ├── docker-manifest-push-pro.sh        ← CHANGED — image names
│   ├── seafile_13.0/
│   │   └── docker-build-push.sh          ← CHANGED — image names
│   ├── seafile_13.0_arm/
│   │   └── docker-build-push.sh          ← CHANGED — image names
│   ├── pro_seafile_13.0/
│   │   └── docker-build-push.sh          ← CHANGED — image names
│   ├── pro_seafile_13.0_arm/
│   │   └── docker-build-push.sh          ← CHANGED — image names
│   ├── pro_seafile_14.0/
│   │   └── docker-build-push.sh          ← CHANGED — image names
│   └── */Dockerfile                       ← NOT CHANGED — ENV vars, internal paths
├── build/
│   ├── seafile_11.0/seafile-build.sh      ← CHANGED — echo messages only
│   ├── seafile_12.0/seafile-build.sh      ← CHANGED — echo messages only
│   ├── seafile_13.0/seafile-build.sh      ← CHANGED — echo messages only
│   └── seafile_14.0/seafile-build.sh      ← CHANGED — echo messages only
├── scripts/
│   ├── scripts_7.1/gc.sh                  ← CHANGED — echo messages only
│   ├── scripts_8.0/gc.sh                  ← CHANGED — echo messages only
│   ├── scripts_9.0/gc.sh                  ← CHANGED — echo messages only
│   ├── scripts_10.0/gc.sh                 ← CHANGED — echo messages only
│   ├── scripts_11.0/gc.sh                 ← CHANGED — echo messages only
│   ├── scripts_*/cluster_server.sh        ← CHANGED — echo messages only (7 versions)
│   ├── scripts_*/enterpoint.sh            ← NOT CHANGED — system user, paths
│   └── scripts_*/create_data_links.sh     ← NOT CHANGED — volume paths
├── services/
│   ├── nginx.conf                         ← NOT CHANGED — seafileformat identifier
│   └── seafile.nginx.conf                 ← NOT CHANGED — internal nginx config
├── custom/
│   └── */Dockerfile                       ← NOT CHANGED — ENV vars, internal paths
└── templates/                             ← NOT CHANGED — internal config templates
```

---

### 4.4 What Was Changed and How

**Pass 1 — Docker image registry names (7 files, 48 lines):**

```bash
find image/ \( -name "docker-build-push.sh" -o -name "docker-manifest-push*.sh" \) -print0 | \
  xargs -0 sed -i '' \
    's|seafileltd/seafile-pro-mc|tengis/tengis-wiki|g; s|seafileltd/seafile-mc|tengis/tengis-wiki|g'
```

| Before | After |
|---|---|
| `seafileltd/seafile-mc:*` | `tengis/tengis-wiki:*` |
| `seafileltd/seafile-pro-mc:*` | `tengis/tengis-wiki:*` |

**Pass 2 — Operator echo status messages (16 files, 28 lines):**

```bash
grep -rl 'echo.*Seafile' build/ scripts/ | \
  xargs sed -i '' '/echo/s/Seafile/Tengis Wiki/g'
```

| Before | After |
|---|---|
| `"Seafile CE: Stop Seafile..."` | `"Tengis Wiki CE: Stop Tengis Wiki..."` |
| `"Info: Seafile Version [ ${tag} ]"` | `"Info: Tengis Wiki Version [ ${tag} ]"` |
| `"Seafile cluster conf not exists!"` | `"Tengis Wiki cluster conf not exists!"` |

**Pass 3 — External URLs (9 files):**

```bash
grep -rl 'seafile\.com\|seafileltd\.com\|manual\.seafile\.com' README.md README.pro.md scripts/ | \
  xargs sed -i '' \
    "s|https://[a-zA-Z0-9._-]*seafile\.com/[^)'\" ]*|https://redirish.global|g; \
     s|https://[a-zA-Z0-9._-]*seafileltd\.com/[^)'\" ]*|https://redirish.global|g"
```

---

### 4.5 What Was NOT Changed (Intentionally)

| Item | Reason |
|---|---|
| `ENV SEAFILE_SERVER`, `ENV SEAFILE_VERSION` in Dockerfiles | Backend config keys — application reads these by name |
| `/opt/seafile/`, `/shared/seafile/` volume paths | Filesystem paths the application reads by convention |
| `seafileformat` in nginx.conf | Internal nginx log format identifier |
| `seafile.nginx.conf` filename | Config file the application looks for by this exact name |
| Linux system user/group `seafile` | OS-level user — changing breaks file permissions |
| `seafile.sh`, `seahub.sh` binary names | Application binaries called by name in scripts |
| `seafile-data/` directory name | Data directory the application expects at this path |
| `$SEAFILE_SERVER`, `$SEAFILE_DIR` env var references | Shell variable names used throughout scripts |
| `docker.seafile.top` registry hostname | Alternative mirror registry, not a brand identifier, not used in our deployment |
| `LICENSE.txt` — `Copyright (c) 2016 Seafile Ltd.` | Legally required upstream attribution under Apache 2.0 |
| Build-time git clone URLs for haiwen/seafile-server | Source code fetch URLs — internal to build process |

---

### 4.6 CLAUDE.md Key Rules (Docker Repo)

In addition to all rules from `tengis-wiki-fr` CLAUDE.md, the docker repo adds:

- Before making any changes, always read `PATHS.md` first
- Container names must use `tengis-` prefix
- Image names must not reference `seafile` or `seafileltd`
- Version labels must say "Tengis Wiki"
- Service keys in docker-compose must use `tengis-*` naming
- `docker.seafile.top` registry hostname is intentionally preserved — do not replace it
- Never touch internal env variable names (`$SEAFILE_SERVER`, `$SEAFILE_DIR`, etc.)
- Never touch volume mount paths (`/opt/seafile/`, `/shared/seafile/`)

---

### 4.7 License Compliance Note

`LICENSE.txt` contains: `Copyright (c) 2016 Seafile Ltd.`

This **must not be removed or replaced**. It is a legally required upstream attribution under the Apache 2.0 license. Removing it would violate the license terms.

If Tengis wants to add its own copyright, add it as a **second line**:
```
Copyright (c) 2016 Seafile Ltd.
Copyright (c) 2026 Tengis
```

---

## SECTION 5 — Custom Docker Image Build

This section documents the full custom image build process, decisions made, and all commands used.

---

### 5.0 State Before This Session

Before the custom image build session, the deployment was running as:
- Base image: `seafileltd/seafile-mc:13.0-latest` retagged as `tengis-wiki:13.0`
- Branding files served via **bind volume mounts** from `~/tengiswiki/tengis-wiki-fr/` on the VM
- `seafile-server.yml` had 7 volume mount lines pointing to local repo files
- Network was still named `seafile-net` (not yet `tengis-net`)

This session replaced the volume mount approach with a proper baked custom image.

---

### 5.0.5 VM Resource Upgrade (Between Test Phase and Build Session)

Before the custom image build, the VM was scaled up from the test-phase specs (2 GB RAM, 2 vCPU, 20 GB disk — see §6.1) to the larger specs needed for the React build and Docker image work.

**RAM and CPU** changed in VMware settings — VM powered off, settings adjusted, powered back on.

**Disk extension** — a new 50 GB virtual disk was added as `/dev/sdb` in VMware, then incorporated into the existing LVM volume group from inside the VM:

```bash
sudo pvcreate /dev/sdb
sudo vgextend ubuntu-vg /dev/sdb
sudo lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
sudo resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv
df -h
```

**Result after upgrade:**
```
/dev/mapper/ubuntu--vg-ubuntu--lv   97G   12G   81G  13% /
```

This produced the specs shown in §5.1.

---

### 5.1 VMware Server Specs

| Item | Value |
|---|---|
| IP | 192.168.2.111 |
| OS | Ubuntu 24.04 |
| RAM | 16 GB |
| vCPUs | 4 |
| Disk | 24 GB total, ~12 GB free before build |
| User | akin |
| Deploy path | `/opt/tengis/` |
| Repos path | `~/tengiswiki/` |

---

### 5.2 Build Approach Decision

**We chose: FROM official image + COPY overlay**

Instead of building from source (which takes 1+ hour, requires C/Go/Rust/Vala compilers), we use the official `seafileltd/seafile-mc:13.0-latest` as base and overlay only the rebranded files on top.

**Why this is valid:**
- The official image has all compiled C binaries and Python deps already
- `tengis-wiki-fr` is a pure Python/Django/template rebrand — no C code changes
- CSS is served directly by nginx — no collectstatic or CSS regeneration at startup
- `media/assets/` and `frontend/build/` are NOT in `tengis-wiki-fr` — they survive from the base image automatically
- Volume mount testing already proved the overlay approach works

**What we do NOT do:**
- Full source build (unnecessary for UI-only changes)
- Symlinks in build context (unreliable)
- COPY entire `tengis-wiki-fr/` repo (wastes space, includes CLAUDE.md, git files)

---

### 5.3 Key Finding — CSS Safety

Claude Code confirmed: **no collectstatic or CSS regeneration runs at container startup.**

The startup chain is:
```
/sbin/my_init → enterpoint.sh → start.py → seahub.sh start (gunicorn)
```

None of these call `manage.py`, `collectstatic`, `compress`, `lessc`, or `webpack`. The `seafile-ui.css` file is served directly by nginx as a static file — our color changes are safe and permanent.

---

### 5.4 Key Finding — Two Issues Before Building

Claude Code caught these before creating any files:

**Issue 1 — `frontend/src/assets/` is a no-op at runtime:**
These are React source files processed by webpack into `frontend/build/`. Since we don't run `npm run build`, copying `src/assets/` has zero effect. **Decision: Drop from COPY list.**

**Issue 2 — locale `.po` files need compiled `.mo` files:**
Django reads compiled `.mo` binary files, not `.po` source files. **Decision: Compile `.mo` files first on VM, then build image.**

---

### 5.5 Compile `.mo` Locale Files (VM)

```bash
cd ~/tengiswiki/tengis-wiki-fr
sudo apt-get install -y gettext
find locale -name "*.po" | while read po; do
    msgfmt -o "${po%.po}.mo" "$po"
done
```

**Result — 7 `.mo` files generated:**
```
locale/en_US/LC_MESSAGES/djangojs.mo
locale/tr/LC_MESSAGES/djangojs.mo
locale/tr/LC_MESSAGES/django.mo
locale/id/LC_MESSAGES/djangojs.mo
locale/id/LC_MESSAGES/django.mo
locale/en/LC_MESSAGES/djangojs.mo
locale/en/LC_MESSAGES/django.mo
```

**Note:** These `.mo` files have NOT been committed to `tengis-wiki-fr` yet — this is pending.

---

### 5.6 The Dockerfile

**Path:** `~/tengiswiki/tengis-wiki-docker/Dockerfile`
**Commit:** `18ce4eb`

```dockerfile
FROM seafileltd/seafile-mc:13.0-latest

ARG SEAFILE_VERSION=13.0.21

COPY tengis-wiki-fr/media/css/             /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/media/css/
COPY tengis-wiki-fr/media/img/             /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/media/img/
COPY tengis-wiki-fr/media/favicons/        /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/media/favicons/
COPY tengis-wiki-fr/seahub/templates/      /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/seahub/templates/
COPY tengis-wiki-fr/seahub/help/templates/ /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/seahub/help/templates/
COPY tengis-wiki-fr/locale/                /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/locale/

RUN find /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
```

---

### 5.7 The .dockerignore

**Path:** `~/tengiswiki/tengis-wiki-docker/.dockerignore` (committed to repo as of commit `7d40ed3`)

```
# Exclude the docker repo itself
tengis-wiki-docker

# Exclude git history
tengis-wiki-fr/.git

# Exclude large directories not needed for the overlay
tengis-wiki-fr/frontend
tengis-wiki-fr/thirdpart
tengis-wiki-fr/static
tengis-wiki-fr/tests
tengis-wiki-fr/scripts
tengis-wiki-fr/sql
tengis-wiki-fr/tools
tengis-wiki-fr/bin
tengis-wiki-fr/fabfile

# Exclude Python app source — re-include only the two template dirs
tengis-wiki-fr/seahub
!tengis-wiki-fr/seahub/templates
!tengis-wiki-fr/seahub/help

# Exclude media in bulk — re-include only the three overlay subdirs
tengis-wiki-fr/media
!tengis-wiki-fr/media/css
!tengis-wiki-fr/media/img
!tengis-wiki-fr/media/favicons

# Exclude repo-root files that have no role in the overlay
tengis-wiki-fr/CLAUDE.md
tengis-wiki-fr/PATHS.md
tengis-wiki-fr/HACKING
tengis-wiki-fr/CONTRIBUTORS
tengis-wiki-fr/Makefile
tengis-wiki-fr/*.py
tengis-wiki-fr/*.sh
tengis-wiki-fr/*.txt
tengis-wiki-fr/*.json
tengis-wiki-fr/*.markdown
```

---

### 5.8 Build Command

Build context root is `~/tengiswiki/` — both repos must exist as siblings there.

```bash
docker build \
  -f ~/tengiswiki/tengis-wiki-docker/Dockerfile \
  --build-arg SEAFILE_VERSION=13.0.21 \
  -t tengis/tengis-wiki:13.0.21 \
  ~/tengiswiki/
```

**Result:** Image `tengis/tengis-wiki:13.0.21` — 2.39 GB, ID `8df46899cbdc`

---

### 5.9 Deployment Configuration

**File:** `/opt/tengis/seafile-server.yml`

Key changes made:
- Image changed from `seafileltd/seafile-mc:13.0-latest` → `tengis/tengis-wiki:13.0.21`
- All `seafile-net` references → `tengis-net`
- All volume mounts pointing to `tengiswiki/tengis-wiki-fr` removed (files are baked in)

```bash
# Apply network rename
sed -i 's/seafile-net/tengis-net/g' seafile-server.yml

# Apply image rename
sed -i 's|image: ${SEAFILE_IMAGE:-tengis-wiki:13.0}|image: tengis/tengis-wiki:13.0.21|g' seafile-server.yml
```

**⚠️ IMPORTANT:** `seafile-server.yml` is NOT in any git repo. Back it up manually after every change:
```bash
cp /opt/tengis/seafile-server.yml /opt/tengis/seafile-server.yml.bak
```

---

### 5.10 Deployment Commands

```bash
cd /opt/tengis
docker compose up -d
```

**Verify running containers:**
```bash
docker ps
```

Expected output — only these containers, no "seafile" names:
- `tengis-wiki` — `tengis/tengis-wiki:13.0.21`
- `tengis-redis` — `redis`
- `tengis-db` — `mariadb:10.11`

**Verify overlay files inside container:**
```bash
docker exec tengis-wiki ls /opt/seafile/seafile-server-13.0.21/seahub/media/css/seafile-ui.css
docker exec tengis-wiki ls /opt/seafile/seafile-server-13.0.21/seahub/seahub/templates/
```

---

### 5.11 Rebuild Process (After Future Changes)

Every time `tengis-wiki-fr` is updated:

```bash
# On VM — rebuild image
docker build \
  -f ~/tengiswiki/tengis-wiki-docker/Dockerfile \
  --build-arg SEAFILE_VERSION=13.0.21 \
  -t tengis/tengis-wiki:13.0.21 \
  ~/tengiswiki/

# Redeploy
cd /opt/tengis
docker compose down
docker compose up -d
```

The base image layer is cached — rebuilds are fast (seconds, not minutes).

---

### 5.12 Current Status After Build Session

| Item | Status |
|---|---|
| Custom image | ✅ `tengis/tengis-wiki:13.0.21` running |
| CSS (seafile-ui.css) | ✅ Overlaid — but `--bs-primary-rgb` needs fix |
| Templates | ✅ Overlaid and confirmed |
| Help templates | ✅ Overlaid and confirmed |
| Images (media/img/) | ✅ Overlaid |
| Favicons | ✅ Overlaid (clear browser cache to see) |
| Locale .mo files | ✅ Compiled — ⚠️ NOT committed to repo yet |
| Network | ✅ `tengis-net` — no seafile names |
| Container names | ✅ All `tengis-*` |
| Site title | ⚠️ Needs fix via admin panel |
| Colors in React UI | ⚠️ `--bs-primary-rgb` wrong value — needs fix + rebuild |
| About dialog | ⚠️ Needs frontend build |
| System Info page | ⚠️ "Community Edition" string — needs `info.js` edit + frontend build |

---

### 5.13 Pending Fixes (Tomorrow's Work Order)

**Fix 1 — CSS `--bs-primary-rgb` (Mac, Claude Code):**

File: `~/tengiswiki/tengis-wiki-fr/media/css/seafile-ui.css`

```css
/* Wrong — orange */
--bs-primary-rgb: 255,128,0

/* Correct — Tengis Blue */
--bs-primary-rgb: 74,78,199
```

**Fix 2 — Site Title (VM admin panel):**
1. Go to `http://192.168.2.111/sys/settings/`
2. Log in as admin
3. Change Site Title → `Tengis Wiki`
4. Save

**Fix 3 — `info.js` Community Edition string (Mac, Claude Code):**

File: `~/tengiswiki/tengis-wiki-fr/frontend/src/pages/sys-admin/info.js`
- Line 110: `'Community Edition'` → `'Tengis Wiki'`
- Line 111: URL `https://seafile.com/...` → `https://redirish.global`, text `'Upgrade to Pro Edition'` → `'Tengis Wiki'`

**Fix 4 — Frontend build (VM):**

```bash
# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install dependencies
cd ~/tengiswiki/tengis-wiki-fr/frontend
npm install

# Build (~10-15 min)
npm run build
# Output: ~/tengiswiki/tengis-wiki-fr/frontend/build/
```

**Fix 5 — Update Dockerfile after frontend build:**

Add this COPY line after the existing ones:
```dockerfile
COPY tengis-wiki-fr/frontend/build/ /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/frontend/build/
```

Update `.dockerignore` — replace:
```
tengis-wiki-fr/frontend
```
With:
```
tengis-wiki-fr/frontend/src
tengis-wiki-fr/frontend/node_modules
tengis-wiki-fr/frontend/scripts
```

**Fix 6 — Commit `.mo` files:**
```bash
cd ~/tengiswiki/tengis-wiki-fr
git add locale/
git commit -m "build: add compiled .mo locale files"
git push origin master
```

---

### 5.14 Enable Wiki Feature (Future)

The Wiki feature requires SeaDoc. To enable:

1. Edit `/opt/tengis/.env`:
```
ENABLE_SEADOC=true
COMPOSE_FILE=seafile-server.yml,seadoc.yml
```

2. Download `seadoc.yml`:
```bash
wget https://manual.seafile.com/13.0/repo/docker/seadoc.yml -O /opt/tengis/seadoc.yml
```

3. Restart stack:
```bash
cd /opt/tengis
docker compose down
docker compose up -d
```

---

## APPENDIX A — Wiki Feature (SeaDoc Integration)

### A.1 Overview

The Wiki feature in Seafile/Tengis Wiki 12.0+ depends entirely on **SeaDoc**. Without SeaDoc running, the Wiki tab appears in the UI but documents cannot be created or edited — even with plain Markdown.

**Key facts:**
- `ENABLE_WIKI = True` in `seahub_settings.py` only enables the old legacy wiki
- The new Wiki feature is controlled by SeaDoc being enabled
- SeaDoc adds one additional Docker container (~500MB image)
- Your VM (16GB RAM) can handle it comfortably

---

### A.2 What SeaDoc Adds

| Component | Purpose |
|---|---|
| `seadoc` container | Collaborative document editing engine |
| Port 7070 | Internal SeaDoc server port |
| `ENABLE_SEADOC=true` | Enables SeaDoc in seahub_settings.py |
| Excalidraw whiteboard | Also enabled via SeaDoc |

---

### A.3 Enable Wiki on VM

**Step 1 — Download seadoc.yml:**
```bash
cd /opt/tengis
wget https://manual.seafile.com/13.0/repo/docker/seadoc.yml -O seadoc.yml
```

**Step 2 — Edit `.env`:**
```bash
nano /opt/tengis/.env
```

Add or change these lines:
```
ENABLE_SEADOC=true
COMPOSE_FILE=seafile-server.yml,seadoc.yml
```

**Step 3 — Restart stack:**
```bash
cd /opt/tengis
docker compose down
docker compose up -d
```

**Step 4 — Verify:**
```bash
docker ps
```

You should now see a `seadoc` container running alongside `tengis-wiki`, `tengis-redis`, `tengis-db`.

**Step 5 — Test in browser:**
1. Log into Tengis Wiki
2. Click **Wiki** in the left navigation
3. Create a new wiki — it should open the SeaDoc editor

---

### A.4 Rebranding SeaDoc (Future)

`seadoc.yml` uses the official `seafileltd/sdoc-server` image. If you want to rebrand the SeaDoc editor interface, that requires a separate fork of the SeaDoc frontend — out of scope for this session but noted for future work.

---

### A.5 SeaDoc Behind a Reverse Proxy

**Currently relevant:** No — the active Tengis Wiki deployment on `192.168.2.111` is HTTP-only with no reverse proxy.
**Becomes relevant:** The moment Tengis Wiki is deployed behind SSL with a real domain (nginx, Caddy, traefik, or any other reverse proxy).

This subsection captures hard-won operational knowledge from the production nexus2.redirish.dev deployment (stock Seafile 13 + SeaDoc 2.0.9 behind mailcow nginx). The routing pattern is universal — it applies to any reverse proxy in front of any SeaDoc deployment, including future Tengis Wiki ones.

#### A.5.1 Why this matters

SeaDoc is a **separate container** from Seafile. The Seafile container does not proxy SeaDoc requests internally. The browser hits `/sdoc-server/` for every wiki page open, markdown import, document conversion, and collaborative-editing session. Without an explicit reverse-proxy rule for `/sdoc-server/`, those requests either hit a dead end (500 error) or — worse — get forwarded to the seafile container, which silently returns wrong responses.

When this is misconfigured, the symptoms are subtle: wiki pages appear blank, markdown imports fail without a clear error, documents open but auto-save silently breaks. The seafile log shows nothing; only the seadoc log reveals that requests never arrived.

#### A.5.2 The required routing pattern

Two `location` blocks are required for any reverse proxy in front of SeaDoc:

```nginx
# ── SeaDoc API and document server ─────────────────────────────────
location /sdoc-server/ {
    proxy_pass http://<seadoc-container>/;

    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    proxy_read_timeout 3600;
    client_max_body_size 100m;
}

# ── SeaDoc WebSocket for real-time collaborative editing ───────────
location /socket.io/ {
    proxy_pass http://<seadoc-container>/socket.io/;

    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    proxy_set_header Host $host;
    proxy_read_timeout 3600;
}
```

For Tengis Wiki, `<seadoc-container>` would be the SeaDoc service name on `tengis-net` (e.g., `tengis-seadoc`).

#### A.5.3 The trailing-slash mechanic (most easily missed)

The single most important detail in the routing above is the trailing slash in `proxy_pass http://<seadoc-container>/`.

- **With trailing slash** (`http://seadoc/`) → nginx strips the `/sdoc-server` prefix before forwarding. SeaDoc receives clean internal paths like `/api/v1/docs/abc123/`. ✅ Works.
- **Without trailing slash** (`http://seadoc`) → nginx forwards the full path. SeaDoc receives `/sdoc-server/api/v1/docs/abc123/`, doesn't recognize the prefixed routes, and returns 404 for everything. ❌ Silently broken.

This is the one detail that takes the longest to debug if missed, because the proxy and the container both look healthy.

#### A.5.4 WebSocket headers

The `Upgrade` and `Connection: "upgrade"` headers on both blocks are required for SeaDoc's socket.io real-time sync. Without them, documents open but live collaboration and auto-save break. Long timeouts (`proxy_read_timeout 3600`) prevent the proxy from killing long-lived WebSocket connections.

#### A.5.5 Body size

`client_max_body_size 100m` on `/sdoc-server/` covers large markdown imports and document conversions. The default of 1 MB is far too small for typical wiki content with images.

#### A.5.6 Reverse-proxy networking

Whatever container runs the reverse proxy (nginx, Caddy, etc.) must be attached to the same Docker network as the seafile and seadoc containers so it can resolve them by name. On the current Tengis stack that network is `tengis-net`; on the nexus2 production stack it is `seafile-net`.

> **⚠️ Stability risk:** If the reverse-proxy container is part of a separate compose stack (e.g., mailcow), the `docker network connect` is a manual operation. It survives reboots but **is lost whenever the proxy container is recreated** (compose pulls a new image, upgrades, etc.). After any such event, re-run `docker network connect <network> <proxy-container>` and reload the proxy.

---

### A.6 SeaDoc Operational Reference

Once SeaDoc is enabled, the following references apply regardless of which reverse-proxy fronting it.

#### A.6.1 SeaDoc log files

All seven SeaDoc logs live in the `seadoc-data` volume under `logs/` (typical host path: `/opt/seadoc-data/logs/`).

| File | What it captures |
|---|---|
| `sdoc-access.log` | Every API request — method, URL, status, response time |
| `sdoc-access-slow.log` | Slow requests only (above SeaDoc's configured threshold) |
| `sdoc-server.log` | Background autosave tasks, service health, startup |
| `sdoc-socket.log` | Real-time collaborative editing over WebSocket |
| `sdoc-socket-slow.log` | Slow socket operations |
| `sdoc_operation_log_clean.log` | Periodic DB cleanup task |
| `seadoc-converter.log` | File conversion tasks (md→sdoc, sdoc→docx, etc.) |

Useful commands:

```bash
# Watch the three most operationally important logs simultaneously
sudo tail -f /opt/seadoc-data/logs/sdoc-server.log \
            /opt/seadoc-data/logs/sdoc-access.log \
            /opt/seadoc-data/logs/sdoc-socket.log

# Watch via Docker (no sudo)
docker logs <seadoc-container> --tail 50 --follow

# Check converter tasks specifically (markdown imports, docx exports)
sudo tail -50 /opt/seadoc-data/logs/seadoc-converter.log
```

#### A.6.2 Verification commands

These tests confirm a SeaDoc deployment is correctly wired end-to-end. They are stack-agnostic — only the container and host names change.

```bash
# 1. Internal reachability — from inside the seafile container to seadoc
docker exec <seafile-container> curl -s http://<seadoc-container>/
# Expected: "Welcome to sdoc-server. The current version is X.X.X"
# If this fails: containers not on the same Docker network, or seadoc not running
```

```bash
# 2. External converter endpoint reachable via reverse proxy
curl -s -X POST https://<public-host>/sdoc-server/converter/api/v1/sdoc-export-to-docx/
# Expected: {"error_msg":"Permission denied"}
# This is the GOLD-STANDARD success signal:
# - Request reached SeaDoc (routing is correct)
# - SeaDoc rejected on auth (expected without a valid token)
# If you get 502/504: routing is broken (likely missing trailing slash in proxy_pass)
# If you get 404: location block missing or wrong prefix
```

```bash
# 3. Reverse-proxy config validation and reload (nginx example)
docker exec <nginx-container> nginx -t
docker exec <nginx-container> nginx -s reload
```

**Verified on production nexus2 (29 May 2026):** SeaDoc 2.0.9, all three tests pass, routing pattern confirmed correct in live use.

#### A.6.3 JWT authentication between Seahub and SeaDoc

Seahub and SeaDoc communicate via JWT tokens signed with a shared key. In a typical compose deployment this is either `JWT_PRIVATE_KEY` (shared across services) or a dedicated `SEADOC_PRIVATE_KEY`. The pattern in the active Tengis `.env` uses `JWT_PRIVATE_KEY` for both Seafile-AI and SeaDoc — see the `SEAFILE_AI_SECRET_KEY` line in `/opt/tengis/.env`.

If SeaDoc API calls start returning `Unauthorized` intermittently, the likely causes are, in order:
1. **Key mismatch** between Seahub's `seahub_settings.py` and the SeaDoc service environment
2. **Container clock skew** — JWT validation is time-sensitive; if the SeaDoc container's clock drifts more than the token's leeway, every request fails auth
3. **Token TTL too short** for the workload (rare in default configs)

---

### A.7 Known SeaDoc Issues

These issues were observed and confirmed in the nexus2 production deployment running stock Seafile 13 CE + SeaDoc 2.0.9. They are **CE/version issues, not branding issues**, which means they will affect Tengis Wiki the moment SeaDoc is enabled — same Seafile 13 core.

#### A.7.1 Markdown import shows "Failed" — but actually succeeds

**Severity:** False UI error, data is safe.

**Symptom:** User imports a `.md` file as a wiki page. The browser displays "Failed to import page". But refreshing the wiki shows the imported page is actually there with correct content.

**Root cause:** Seahub submits an async task to seafevents, which completes successfully (`seafevents.log` shows `Run task success: <id> import_wiki_page cost 0s`). The browser then polls `/api/v2.1/query-io-status/` to confirm — but **that endpoint does not exist in Seafile 13 CE**. The polling call returns 404, the browser interprets it as failure, and shows the error toast. The actual file is fine.

**Workaround:** Ignore the error message. After "Failed to import page", refresh the wiki — the content is there.

**Long-term fix:** Either the endpoint gets added in a later Seafile 13 point release, or the frontend stops polling. Worth checking the Seafile changelog before each upgrade.

#### A.7.2 Wiki publish returns 400 Bad Request

**Severity:** Feature broken, under investigation.

**Symptom:** Attempting to publish a wiki returns:

```
Bad Request: /api/v2.1/wiki2/<uuid>/publish/
Not Found: /wiki/publish/
```

The publish API route exists and matches — routing is fine — but the handler rejects the request body. Most likely cause is a missing required field (probably a URL slug for the public publish URL) or a role permission denied.

**Diagnostic steps:**
1. Open browser DevTools → Network tab
2. Attempt to publish a wiki
3. Capture the exact `/publish/` request payload and response body
4. Check `can_publish_wiki = True` in `seahub_settings.py` or under Admin Panel → Roles

**Status as of v1.5:** Not yet diagnosed on nexus2 production. Same regression will hit Tengis Wiki when SeaDoc is enabled.

#### A.7.3 Intermittent "Unauthorized" on SeaDoc API endpoints

**Severity:** Low — does not block basic functionality.

**Symptom:** Opening a document occasionally logs:

```
Unauthorized: /api/v2.1/seadoc/notifications/<uuid>/
Unauthorized: /api/v2.1/seadoc/participants/<uuid>/
```

**Likely cause:** JWT token timing or expiration race between Seahub and SeaDoc — see A.6.3. Monitor frequency; if it becomes common, audit `JWT_PRIVATE_KEY` consistency across containers and check for clock skew between Seafile and SeaDoc containers (`docker exec <container> date`).

---

## APPENDIX B — Pending Work Tracker

Last updated: v1.6 (May 2026). All B.1 items from v1.3 are now complete. B.2 reflects the current state after the full build, deploy, and documentation sprint.

---

### B.1 Completed (as of v1.6)

- [x] Fix `--bs-primary-rgb: 255,128,0` → `74,78,199` in `media/css/seafile-ui.css`
- [x] Edit `info.js` line 110: `'Community Edition'` → `'Tengis Wiki'`
- [x] Edit `info.js` line 111: URL → `https://redirish.global`, text → `'Tengis Wiki'`
- [x] Run `npm install` in `frontend/` on VM
- [x] Run `npm run build` in `frontend/` on VM
- [x] Run `collectstatic` on VM (Option J — pre-built, not inside docker build)
- [x] Add `frontend/build/` and `media/assets/` COPY lines to Dockerfile
- [x] Update `.dockerignore` at build context root `~/tengiswiki/`
- [x] Rebuild image as `tengis/tengis-wiki:13.0.21-r2`
- [x] Redeploy via `docker compose down && docker compose up -d`
- [x] Verify System Info shows "Tengis Wiki" not "Community Edition"
- [x] Commit `.mo` locale files to `tengis-wiki-fr`
- [x] Commit Dockerfile + `.dockerignore` to `tengis-wiki-docker`
- [x] Both repos clean on GitHub at final commits (`4399bc278`, `27b3a9a`)
- [x] Project documentation consolidated into three canonical docs
- [x] README written and pushed to `tengis-wiki-docker`
- [x] VM synced with docs

---

### B.2 Next Steps — Tengis Wiki VM (`192.168.2.111`)

#### Housekeeping (quick wins)

- [ ] **Fix hardcoded orange color values in React source** — `#ed7109` and `rgba(255,128,0,...)` are baked into the compiled React bundles and are not overridden by `seafile-ui.css`. Full investigation, affected file list, and step-by-step fix plan in **Appendix G**. Requires React source edit + `npm run build` + `collectstatic` + image rebuild.
- [ ] **Set Site Title via admin panel** — `http://192.168.2.111/sys/settings/` → change "Site Title" to `Tengis Wiki`. Takes 30 seconds. Only needed if not already done — verify by checking the browser tab when logged in.
- [ ] **Remove old image from VM** — `docker image rm tengis/tengis-wiki:13.0.21`. Frees 2.39 GB. Safe to do any time; the active image is `13.0.21-r2` and the rollback target is documented in the build plan v1.6 §9.5.
- [ ] **Delete obsolete documentation files from Mac** — 11 predecessor files listed in the build plan v1.6 §13 changelog (build-plan v1.0–v1.5, frontend-build v1.0, project-guide v1.3–v1.4, deployment-session, rebranding-guide).

#### Infrastructure (required before production use)

- [ ] **Set up HTTPS and a real domain** — currently HTTP-only on port 80, IP-only. Required for any production use. Recommended approach: follow the same pattern as nexus2 (mailcow nginx + ACME) — see Appendix A.5 for the SeaDoc-aware reverse-proxy pattern which will apply here too. Decide whether the Tengis VM joins the mailcow network or runs its own Caddy instance.
- [ ] **Set up automated backup** — two directories must be backed up regularly:
  - `/opt/seafile-data/` — all user files (synced file content, wiki content, thumbnails)
  - `/opt/seafile-mysql/db/` — all database data (users, permissions, file metadata, wiki structure)
  - `/opt/tengis/.env` — environment variables (JWT key, DB password, admin credentials)
  - `/opt/tengis/seafile-server.yml` — the compose file (not in git — see Appendix F)
  - Suggested approach: daily `rsync` or `borgbackup` to an offsite target, with a test restore every 30 days.
- [ ] **Push image to Docker Hub** — `docker push tengis/tengis-wiki:13.0.21-r2`. Required if deploying Tengis Wiki to other servers without rebuilding. Compressed size is 644 MB (see build plan §2). Mark the repo private if you don't want the image public.

#### Features (when ready)

- [ ] **Enable SeaDoc / Wiki feature** — procedure in Appendix A.3. Prerequisites: HTTPS must be configured first (SeaDoc's WebSocket requires a stable SSL endpoint), and the reverse-proxy routing blocks from Appendix A.5 must be in place.
- [ ] **Per-customer branding via `custom/`** — logos, colors, and site title can be delivered without rebuilding the image using Seafile's official `seahub-data/custom/` bind-mount mechanism. Full reference in `tengis-wiki-frontend-build-v1_2.md` Appendix A. Implement this before deploying to multiple customers.
- [ ] **Upstream rebase** — when Seafile releases a new version, follow the upgrade process in build plan v1.6 §14. Key pre-check: verify the `RPCProxy` pattern in `seahub/utils/__init__.py` is still present before running any build.

---

### B.3 Next Steps — Nexus2 (`nexus2.redirish.dev`)

#### Bugs under investigation

- [ ] **Wiki publish returns 400 Bad Request** — see Appendix A.7.2 for diagnosis steps. Next action: open browser DevTools → Network tab → attempt to publish a wiki → capture the exact request payload and response body. Also check `can_publish_wiki = True` in seahub_settings.py or Admin Panel → Roles. **Blocks wiki publishing for all users.**
- [ ] **Fix nginx `listen ... http2` deprecation warning** — in `/opt/mailcow-dockerized/data/conf/nginx/nexus2.conf` lines 15–16, change:
  ```nginx
  # Before
  listen 443 ssl http2;
  listen [::]:443 ssl http2;

  # After
  listen 443 ssl;
  listen [::]:443 ssl;
  http2 on;
  ```
  Then `docker exec mailcowdockerized-nginx-mailcow-1 nginx -t && docker exec mailcowdockerized-nginx-mailcow-1 nginx -s reload`. Non-blocking warning but worth cleaning up.
- [ ] **Investigate `webmail.permitly.id` conflicting server name warning** — two nginx server blocks both claim this hostname. Run `docker exec mailcowdockerized-nginx-mailcow-1 grep -rn "webmail.permitly.id" /etc/nginx/` to find the duplicate. If one is in a custom file you wrote, remove that block.

#### Known non-issues (monitor only)

- [x~~] **Markdown import shows "Failed" but succeeds** — documented CE regression in Seafile 13, no fix available yet. Workaround: ignore the error message and refresh the wiki. Track Seafile changelog for a fix in point releases. See Appendix A.7.1.
- [ ] **Intermittent "Unauthorized" on SeaDoc notification/participant endpoints** — low severity, does not block basic functionality. Monitor frequency. If it becomes regular, audit `JWT_PRIVATE_KEY` consistency across containers and check clock skew. See Appendix A.7.3.

#### Mailcow nginx fragility

- [ ] **Document the `docker network connect` command** — the mailcow nginx container must be on `seafile-net` for SeaDoc routing to work. This connection is lost whenever the nginx container is recreated (upgrades, etc.). Add a post-upgrade runbook note somewhere in your mailcow ops documentation: `docker network connect seafile-net mailcowdockerized-nginx-mailcow-1` followed by nginx reload.

---

## APPENDIX C — Corrections & Missing Items

### C.1 Version History

| Version | Date | Changes |
|---|---|---|
| v1.0 | May 2026 | Initial guide — rebranding session (tengis-wiki-fr + tengis-wiki-docker) |
| v1.1 | May 2026 | Build session — custom image, deployment, appendices added |
| v1.2 | May 2026 | Added Section 6 — full test deployment session log, Docker install, all sed commands, .env reference, volume mount phase, decisions table |
| v1.3 | May 2026 | Added Appendix D — full Claude Code analysis log (16 entries), Appendix E — new session handoff note, all CSS/info.js fixes documented |
| v1.4 | May 2026 | Added repo visibility history note (§1.5); added §5.0.5 VM resource upgrade with LVM disk extension recipe; added Appendix F — pre-custom-image `seafile-server.yml` snapshot, extended `.env` reference, plus two operational techniques (`docker compose config` validation, container path discovery). Content preserved before deletion of the separate 25 May 2026 deployment session log. |
| v1.5 | May 2026 | Extended Appendix A with operational knowledge extracted from the production nexus2.redirish.dev deployment (stock Seafile 13 + SeaDoc 2.0.9 behind mailcow nginx): A.5 SeaDoc reverse-proxy routing requirements, A.6 SeaDoc operational reference (log file inventory, verification commands, JWT auth), A.7 known SeaDoc issues (markdown-import false error, wiki-publish 400, intermittent JWT unauthorized). All content generalized so it applies to Tengis Wiki when SeaDoc is eventually enabled. |
| v1.6 | May 2026 | Appendix B fully rewritten — all B.1 items marked complete (the entire build, deploy, and documentation sprint is done), B.2 expanded into a structured next-steps checklist covering both the Tengis Wiki VM and the nexus2 production deployment with every outstanding item tracked to the right appendix section. |
| v1.7 | May 2026 | Added Appendix G — Color Token Investigation. Live investigation confirmed that `seafile-ui.css` CSS variable overrides do not reach hardcoded hex/rgb values inside the React compiled bundles in `media/assets/`. Root cause, affected elements, fix approach (Option A — patch React source), and full step-by-step execution plan documented. Appendix B.2 updated to reference Appendix G. |

---

### C.2 VM Repository Setup

Both repos must also be cloned on the VMware VM for the build to work. The build context requires both repos as siblings at `~/tengiswiki/`.

```bash
# On VM — install git if needed
sudo apt-get install -y git

# Set up SSH key on VM too (same process as Mac — Section 1.4)
ssh-keygen -t ed25519 -C "sewistman@gmail.com"
cat ~/.ssh/id_ed25519.pub
# Add this key to GitHub at https://github.com/settings/ssh/new

# Clone both repos
mkdir ~/tengiswiki && cd ~/tengiswiki
git clone git@github.com:sewistman/tengis-wiki-fr.git
git clone git@github.com:sewistman/tengis-wiki-docker.git
```

---

### C.3 VM Cleanup Before Build

Before building the custom image, the test environment was wiped clean:

```bash
cd /opt/tengis
docker compose down
docker rmi tengis-wiki:13.0
docker rmi seafileltd/seafile-mc:13.0-latest
docker system prune -a
# Confirm with 'y' when prompted
```

**Result:** 164.2 MB reclaimed. All old containers, images, and build cache removed.

---

### C.4 Logo File Processing with Python Pillow

When the new logo files had wrong dimensions, we used Python Pillow to resize them correctly while preserving aspect ratio and transparency.

**Install Pillow:**
```bash
pip3 install pillow --break-system-packages
```

**Resize script used:**
```python
from PIL import Image
import os

def process_logo(src, dst, size):
    img = Image.open(os.path.expanduser(src)).convert("RGBA")
    # Crop transparent padding first
    bbox = img.getbbox()
    img = img.crop(bbox)
    # Resize preserving aspect ratio
    img.thumbnail(size, Image.LANCZOS)
    # Place on transparent canvas at correct size
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    x = (size[0] - img.width) // 2
    y = (size[1] - img.height) // 2
    canvas.paste(img, (x, y), img)
    canvas.save(os.path.expanduser(dst))
    print(f"Saved {dst}: {canvas.size}")

# Logo files — 256x64
process_logo("~/Downloads/tengis_1.png", "~/tengiswiki/tengis-wiki-fr/frontend/src/assets/seafile-logo.png", (256, 64))
process_logo("~/Downloads/tengis_1.png", "~/tengiswiki/tengis-wiki-fr/media/img/seafile-logo.png", (256, 64))
process_logo("~/Downloads/tengis_dark.png", "~/tengiswiki/tengis-wiki-fr/media/img/seafile-logo-dark.png", (256, 64))

# Favicon — 512x512
process_logo("~/Downloads/tengis_favicon.png", "~/tengiswiki/tengis-wiki-fr/media/favicons/favicon.png", (512, 512))
```

**Original source file dimensions:**
| File | Original Size | Target Size |
|---|---|---|
| `tengis_1.png` | 1024×1024 | 256×64 |
| `tengis_dark.png` | 1774×887 | 256×64 |
| `tengis_favicon.png` | 1536×1024 | 512×512 |

---

### C.5 seafile-server.yml Backup Command

```bash
cp /opt/tengis/seafile-server.yml /opt/tengis/seafile-server.yml.bak
```

To restore if something goes wrong:
```bash
cp /opt/tengis/seafile-server.yml.bak /opt/tengis/seafile-server.yml
docker compose down && docker compose up -d
```

---

### C.6 Status Corrections

**Section 5.12 correction:** The `.mo` locale files were already committed to `tengis-wiki-fr` before the build session started — the working tree was clean when checked. The "NOT committed" note in Section 5.12 is incorrect.

**Section 1.7 correction:** The "remaining" items listed are outdated. See Appendix B for the accurate current pending work tracker.

---

### C.7 Working Directory Note

During the session the local repo folder was renamed from `tengis` to `tengiswiki`:

```bash
# The folder is at:
~/tengiswiki/

# NOT at:
~/tengis/
```

All commands in this guide use `~/tengiswiki/` which is the correct path.

---

## SECTION 6 — Initial Test Deployment Session (25 May 2026)

This section documents the complete first deployment of Tengis Wiki on the VMware test server. This was the volume-mount-based test phase that validated branding files before the custom image build.

---

### 6.1 Test VM Specifications

| Item | Value |
|---|---|
| Hypervisor | VMware |
| OS | Ubuntu 24.04 Server |
| RAM | 2 GB (minimum — test only) |
| CPU | 2 vCPUs |
| Disk | 20 GB |
| IP | 192.168.2.111 |
| Username | akin |
| Hostname | wiki |

> **Note:** Minimum specs — suitable for single-person branding test only. For production see Section 6.11.

> **Note:** VM was later upgraded to 16GB RAM / 4 vCPUs for the custom image build phase.

---

### 6.2 Docker Installation on VM

```bash
sudo apt update && sudo apt install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker akin
```

**Result:**
```
Docker version 29.5.2, build 79eb04c
Docker Compose version v5.1.4
```

> After adding user to docker group — log out and back in before continuing.

---

### 6.3 Git and SSH Setup on VM

```bash
git config --global user.name "sewistman"
git config --global user.email "sewistman@gmail.com"

ssh-keygen -t ed25519 -C "sewistman@gmail.com"
cat ~/.ssh/id_ed25519.pub
```

Add the public key to GitHub at `https://github.com/settings/ssh/new` — title: `tengis-wiki-server`

**Test connection:**
```bash
ssh -T git@github.com
# Expected: Hi sewistman! You've successfully authenticated...
```

---

### 6.4 Clone Repositories on VM

```bash
mkdir ~/tengiswiki && cd ~/tengiswiki

# Private repo — SSH
git clone git@github.com:sewistman/tengis-wiki-docker.git

# Public repo — HTTPS
git clone https://github.com/sewistman/tengis-wiki-fr.git
```

---

### 6.5 Create Deployment Folder

```bash
sudo mkdir /opt/tengis
sudo chown akin:akin /opt/tengis
cd /opt/tengis
```

---

### 6.6 Download Official Seafile 13.0 Deployment Files

```bash
wget -O .env https://manual.seafile.com/13.0/repo/docker/ce/env
wget https://manual.seafile.com/13.0/repo/docker/ce/seafile-server.yml
wget https://manual.seafile.com/13.0/repo/docker/caddy.yml
```

> `caddy.yml` and `seadoc.yml` downloaded but not used in the test deployment.

---

### 6.7 Rebrand seafile-server.yml (Full Commands)

```bash
# Backup first
cp seafile-server.yml seafile-server.yml.bak

# Rename container names
sed -i 's/container_name: seafile-mysql/container_name: tengis-db/g' seafile-server.yml
sed -i 's/container_name: seafile-redis/container_name: tengis-redis/g' seafile-server.yml
sed -i 's/container_name: seafile$/container_name: tengis-wiki/g' seafile-server.yml

# Rename service keys
sed -i 's/^  db:$/  tengis-db:/g' seafile-server.yml
sed -i 's/^  redis:$/  tengis-redis:/g' seafile-server.yml
sed -i 's/^  seafile:$/  tengis-wiki:/g' seafile-server.yml

# Change image reference
sed -i 's/seafileltd\/seafile-mc:13.0-latest/tengis-wiki:13.0/g' seafile-server.yml

# Fix depends_on references
sed -i 's/      db:$/      tengis-db:/g' seafile-server.yml
sed -i 's/      redis:$/      tengis-redis:/g' seafile-server.yml

# Fix default DB host value
sed -i 's/SEAFILE_MYSQL_DB_HOST:-db/SEAFILE_MYSQL_DB_HOST:-tengis-db/g' seafile-server.yml

# Fix default Redis host value
sed -i 's/REDIS_HOST:-redis/REDIS_HOST:-tengis-redis/g' seafile-server.yml

# Uncomment ports
sed -i 's/    # ports:/    ports:/g' seafile-server.yml
sed -i 's/    #   - "80:80"/      - "80:80"/g' seafile-server.yml
```

---

### 6.8 Configure .env

**Generate JWT key:**
```bash
cat /proc/sys/kernel/random/uuid | tr -d '-' | head -c 40
# Output: b85c69cd52ae4cf8a9b943722875ebe2
```

**Apply all settings:**
```bash
sed -i "s/COMPOSE_FILE='seafile-server.yml,caddy.yml,seadoc.yml'/COMPOSE_FILE='seafile-server.yml'/g" .env
sed -i 's/SEAFILE_IMAGE=seafileltd\/seafile-mc:13.0-latest/SEAFILE_IMAGE=tengis-wiki:13.0/g' .env
sed -i 's/SEAFILE_SERVER_HOSTNAME=seafile.example.com/SEAFILE_SERVER_HOSTNAME=192.168.2.111/g' .env
sed -i 's/TIME_ZONE=Etc\/UTC/TIME_ZONE=Europe\/Istanbul/g' .env
sed -i 's/JWT_PRIVATE_KEY=/JWT_PRIVATE_KEY=b85c69cd52ae4cf8a9b943722875ebe2/g' .env
sed -i 's/SEAFILE_MYSQL_DB_HOST=db/SEAFILE_MYSQL_DB_HOST=tengis-db/g' .env
sed -i 's/SEAFILE_MYSQL_DB_PASSWORD=PASSWORD/SEAFILE_MYSQL_DB_PASSWORD=Ankara123/g' .env
sed -i 's/INIT_SEAFILE_MYSQL_ROOT_PASSWORD=ROOT_PASSWORD/INIT_SEAFILE_MYSQL_ROOT_PASSWORD=Ankara123/g' .env
sed -i 's/INIT_SEAFILE_ADMIN_EMAIL=me@example.com/INIT_SEAFILE_ADMIN_EMAIL=admin@tengis.local/g' .env
sed -i 's/INIT_SEAFILE_ADMIN_PASSWORD=asecret/INIT_SEAFILE_ADMIN_PASSWORD=Ankara123/g' .env
sed -i 's/REDIS_HOST=redis/REDIS_HOST=tengis-redis/g' .env
sed -i 's/ENABLE_SEADOC=true/ENABLE_SEADOC=false/g' .env
```

---

### 6.9 Pull and Retag Official Image

```bash
docker pull seafileltd/seafile-mc:13.0-latest
docker tag seafileltd/seafile-mc:13.0-latest tengis-wiki:13.0
docker images
```

**Result:**
```
IMAGE                              ID             DISK USAGE
seafileltd/seafile-mc:13.0-latest  1e335e704bb0   2.38GB
tengis-wiki:13.0                   1e335e704bb0   2.38GB
```

Both point to same image ID — retag confirmed.

---

### 6.10 Volume Mount Test Phase

Before the custom image build, branding files were mounted as volumes to validate they worked correctly. This is the test phase — NOT the production approach.

**Volume mounts used in `seafile-server.yml`:**
```yaml
volumes:
  - /home/akin/tengiswiki/tengis-wiki-fr/media/img/seafile-logo.png:/opt/seafile/seafile-server-13.0.21/seahub/media/img/seafile-logo.png
  - /home/akin/tengiswiki/tengis-wiki-fr/media/img/seafile-logo-dark.png:/opt/seafile/seafile-server-13.0.21/seahub/media/img/seafile-logo-dark.png
  - /home/akin/tengiswiki/tengis-wiki-fr/media/favicons/favicon.png:/opt/seafile/seafile-server-13.0.21/seahub/media/favicons/favicon.png
  - /home/akin/tengiswiki/tengis-wiki-fr/media/css/seafile-ui.css:/opt/seafile/seafile-server-13.0.21/seahub/media/css/seafile-ui.css
  - /home/akin/tengiswiki/tengis-wiki-fr/seahub/templates:/opt/seafile/seafile-server-13.0.21/seahub/seahub/templates
  - /home/akin/tengiswiki/tengis-wiki-fr/locale:/opt/seafile/seafile-server-13.0.21/seahub/locale
  - /home/akin/tengiswiki/tengis-wiki-fr/seahub/help/templates:/opt/seafile/seafile-server-13.0.21/seahub/seahub/help/templates
```

> These volume mounts were removed after the custom image was built — files are now baked into the image.

---

### 6.10 Test Phase Findings

| Finding | Status |
|---|---|
| `docker ps` shows only `tengis-*` names | ✅ Confirmed |
| `docker ps` shows `tengis-wiki:13.0` image | ✅ Confirmed |
| Tengis logos visible in browser | ✅ Confirmed |
| Tengis color palette applied | ✅ Confirmed |
| Help page text rebranded | ⬜ Needs verification after restart |
| `docker logs` still shows `server name: seafile` | ⚠️ Internal script — fixed by custom image build |
| `docker network ls` shows `seafile-net` | ⚠️ Fixed in custom image build phase |
| JS compiled strings (about dialog etc.) | ⚠️ Requires frontend build |

---

### 6.11 Deployment Decisions Explained

| Decision | Reason |
|---|---|
| Skipped Caddy | Needs real domain + HTTPS — test uses plain IP `192.168.2.111` |
| Skipped SeaDoc | Heavy extra container, not needed for branding verification |
| Used official image + retag | Avoids full build on 2GB RAM test VM |
| Volume mount instead of build | Fastest way to verify rebranding files are correct |
| Left `seafile-net` network name | Test phase only — fixed in custom image build |
| Left env variable names unchanged | CLAUDE.md rule: never rename internal variable names |
| Left volume mount paths unchanged | CLAUDE.md rule: never touch volume mount paths |

---

### 6.12 Reference: Final .env File

```env
COMPOSE_FILE='seafile-server.yml'
COMPOSE_PATH_SEPARATOR=','

SEAFILE_IMAGE=tengis-wiki:13.0
SEAFILE_DB_IMAGE=mariadb:10.11
SEAFILE_REDIS_IMAGE=redis

BASIC_STORAGE_PATH=/opt
SEAFILE_VOLUME=$BASIC_STORAGE_PATH/seafile-data
SEAFILE_MYSQL_VOLUME=$BASIC_STORAGE_PATH/seafile-mysql/db

SEAFILE_SERVER_HOSTNAME=192.168.2.111
SEAFILE_SERVER_PROTOCOL=http
TIME_ZONE=Europe/Istanbul
JWT_PRIVATE_KEY=b85c69cd52ae4cf8a9b943722875ebe2

SEAFILE_MYSQL_DB_HOST=tengis-db
SEAFILE_MYSQL_DB_USER=seafile
SEAFILE_MYSQL_DB_PASSWORD=Ankara123
SEAFILE_MYSQL_DB_CCNET_DB_NAME=ccnet_db
SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=seafile_db
SEAFILE_MYSQL_DB_SEAHUB_DB_NAME=seahub_db

CACHE_PROVIDER=redis
REDIS_HOST=tengis-redis
REDIS_PORT=6379
REDIS_PASSWORD=

INIT_SEAFILE_MYSQL_ROOT_PASSWORD=Ankara123
INIT_SEAFILE_ADMIN_EMAIL=admin@tengis.local
INIT_SEAFILE_ADMIN_PASSWORD=Ankara123

ENABLE_SEADOC=false
ENABLE_NOTIFICATION_SERVER=false
ENABLE_SEAFILE_AI=false
```

---

### 6.13 Production VM Recommended Specs

For production deployment (not test):

| Item | Recommended |
|---|---|
| RAM | 4 GB minimum, 8 GB recommended |
| CPU | 4 vCPUs |
| Disk | 50 GB minimum |
| OS | Ubuntu 24.04 Server |
| Network | Real domain with DNS, HTTPS via Caddy |
| SeaDoc | Enable if Wiki feature needed |

---

## APPENDIX D — Claude Code Analysis & Comments Log

This appendix captures all significant Claude Code analysis outputs, warnings, and recommendations from the session. Useful for reviewing decisions made and understanding why certain approaches were taken.

---

### D.1 Initial Seahub Analysis (tengis-wiki-fr)

**Context:** First analysis of the seahub codebase to find all "Seafile" occurrences.

**Finding:**
- 6 JS source strings found in user-facing UI
- 25+ help page templates with "Seafile" text
- All locale `.po` files with "Seafile" strings
- CSS occurrences are internal class names only — not visible to users
- `{{ site_name }}` template variable used in emails is already brand-neutral

**Claude Code note:**
> "The CSS occurrences are internal class names/comments only — not rendered as visible text. The {{ site_name }} template variable used in emails is dynamically configured, so those are already brand-neutral."

---

### D.2 Webhook Header Warning

**Context:** During JS string replacement, Claude Code flagged change #2.

**Claude Code warning:**
> "Note: X-Seafile-Signature is the actual header name sent by the server. If the backend still sends that header, renaming it here would mislead users. I'd recommend just replacing the brand word in surrounding prose only."

**Decision:** Left `X-Seafile-Signature` unchanged — protocol identifier.

---

### D.3 seahub-db Warning

**Context:** During admin settings string replacement.

**Claude Code warning:**
> "Note: seahub-db is the actual database name. Renaming it in the UI could confuse admins who need to find it. I'd suggest keeping seahub-db as-is here since it's a technical brand name."

**Decision:** Left `seahub-db` unchanged — actual database name.

---

### D.4 CSS Color Variables Analysis

**Context:** Finding where brand colors are defined.

**Claude Code finding:**
> "frontend/src/css/layout.css — consumes Bootstrap variables only, defines no color values of its own. All color references are via var(--bs-*) calls. media/css/seafile-ui.css — defines the full :root token set."

**Key tokens identified for change:**
- `--bs-primary: #ff8000` → `#4A4EC7`
- `--bs-link-color: #ff8000` → `#4A4EC7`
- `--bs-link-hover-color: #c60` → `#3a3ea0`
- `--bs-body-color: #212529` → `#0D0D0D`

**Claude Code warning on body-bg:**
> "--bs-body-bg: #F4F4F6 will make the entire page background slightly gray instead of white. Looking at the brand guide, white is the document background. I'd keep body-bg as #ffffff."

**Decision:** Left `--bs-body-bg` as `#fff` unchanged.

---

### D.5 CSS Minified File Warning

**Context:** Applying color changes to `seafile-ui.css`.

**Claude Code note:**
> "All 4 are distinct non-overlapping strings in the minified file, so I'll apply them in parallel. The verify shows some changes didn't apply and there's an unexpected --bs-body-bg:#090909. Let me investigate... The file has multiple contexts for those properties (light/dark/navbar). The primary-only sed worked but the others need targeting — they appear in multiple rules. Let me apply the remaining 3 with Python to be precise, targeting only the :root definition block."

**Lesson:** Minified CSS files need Python for precision targeting, not simple sed.

---

### D.6 Email Templates Finding

**Context:** Checking email templates for "Seafile" strings.

**Claude Code finding:**
> "The 18 email template files found by name (*email*, *mail*) do not contain the literal string 'Seafile' — they already use {{ site_name }} for the brand name, which is dynamic and correct."

**Only actionable file:** `download.html` — 2 lines with hardcoded "Seafile" text.

---

### D.7 Final Grep Result (tengis-wiki-fr)

**Context:** Post-rebranding verification.

**Claude Code report:**
> "Zero user-facing strings remain. Every remaining hit is a non-user-facing internal identifier."

| Category | Examples | Status |
|---|---|---|
| JS identifiers | `enableSeafileAI`, `SeafileCodeMirror` | Leave — internal code |
| Import paths | `@seafile/comment-editor` | Leave — module names |
| HTTP header | `X-Seafile-Signature` | Leave — protocol identifier |
| msgid lookup keys | All msgid "Seafile" in .po files | Leave — translation keys |
| .po file metadata | `# Seafile Info <info@seafile.com>` | Leave — internal metadata |
| User-facing strings | (none) | Clean ✅ |

---

### D.8 Docker Repo Analysis

**Context:** Analysis of `tengis-wiki-docker` before rebranding.

**Claude Code categorization:**

**User-facing (changed):**
- Docker image registry names in 7 push/build scripts — `seafileltd/seafile-mc` → `tengis/tengis-wiki`
- Operator echo status messages in `seafile-build.sh` (×4 versions) and `gc.sh`/`cluster_server.sh` (×7 versions)

**Internal (never touched):**
- `ENV SEAFILE_SERVER`, `ENV SEAFILE_VERSION` in Dockerfiles
- `/opt/seafile/`, `/shared/seafile/` volume paths
- `seafileformat` nginx log format identifier
- Linux system user/group `seafile`
- Binary names: `seafile.sh`, `seahub.sh`
- `$SEAFILE_SERVER`, `$SEAFILE_DIR` env var references

---

### D.9 Docker Repo URL Scope Check

**Context:** Before replacing seafile.com URLs in docker repo.

**Claude Code finding:**
> "No matches in build/. The previous scope was sufficient — build/ is clean. Ready to run the command as shown when you confirm."

---

### D.10 License Compliance Warning

**Context:** Final grep of `tengis-wiki-docker`.

**Claude Code warning:**
> "LICENSE.txt:1 names the original copyright holder under Apache 2.0. This is not a product branding string — it's a legally required upstream attribution. Replacing it would misrepresent the origin of the code and could create a license compliance issue. It should remain unchanged. If Tengis Wiki wants its own copyright line, it should be added as a second line, not a replacement."

**Decision:** `LICENSE.txt` left unchanged. If Tengis copyright needed, add as second line:
```
Copyright (c) 2016 Seafile Ltd.
Copyright (c) 2026 Tengis
```

---

### D.11 Custom Image Build Approach Validation

**Context:** Decision between full source build vs FROM + overlay.

**Claude Code analysis:**
> "Yes — it's the right approach. The official seafileltd/seafile-mc:13.0-latest image already has all compiled C binaries and all Python deps installed. Tengis-wiki-fr is a pure Python/Django/template rebrand — no C code changes. You only need to replace the seahub/ subtree, which is just files on disk."

**Risks flagged:**
- Path is patch-version-specific — if base tag updates, path breaks. Mitigation: pin `ARG SEAFILE_VERSION`
- Upstream image updates silently change seahub — `13.0-latest` is a moving tag. Mitigation: pin digest
- `__pycache__` stale bytecode. Mitigation: `RUN find ... -name '__pycache__' -exec rm -rf {} +`
- Extra image layer size — cosmetic, acceptable

---

### D.12 CSS collectstatic Safety Check

**Context:** Verifying CSS changes survive container startup.

**Claude Code finding:**
> "The container startup chain does zero CSS compilation and zero collectstatic. Tracing it exactly: /sbin/my_init → enterpoint.sh → start.py → seahub.sh start (gunicorn). None of those steps call manage.py, collectstatic, compress, lessc, sass, or webpack."

**Key finding:**
> "media/assets/ does not exist in tengis-wiki-fr. The base image has a pre-built media/assets/ from when that image was constructed. When you COPY tengis-wiki-fr/ over the seahub dir, you will not overwrite media/assets/ — the base image's copy survives intact."

---

### D.13 Two Issues Before Dockerfile Creation

**Context:** Claude Code review of the build plan before creating files.

**Issue 1 — `frontend/src/assets/` is a no-op:**
> "frontend/src/assets/ contains 165 SVG/PNG icons and the logo — these are React source files, not served files. They go through webpack to produce frontend/build/, which is what the running container actually serves. Copying frontend/src/assets/ into the container has zero effect on what users see."

**Decision:** Dropped from COPY list.

**Issue 2 — locale `.po` files need compiled `.mo` files:**
> "Django reads compiled .mo binaries at runtime, not .po source files. The locale dir in tengis-wiki-fr has only .po files — no .mo files were found."

**Decision:** Compiled `.mo` files first on VM using `msgfmt`.

---

### D.14 Dockerfile File Mix-up Warning

**Context:** First attempt to create Dockerfile and .dockerignore.

**What happened:** Claude Code wrote Dockerfile content into `.dockerignore` and vice versa on the first attempt.

**Resolution:** Deleted both files and recreated correctly with explicit path confirmation before writing.

**Lesson:** Always verify file contents with `cat` after Claude Code creates files, especially when creating multiple files in the same operation.

---

### D.15 Build Plan Review — 4 Issues Flagged

**Context:** Final review before frontend build.

**Issue 1 — Memory conflict:**
> "Memory from a previous session says tengis-wiki-fr is already fully rebranded, do not touch it."
**Resolution:** Confirmed intentional — proceed with edits.

**Issue 2 — CSS scope:**
> "The CSS file is at media/css/seafile-ui.css — that's Django's static media directory, not the React frontend. The npm run build step compiles frontend/src/ into frontend/build/. The Dockerfile COPY you plan won't capture the CSS change."
**Resolution:** Already covered by existing `COPY tengis-wiki-fr/media/css/` line in Dockerfile.

**Issue 3 — Two repos, one commit:**
> "Steps 1–2 edit tengis-wiki-fr; step 3 says commit both. This needs to be two separate commits in two separate repos."
**Resolution:** Both files are in `tengis-wiki-fr` — one commit is correct.

**Issue 4 — Link text "Tengis Wiki":**
> "The original anchor text was 'Upgrade to Pro Edition' — a call-to-action. Replacing it with 'Tengis Wiki' gives you an anchor that reads [Tengis Wiki], which is a bit strange."
**Resolution:** Changed to "Learn More" instead.

---

### D.16 Commit Push Miss

**Context:** After CSS and info.js fix commit.

**What happened:** Claude Code committed `67d8376e4` locally but did not push to GitHub. VM pull showed the commit was missing.

**Resolution:** Manually ran `git push origin master` in Claude Code session.

**Lesson:** Always verify push happened after commit. Check with `git log --oneline -3` on both Mac and VM to confirm they match.

---

## APPENDIX E — New Session Handoff Note

Use this at the start of every new Claude session to provide context.

```
I am continuing the Tengis Wiki project. Here is the current state:

COMPLETED:
- Rebranding of tengis-wiki-fr and tengis-wiki-docker repos (all commits pushed)
- Custom Docker image built: tengis/tengis-wiki:13.0.21 running on VM 192.168.2.111
- Latest commit on tengis-wiki-fr: 67d8376e4 (CSS --bs-primary-rgb fix + info.js fix)
- Latest commit on tengis-wiki-docker: 7d40ed3 (.dockerignore added)

NEXT STEPS (frontend build):
1. Install Node.js 20 on VM (192.168.2.111, user: akin)
2. npm install in ~/tengiswiki/tengis-wiki-fr/frontend/
3. npm run build (~10-15 min) — output: frontend/build/
4. Update Dockerfile in tengis-wiki-docker — add this line after existing COPYs:
   COPY tengis-wiki-fr/frontend/build/ /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/frontend/build/
5. Update .dockerignore — replace "tengis-wiki-fr/frontend" with:
   tengis-wiki-fr/frontend/src
   tengis-wiki-fr/frontend/node_modules
   tengis-wiki-fr/frontend/scripts
   tengis-wiki-fr/frontend/public
6. Commit and push both files to tengis-wiki-docker
7. On VM: pull tengis-wiki-docker, rebuild image as tengis/tengis-wiki:13.0.21-r2
8. Redeploy: docker compose down && docker compose up -d
9. Fix Site Title: http://192.168.2.111/sys/settings/ → Site Title → Tengis Wiki
10. Verify all fixes in browser

REPOS:
- Mac: ~/tengiswiki/tengis-wiki-fr and ~/tengiswiki/tengis-wiki-docker
- VM: ~/tengiswiki/tengis-wiki-fr and ~/tengiswiki/tengis-wiki-docker
- Deploy: /opt/tengis/seafile-server.yml

VM SPECS: 16GB RAM, 4 vCPU, Ubuntu 24.04, IP: 192.168.2.111
```

---

## APPENDIX F — Test-Phase `seafile-server.yml` Snapshot (Pre-Custom-Image)

Preserved from the 25 May 2026 deployment session log. This appendix exists because:

1. The **active** `/opt/tengis/seafile-server.yml` is **not in any git repo** — it is edited in-place on the VM and backed up only via local `.bak` files. Without a documented snapshot, there is no record of how the compose file ever looked.
2. The volume-mount-based test phase was the working configuration **before** the custom image was built. If anything goes wrong with the custom image (`tengis/tengis-wiki:13.0.21-r2`), this snapshot is a known-good fallback shape that can be reconstructed from scratch.

> **⚠️ This is the OLD test-phase configuration.** The current active deployment is different:
> - Image: `tengis/tengis-wiki:13.0.21-r2` (NOT the retagged `tengis-wiki:13.0`)
> - Network: `tengis-net` (NOT `seafile-net`)
> - Volume mounts: **removed** (rebranding files are baked into the custom image)
>
> If you blindly copy this YAML over the active file, you will undo the custom image deployment. Only use this as a reference for the structure, or as a starting point if you ever need to bring up a fresh volume-mount test environment.

---

### F.1 Full Test-Phase `seafile-server.yml`

```yaml
services:
  tengis-db:
    image: ${SEAFILE_DB_IMAGE:-mariadb:10.11}
    container_name: tengis-db
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=${INIT_SEAFILE_MYSQL_ROOT_PASSWORD:-}
      - MYSQL_LOG_CONSOLE=true
      - MARIADB_AUTO_UPGRADE=1
    volumes:
      - "${SEAFILE_MYSQL_VOLUME:-/opt/seafile-mysql/db}:/var/lib/mysql"
    networks:
      - seafile-net
    healthcheck:
      test:
        [
          "CMD",
          "/usr/local/bin/healthcheck.sh",
          "--connect",
          "--mariadbupgrade",
          "--innodb_initialized",
        ]
      interval: 20s
      start_period: 30s
      timeout: 5s
      retries: 10

  tengis-redis:
    image: ${SEAFILE_REDIS_IMAGE:-redis}
    container_name: tengis-redis
    restart: unless-stopped
    command:
      - /bin/sh
      - -c
      - redis-server --requirepass "$$REDIS_PASSWORD"
    environment:
      - REDIS_PASSWORD=${REDIS_PASSWORD:-}
    networks:
      - seafile-net

  tengis-wiki:
    image: ${SEAFILE_IMAGE:-tengis-wiki:13.0}
    container_name: tengis-wiki
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ${SEAFILE_VOLUME:-/opt/seafile-data}:/shared
      - /home/akin/tengiswiki/tengis-wiki-fr/media/img/seafile-logo.png:/opt/seafile/seafile-server-13.0.21/seahub/media/img/seafile-logo.png
      - /home/akin/tengiswiki/tengis-wiki-fr/media/img/seafile-logo-dark.png:/opt/seafile/seafile-server-13.0.21/seahub/media/img/seafile-logo-dark.png
      - /home/akin/tengiswiki/tengis-wiki-fr/media/favicons/favicon.png:/opt/seafile/seafile-server-13.0.21/seahub/media/favicons/favicon.png
      - /home/akin/tengiswiki/tengis-wiki-fr/media/css/seafile-ui.css:/opt/seafile/seafile-server-13.0.21/seahub/media/css/seafile-ui.css
      - /home/akin/tengiswiki/tengis-wiki-fr/seahub/templates:/opt/seafile/seafile-server-13.0.21/seahub/seahub/templates
      - /home/akin/tengiswiki/tengis-wiki-fr/locale:/opt/seafile/seafile-server-13.0.21/seahub/locale
      - /home/akin/tengiswiki/tengis-wiki-fr/seahub/help/templates:/opt/seafile/seafile-server-13.0.21/seahub/seahub/help/templates
    environment:
      - SEAFILE_MYSQL_DB_HOST=${SEAFILE_MYSQL_DB_HOST:-tengis-db}
      - SEAFILE_MYSQL_DB_PORT=${SEAFILE_MYSQL_DB_PORT:-3306}
      - SEAFILE_MYSQL_DB_USER=${SEAFILE_MYSQL_DB_USER:-seafile}
      - SEAFILE_MYSQL_DB_PASSWORD=${SEAFILE_MYSQL_DB_PASSWORD:?Variable is not set or empty}
      - INIT_SEAFILE_MYSQL_ROOT_PASSWORD=${INIT_SEAFILE_MYSQL_ROOT_PASSWORD:-}
      - SEAFILE_MYSQL_DB_CCNET_DB_NAME=${SEAFILE_MYSQL_DB_CCNET_DB_NAME:-ccnet_db}
      - SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=${SEAFILE_MYSQL_DB_SEAFILE_DB_NAME:-seafile_db}
      - SEAFILE_MYSQL_DB_SEAHUB_DB_NAME=${SEAFILE_MYSQL_DB_SEAHUB_DB_NAME:-seahub_db}
      - TIME_ZONE=${TIME_ZONE:-Etc/UTC}
      - INIT_SEAFILE_ADMIN_EMAIL=${INIT_SEAFILE_ADMIN_EMAIL:-me@example.com}
      - INIT_SEAFILE_ADMIN_PASSWORD=${INIT_SEAFILE_ADMIN_PASSWORD:-asecret}
      - SEAFILE_SERVER_HOSTNAME=${SEAFILE_SERVER_HOSTNAME:?Variable is not set or empty}
      - SEAFILE_SERVER_PROTOCOL=${SEAFILE_SERVER_PROTOCOL:-http}
      - SITE_ROOT=${SITE_ROOT:-/}
      - NON_ROOT=${NON_ROOT:-false}
      - JWT_PRIVATE_KEY=${JWT_PRIVATE_KEY:?Variable is not set or empty}
      - SEAFILE_LOG_TO_STDOUT=${SEAFILE_LOG_TO_STDOUT:-false}
      - ENABLE_GO_FILESERVER=${ENABLE_GO_FILESERVER:-true}
      - ENABLE_SEADOC=${ENABLE_SEADOC:-true}
      - SEADOC_SERVER_URL=${SEAFILE_SERVER_PROTOCOL:-http}://${SEAFILE_SERVER_HOSTNAME:?Variable is not set or empty}/sdoc-server
      - CACHE_PROVIDER=${CACHE_PROVIDER:-redis}
      - REDIS_HOST=${REDIS_HOST:-tengis-redis}
      - REDIS_PORT=${REDIS_PORT:-6379}
      - REDIS_PASSWORD=${REDIS_PASSWORD:-}
      - MEMCACHED_HOST=${MEMCACHED_HOST:-memcached}
      - MEMCACHED_PORT=${MEMCACHED_PORT:-11211}
      - ENABLE_NOTIFICATION_SERVER=${ENABLE_NOTIFICATION_SERVER:-false}
      - INNER_NOTIFICATION_SERVER_URL=${INNER_NOTIFICATION_SERVER_URL:-http://notification-server:8083}
      - NOTIFICATION_SERVER_URL=${NOTIFICATION_SERVER_URL:-${SEAFILE_SERVER_PROTOCOL:-http}://${SEAFILE_SERVER_HOSTNAME:?Variable is not set or empty}/notification}
      - ENABLE_SEAFILE_AI=${ENABLE_SEAFILE_AI:-false}
      - ENABLE_FACE_RECOGNITION=${ENABLE_FACE_RECOGNITION:-false}
      - SEAFILE_AI_SERVER_URL=${SEAFILE_AI_SERVER_URL:-http://seafile-ai:8888}
      - SEAFILE_AI_SECRET_KEY=${JWT_PRIVATE_KEY:?Variable is not set or empty}
      - MD_FILE_COUNT_LIMIT=${MD_FILE_COUNT_LIMIT:-100000}
    labels:
      caddy: ${SEAFILE_SERVER_PROTOCOL:-http}://${SEAFILE_SERVER_HOSTNAME:?Variable is not set or empty}
      caddy.reverse_proxy: "{{upstreams 80}}"
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:80 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    depends_on:
      tengis-db:
        condition: service_healthy
      tengis-redis:
        condition: service_started
    networks:
      - seafile-net

networks:
  seafile-net:
    name: seafile-net
```

---

### F.2 Extended `.env` Reference (More Complete Than §6.12)

§6.12 trimmed the `.env` to only the variables that were actively used in the test deployment. The full version below preserves every variable that the test session populated, including the ones for features that were disabled (SeaDoc, notification server, Caddy, memcached, MD server) — useful as a reference if any of these get enabled later.

```env
COMPOSE_FILE='seafile-server.yml'
COMPOSE_PATH_SEPARATOR=','

SEAFILE_IMAGE=tengis-wiki:13.0
SEAFILE_DB_IMAGE=mariadb:10.11
SEAFILE_REDIS_IMAGE=redis
SEAFILE_CADDY_IMAGE=lucaslorentz/caddy-docker-proxy:2.12-alpine
SEADOC_IMAGE=seafileltd/sdoc-server:2.0-latest
NOTIFICATION_SERVER_IMAGE=seafileltd/notification-server:13.0-latest
MD_IMAGE=seafileltd/seafile-md-server:13.0-latest

BASIC_STORAGE_PATH=/opt
SEAFILE_VOLUME=$BASIC_STORAGE_PATH/seafile-data
SEAFILE_MYSQL_VOLUME=$BASIC_STORAGE_PATH/seafile-mysql/db
SEAFILE_CADDY_VOLUME=$BASIC_STORAGE_PATH/seafile-caddy
SEADOC_VOLUME=$BASIC_STORAGE_PATH/seadoc-data

SEAFILE_SERVER_HOSTNAME=192.168.2.111
SEAFILE_SERVER_PROTOCOL=http
TIME_ZONE=Europe/Istanbul
JWT_PRIVATE_KEY=b85c69cd52ae4cf8a9b943722875ebe2

SEAFILE_MYSQL_DB_HOST=tengis-db
SEAFILE_MYSQL_DB_USER=seafile
SEAFILE_MYSQL_DB_PASSWORD=Ankara123
SEAFILE_MYSQL_DB_CCNET_DB_NAME=ccnet_db
SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=seafile_db
SEAFILE_MYSQL_DB_SEAHUB_DB_NAME=seahub_db

CACHE_PROVIDER=redis
REDIS_HOST=tengis-redis
REDIS_PORT=6379
REDIS_PASSWORD=

MEMCACHED_HOST=memcached
MEMCACHED_PORT=11211

INIT_SEAFILE_MYSQL_ROOT_PASSWORD=Ankara123
INIT_SEAFILE_ADMIN_EMAIL=admin@tengis.local
INIT_SEAFILE_ADMIN_PASSWORD=Ankara123

ENABLE_SEADOC=false
ENABLE_NOTIFICATION_SERVER=false
ENABLE_SEAFILE_AI=false
ENABLE_FACE_RECOGNITION=false
MD_FILE_COUNT_LIMIT=100000
```

---

### F.3 Operational Techniques From the Test Session

Two small techniques captured from the test deployment that are useful any time the compose file or container layout is being modified.

#### F.3.1 Validate compose config before bringing the stack up

After any `sed` round on `seafile-server.yml`, validate the resulting YAML before `docker compose up -d`:

```bash
cd /opt/tengis
docker compose config
```

This expands all `${VAR}` substitutions from `.env`, resolves defaults, and parses the YAML. Any syntax error, missing required variable (e.g., `JWT_PRIVATE_KEY:?Variable is not set`), or malformed indent shows up here without starting any containers. Cheap insurance against bringing up a broken stack.

#### F.3.2 Discovering paths inside the running container

When a new file in `tengis-wiki-fr` needs to be mounted into the container, the destination path inside the container is not always obvious. Use `find` from `docker exec` to locate the file the customization should replace:

```bash
docker exec tengis-wiki find /opt/seafile -name "seafile-logo.png" 2>/dev/null
```

Example output:
```
/opt/seafile/seafile-server-13.0.21/seahub/frontend/src/assets/seafile-logo.png
/opt/seafile/seafile-server-13.0.21/seahub/media/img/seafile-logo.png
```

This both confirms the Seafile version installed in the container (`13.0.21` here) and reveals every location where a file with that name exists — important because Seahub serves `media/img/...` at runtime while `frontend/src/assets/...` is a build-time React source path that has no effect on the running server unless `npm run build` is re-run.

The same technique works for any other branding asset (`favicon.png`, `seafile-ui.css`, etc.) when planning either volume mounts or Dockerfile COPYs.

---

*End of Appendix F.*

---

## APPENDIX G — Color Token Investigation

**Investigation date:** 30 May 2026
**Status:** Root cause confirmed. Fix approach chosen: Option A (patch React source).
**Next action:** Execute the fix plan in §G.4.

---

### G.1 The Problem

After deploying `tengis/tengis-wiki:13.0.21-r2`, brand colors were partially applied:

| Element | Status |
|---|---|
| Login page background, Django-rendered templates | ✅ Tengis Blue `#4A4EC7` |
| Logos, favicons | ✅ Correct |
| Active tab underline indicator in file manager | ❌ Still orange `#ed7109` |
| Edit button focus ring | ❌ Still orange `rgba(255,128,0,.25)` |
| Various wiki, sdoc, shared-view UI elements | ❌ Still orange in 37 CSS files |

The `--bs-primary-rgb` fix in `seafile-ui.css` applied correctly to Django-rendered templates but had no effect on the React UI.

---

### G.2 Investigation Commands and Results

**Step 1 — Confirm `seafile-ui.css` has the correct value:**

```bash
docker exec tengis-wiki grep "bs-primary-rgb" \
  /opt/seafile/seafile-server-13.0.21/seahub/media/css/seafile-ui.css
```

Result: `--bs-primary-rgb:74,78,199` confirmed present. Our fix landed correctly.

**Step 2 — Check if base image ships `media/assets/` pre-built:**

```bash
docker run --rm seafileltd/seafile-mc:13.0-latest \
  ls /opt/seafile/seafile-server-13.0.21/seahub/media/assets/ 2>/dev/null | head -5
```

Result: No output. **Base image ships without `media/assets/`.** Our `collectstatic` genuinely built it — this is not a "snapshot of pre-existing state" issue.

**Step 3 — Check if orange value exists in compiled React bundles:**

```bash
docker exec tengis-wiki grep -rl "255,128,0" \
  /opt/seafile/seafile-server-13.0.21/seahub/media/assets/
```

Result: **37 CSS files** in `media/assets/frontend/static/css/` contain `255,128,0`.

**Step 4 — Inspect the actual context of the match:**

```bash
docker exec tengis-wiki grep -o ".\{30\}255,128,0.\{30\}" \
  /opt/seafile/seafile-server-13.0.21/seahub/media/assets/frontend/static/css/commons.e80a7295.css | head -3
```

Result:
```
box-shadow:0 0 0 2px rgba(255,128,0,.25)}.doc-ops #op-edit
```

And from the full file content, also confirmed:
```css
.nav-indicator-container:before { background: #ed7109; }
```

---

### G.3 Root Cause

The React source code has two types of color references:

**Type 1 — CSS variable references (correctly overridden by `seafile-ui.css`):**
```css
color: var(--bs-primary);
background: var(--bs-primary-rgb);
```
These respond to the `:root` variable definitions in `seafile-ui.css`. Our fix works for these.

**Type 2 — Hardcoded hex/rgb literals (NOT overridden by `seafile-ui.css`):**
```css
background: #ed7109;
box-shadow: 0 0 0 2px rgba(255,128,0,.25);
```
These were written directly into the React component stylesheets as literal values. Webpack compiles them verbatim into the CSS bundles in `media/assets/`. The `:root` CSS variable override in `seafile-ui.css` has zero effect on literal values — CSS variable scoping does not work in reverse.

**Why `seafile-ui.css` worked for some elements but not others:** Django-rendered templates (login page, header) load `seafile-ui.css` which sets the `:root` variables. React components that reference `var(--bs-primary)` pick up those variables at runtime. But React components that have hardcoded `#ed7109` or `rgba(255,128,0,...)` ignore the variable entirely.

---

### G.4 Fix Plan — Option A (Patch React Source)

The fix must happen in the React source, before `npm run build`. The compiled output is what gets copied into `media/assets/` by `collectstatic`.

#### G.4.1 Find all hardcoded orange occurrences in the source

On the VM, in the `tengis-wiki-fr` repo:

```bash
cd ~/tengiswiki/tengis-wiki-fr/frontend/src

grep -rl "#ed7109" . | sort
grep -rl "255,128,0" . | sort
grep -rl "rgba(255, 128, 0" . | sort
```

Record every file returned. These are the files that need editing.

#### G.4.2 Replace the values

For each file found, replace:

| Find | Replace with | Usage |
|---|---|---|
| `#ed7109` | `#4A4EC7` | Solid color elements (tab indicator, highlights) |
| `rgba(255,128,0,` | `rgba(74,78,199,` | Transparent/alpha variants (focus rings, shadows) |
| `rgba(255, 128, 0,` | `rgba(74, 78, 199,` | Same with spaces |

Use `sed` for efficiency:

```bash
cd ~/tengiswiki/tengis-wiki-fr/frontend/src

grep -rl "#ed7109" . | xargs sed -i 's/#ed7109/#4A4EC7/g'
grep -rl "255,128,0" . | xargs sed -i 's/255,128,0/74,78,199/g'
```

Verify the replacements:

```bash
grep -r "#ed7109" . | wc -l
grep -r "255,128,0" . | wc -l
```

Both should return 0.

#### G.4.3 Rebuild

Follow the standard Option J rebuild process — build plan v1.6 Phases 1–7:

```bash
cd ~/tengiswiki/tengis-wiki-fr/frontend
NODE_OPTIONS=--max-old-space-size=4096 npm run build
```

Then collectstatic (Phase 2–3), Dockerfile update if needed (Phase 4), docker build (Phase 5), redeploy (Phase 6).

Tag the new image as `tengis/tengis-wiki:13.0.21-r3`.

#### G.4.4 Verify the fix

After redeployment, confirm the orange is gone from the compiled bundles:

```bash
docker exec tengis-wiki grep -rl "255,128,0" \
  /opt/seafile/seafile-server-13.0.21/seahub/media/assets/
```

Expected: no output (zero files).

Then browser-check the two known orange elements:
- Active tab underline in the file manager navigation
- Edit button focus ring in document viewer

#### G.4.5 Commit

```bash
cd ~/tengiswiki/tengis-wiki-fr
git add frontend/src/
git commit -m "rebrand: replace hardcoded orange color literals with Tengis Blue

Replace #ed7109 → #4A4EC7 and rgba(255,128,0,...) → rgba(74,78,199,...)
in React source stylesheets. These values were not overridden by the
--bs-primary-rgb variable in seafile-ui.css because they are hardcoded
literals, not CSS variable references.

Requires npm run build + collectstatic + image rebuild (13.0.21-r3)."
git push origin master
```

---

### G.5 Known Scope

The 37 files containing `255,128,0` in `media/assets/` are all compiled output — editing them directly is pointless as they get overwritten on every `collectstatic` run. Only the React source files in `frontend/src/` matter.

The `#ed7109` value also appears in the compiled bundle as:
- Active nav tab underline: `.nav-indicator-container:before { background: #ed7109 }`
- Possibly other accent elements — the full list will be revealed by G.4.1's grep

After this fix, the only remaining color-related task is verifying that no other Seafile orange hex values (`#ff8000`, `#f60`, `#ff6600`) exist in the source. Add those to the grep in G.4.1:

```bash
grep -rl "#ff8000\|#f60\b\|#ff6600\|#ed7109\|255,128,0" . | sort
```

---

*End of Appendix G.*
