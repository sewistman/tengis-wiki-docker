# Tengis Wiki

Tengis Wiki is a rebranded deployment of [Seafile Community Edition](https://github.com/haiwen/seafile). All user-visible "Seafile" and "Community Edition" strings, logos, favicons, colors, and locale translations have been replaced with Tengis Wiki branding. All internal identifiers — function names, environment variable names, Docker volume paths, the Apache 2.0 license attribution — are preserved untouched, since renaming them would either break the application or violate the upstream license.

The deployment runs as a custom Docker image (`tengis/tengis-wiki:13.0.21-r2`) built by overlaying rebranded files on top of the official `seafileltd/seafile-mc:13.0-latest` base image. The React frontend and Django `collectstatic` output are pre-built on the VM and copied into the image at build time (Option J — see the build plan for details).

---

## At a glance

| Item | Value |
|---|---|
| Base | Seafile CE 13.0 — `seafileltd/seafile-mc:13.0-latest` |
| Product image | `tengis/tengis-wiki:13.0.21-r2` (2.76 GB uncompressed / 644 MB compressed) |
| Active deployment | VM `192.168.2.111`, deployed from `/opt/tengis/` |
| VM | Ubuntu 24.04, 32 GB RAM, 4 vCPU, 97 GB disk |
| Network | `tengis-net` |
| Containers | `tengis-wiki`, `tengis-redis`, `tengis-db` |
| Admin URL | http://192.168.2.111 |
| Brand color | Tengis Blue `#4A4EC7` on `#0D0D0D` text, hover `#3a3ea0` |
| Supported locales | `en`, `en_US`, `tr` (Turkish), `id` (Indonesian) |
| External URL rebrand | All `seafile.com` / `seafileltd.com` references → `redirish.global` |
| Compose file | `/opt/tengis/seafile-server.yml` — **not in any git repo**, backed up manually via `.bak` |

---

## Repositories

| Repo | URL | Visibility | Latest commit |
|---|---|---|---|
| `tengis-wiki-fr` (Seahub fork) | `github.com/sewistman/tengis-wiki-fr` | Private | `4399bc278` |
| `tengis-wiki-docker` (Docker fork) | `github.com/sewistman/tengis-wiki-docker` | Private | `27b3a9a` |

Both are cloned at `~/tengiswiki/` on Mac and VM. Rebranding rules are enforced by Claude Code via the `CLAUDE.md` file committed at the root of each repo.

> Note: `tengis-wiki-fr` was initially Public during the 25 May 2026 test deployment and was changed to Private afterwards. Current state for both repos is Private.

---

## The four canonical documents

| Document | Lines | Purpose |
|---|---|---|
| [`docs/tengis-wiki-project-guide-v1_5.md`](docs/tengis-wiki-project-guide-v1_5.md) | 2246 | **The big one.** End-to-end record of what was built and why. Setup procedures, rebranding rules, every change tracked across both repos, deployment history, Claude Code analysis log, troubleshooting decisions. Six appendices covering: SeaDoc/Wiki integration (enablement, reverse-proxy routing, operational reference, known issues), pending work tracker, corrections and missing items (with version history table), Claude Code analysis log, session handoff template, test-phase compose snapshot. |
| [`docs/tengis-wiki-build-plan-v1_6.md`](docs/tengis-wiki-build-plan-v1_6.md) | 1239 | **The runbook.** Step-by-step plan for rebuilding the Docker image via Option J — collectstatic on the VM, COPY pre-built artifacts into the image. Includes the build environment contract, all 16 findings about why the build works the way it does, full Phases 0–8 with troubleshooting tables, env-var and file-path references, complete Option D fallback recipe (multi-stage Dockerfile + build-failure decision table + rollback procedure), and future Seafile upgrade process. |
| [`docs/tengis-wiki-frontend-build-v1_2.md`](docs/tengis-wiki-frontend-build-v1_2.md) | 1003 | **The collectstatic investigation.** Documents the four-layer failure of trying to run `collectstatic` inside the running container, and — most importantly — Appendix A documents Seafile's official customization mechanism (`seahub-data/custom/` + `seahub_settings.py` overrides for `LOGO_PATH`, `FAVICON_PATH`, `BRANDING_CSS`, `SITE_TITLE`, template overrides, custom navigation). |

Read order for someone new to the project: **project guide → build plan → frontend build (only if needed)**.

---

## Where to look — by task

This is the section to bookmark. Each row maps a concrete thing you might be doing to the document and section that answers it.

### Day-to-day operations

| What you are doing | Document | Section |
|---|---|---|
| Bringing the stack up after a stop | `project-guide-v1_5.md` | §5.10 |
| Bringing the stack down for maintenance | `project-guide-v1_5.md` | §5.11 (rebuild process) — covers `docker compose down/up` |
| Restoring `seafile-server.yml` after a bad edit | `project-guide-v1_5.md` | §C.5 — `cp seafile-server.yml.bak seafile-server.yml` |
| Reconstructing `seafile-server.yml` if both files are lost | `project-guide-v1_5.md` | Appendix F.1 (test-phase snapshot — adapt: image → `tengis/tengis-wiki:13.0.21-r2`, network → `tengis-net`, remove the 7 volume-mount lines) |
| Restoring `.env` after corruption | `project-guide-v1_5.md` | §6.12 (in-use version) or Appendix F.2 (extended reference) |
| Checking what the compose config will actually be | `project-guide-v1_5.md` | Appendix F.3.1 — `docker compose config` |
| Finding where a file lives inside the container | `project-guide-v1_5.md` | Appendix F.3.2 — `docker exec ... find` recipe |
| Resetting admin password | Seafile upstream docs — not project-specific | — |

### Making a rebranding change

| What you are doing | Document | Section |
|---|---|---|
| Understanding what is OK to change vs not | `project-guide-v1_5.md` | §2.2 (touch vs never-touch) + §3.6 (full `CLAUDE.md` rules) |
| Changing a brand color | `project-guide-v1_5.md` | §3.4 (CSS variables table) — then rebuild via build plan |
| Replacing a logo or favicon | `project-guide-v1_5.md` | §3.5 (dimensions table) + §C.4 (Python Pillow resize script) |
| Editing a help page or download page | `project-guide-v1_5.md` | §3.3 (directory map shows which files) |
| Editing UI strings | `project-guide-v1_5.md` | §3.6 `CLAUDE.md` (rules: `gettext()` / `{% trans %}` only) |
| Translating into Turkish or Indonesian | `project-guide-v1_5.md` | §3.7 — **rule: `msgstr` lines only, never `msgid`** |
| Adding or removing a supported locale | `project-guide-v1_5.md` | §3.6 `CLAUDE.md` — currently `en`, `en_US`, `tr`, `id` only |
| Changing the React `info.js` system info text | `project-guide-v1_5.md` | §5.13 Fix 3 — then full rebuild required (Option J) |

### Rebuilding the Docker image

| What you are doing | Document | Section |
|---|---|---|
| Standard image rebuild after a change to `tengis-wiki-fr` | `build-plan-v1_6.md` | Start at "Pre-session checklist", then Phases 0 → 7 |
| Just the React build + collectstatic on the VM | `build-plan-v1_6.md` | Phase 1 (React) + Phases 2–3 (collectstatic) |
| Writing/updating the Dockerfile | `build-plan-v1_6.md` | Phase 4 |
| Writing the root-level `.dockerignore` | `build-plan-v1_6.md` | Phase 4 Task 4.2 — **must be at `~/tengiswiki/`, not next to the Dockerfile** |
| Setting up a fresh VM for builds | `build-plan-v1_6.md` | Phase 1 Task 1.0 (Node.js + `build-essential` + `python3`) + `project-guide-v1_5.md` §5.0.5 (LVM disk extension) |
| Understanding why a build step exists | `build-plan-v1_6.md` | §4 (Findings 1–16) |
| Debugging a build failure | `build-plan-v1_6.md` | Phase 2.7 troubleshooting table |
| Force-push and sync issues after a build | `build-plan-v1_6.md` | Phase 7 (8 tasks — includes `git fetch && git reset --hard` for the VM, build-artifact cleanup, etc.) |
| Pushing the image to Docker Hub | `build-plan-v1_6.md` | §2 (compressed size 644 MB to estimate push bandwidth) |
| Upgrading to a new upstream Seafile version (13.1, 14.0, etc.) | `build-plan-v1_6.md` | §14 — six-step recipe: re-verify findings, bump base image tag, run pipeline, tag and release, retention, upstream rebase |
| Trying the multi-stage Dockerfile fallback (Option D) | `build-plan-v1_6.md` | §9 — five subsections covering when to use, v1.4 corrections, Dockerfile sketch, build-failure decision table, rollback procedure |

### Future / per-customer customization

| What you are doing | Document | Section |
|---|---|---|
| Adding per-customer branding without rebuilding the image | `frontend-build-v1_2.md` | Appendix A (full official customization mechanism reference) |
| Changing `SITE_TITLE` shown in the browser tab | `project-guide-v1_5.md` | §5.13 Fix 2 (admin panel) — no rebuild needed |
| Enabling the Wiki feature / SeaDoc | `project-guide-v1_5.md` | Appendix A.1–A.4 (overview + enablement procedure) |
| Putting SeaDoc behind a reverse proxy (nginx, Caddy, etc.) | `project-guide-v1_5.md` | Appendix A.5 — the `/sdoc-server/` + `/socket.io/` routing pattern, trailing-slash mechanic, WebSocket headers |
| Operating SeaDoc (logs, reachability tests, JWT auth) | `project-guide-v1_5.md` | Appendix A.6 — seven log files explained, three verification commands, JWT failure modes |
| Hitting a SeaDoc issue (markdown import "Failed", wiki publish 400, intermittent JWT unauthorized) | `project-guide-v1_5.md` | Appendix A.7 — known issues with workarounds and root causes |
| Adding custom navigation links | `frontend-build-v1_2.md` | Appendix A.4 (`CUSTOM_NAV_ITEMS` in `seahub_settings.py`) |
| Adding a custom login background or help URL | `frontend-build-v1_2.md` | Appendix A.1 (`LOGIN_BG_IMAGE_PATH`, `HELP_LINK`) |

### Understanding decisions and history

| What you are looking for | Document | Section |
|---|---|---|
| Why Option A (docker exec collectstatic) is permanently closed | `build-plan-v1_6.md` | §3 (four-layer failure) |
| Why Option J was chosen over Option D | `build-plan-v1_6.md` | §6 (four-bullet practical rationale) + Finding 6 (upstream does the same) |
| Why the build stub `seahub_settings.py` is only 6 lines | `build-plan-v1_6.md` | §7 + Findings 1, 2, 4, 5, 10 |
| Why `LICENSE.txt` still says "Seafile Ltd." | `project-guide-v1_5.md` | §4.7 (Apache 2.0 attribution is legally required) |
| Why `X-Seafile-Signature` and `seahub-db` were not renamed | `project-guide-v1_5.md` | §3.7, Appendix D.2, D.3 |
| Why CSS class names containing "seafile" were left alone | `project-guide-v1_5.md` | §3.6 `CLAUDE.md` rules + Appendix D.4 |
| What was tried and rejected | `build-plan-v1_6.md` | §12 Decision Record (includes "Patch lazy import" and "BUILD_MODE flag" as rejected) |

---

## In case of emergency

| Problem | First action |
|---|---|
| Stack won't start after a compose edit | `cp /opt/tengis/seafile-server.yml.bak /opt/tengis/seafile-server.yml && cd /opt/tengis && docker compose down && docker compose up -d` |
| `seafile-server.yml` corrupted and no `.bak` exists | Reconstruct from `project-guide-v1_5.md` Appendix F.1; update three things: image → `tengis/tengis-wiki:13.0.21-r2`, network → `tengis-net` (rename both the `networks:` section at bottom and the per-service `networks:` entries), remove the 7 volume-mount lines for branding files |
| Container won't come up — error about webpack-stats or static files | `build-plan-v1_6.md` Phase 5.2 + Phase 2.7 troubleshooting — likely a stale build artifact |
| VM crashed, need to rebuild from scratch | Both repos are on GitHub. Recreate VM per `project-guide-v1_5.md` §6.1–§6.5, then run `build-plan-v1_6.md` Phase 0 onward |
| Lost track of which image is running | `docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'` — active image should be `tengis/tengis-wiki:13.0.21-r2` |
| Lost track of which Dockerfile is on disk vs in git | `cd ~/tengiswiki/tengis-wiki-docker && git status && git log --oneline -3` — clean tree should show `27b3a9a` as latest |

**Compose file is not in git.** This is the single most important operational fact in this project. Every edit to `/opt/tengis/seafile-server.yml` must be preceded by `cp seafile-server.yml seafile-server.yml.bak`. If a rebuild ever fails halfway and the file is lost, Appendix F.1 of the project guide is the only off-disk record of what it should look like.

---

## License and attribution

Tengis Wiki is built on Seafile Community Edition, which is licensed under Apache 2.0. The original copyright line `Copyright (c) 2016 Seafile Ltd.` in `tengis-wiki-docker/LICENSE.txt` is **legally required upstream attribution** under Apache 2.0 and is preserved unmodified. Any Tengis copyright additions go as a second line, never as a replacement:

```
Copyright (c) 2016 Seafile Ltd.
Copyright (c) 2026 Tengis
```

See `project-guide-v1_5.md` §4.7 for the full license-compliance reasoning, and Appendix D.10 for the original Claude Code warning that flagged the issue during the rebranding session.

---

*Last updated to reflect: `tengis-wiki-fr@4399bc278`, `tengis-wiki-docker@27b3a9a`, image `tengis/tengis-wiki:13.0.21-r2` deployed on `192.168.2.111`. Documentation set consists of three canonical documents: project guide v1.5 (added Appendix A.5–A.7 SeaDoc operational reference from production nexus2 deployment 29 May 2026), build plan v1.6 (absorbed the original v1.0 planning document — multi-stage Dockerfile, build-failure decision table, rollback procedure, and future upgrade process all now in v1.6 §9 and §14), and frontend build v1.2 (unchanged).*
