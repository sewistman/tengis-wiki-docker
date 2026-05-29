# Tengis Wiki — Frontend Build & Image Rebuild Session
**Version 1.2 — May 2026**
**Continues from:** `tengis-wiki-project-guide-v1.3.md` and `tengis-wiki-frontend-build-v1.0.md`
**Session focus:** Investigation of frontend build + collectstatic approaches, discovery of the official Seafile customization mechanism, full documentation of unknowns

---

## VERSION HISTORY

| Version | Date | Changes |
|---|---|---|
| v1.0 | May 2026 | Initial — frontend build session, VM resource upgrade, npm install completed |
| v1.1 | May 2026 | Investigated collectstatic options via dry-run (each layer failed); documented official Seafile customization mechanism; mapped three strategic + three tactical options for tomorrow |
| v1.2 | May 2026 | Elevated double-hashing finding from §2.6 by-product to highlighted callout; added notes on `docker compose exec` equivalence, `--env-file` process-sub attempt, and seahub_settings.py being runtime-generated; added Appendix F (web research sources), Appendix G (what definitely works), Appendix H (Mac repo cleanup), Appendix I (token/context budget notes) |

---

## SECTION 0 — Note to Future Claude / Future-Me

This document is a handoff to the next session. Read this first.

**You are continuing the Tengis Wiki rebranding project.** The user has rebranded Seafile (a self-hosted file-sync/wiki platform) into a custom-branded product called "Tengis Wiki." Two repos exist on their Mac and on a VMware VM:

- `~/tengiswiki/tengis-wiki-fr` — Seahub (Django+React web UI) fork
- `~/tengiswiki/tengis-wiki-docker` — Docker compose / image build fork

A custom Docker image `tengis/tengis-wiki:13.0.21` was already built and is **running on the VM (192.168.2.111)**. CSS, logos, favicons, help templates, and most user-facing strings are rebranded and visible in the browser.

**What's NOT yet visible in the browser:**
1. The `info.js` change from `'Community Edition'` → `'Tengis Wiki'` (System Info admin page) — requires React build
2. The locale `.mo` files (Turkish/Indonesian translations) — already on disk, not yet committed to repo, but already baked into image
3. The Site Title in browser tab — requires admin panel change (separate task)

**This session was supposed to do the React build.** It didn't. Instead we discovered:
- The collectstatic step that's required after the React build is much harder than expected on this codebase
- There's an official customization mechanism in Seafile that the project never used and that could fundamentally simplify everything going forward

**Read Sections 1-5 to understand state, then Sections 6-7 for the decisions waiting for tomorrow.**

---

## SECTION 1 — Current State (End of v1.1 Session)

### 1.1 VM State

| Item | Value |
|---|---|
| IP | 192.168.2.111 |
| User | akin |
| OS | Ubuntu 24.04 Server |
| RAM | 32 GB |
| vCPUs | 4 |
| Disk | 97 GB total, 80 GB free |
| Deploy path | `/opt/tengis/` |
| Repos path | `~/tengiswiki/` |

### 1.2 Toolchain on VM

| Tool | Version | Notes |
|---|---|---|
| Node.js | v20.20.2 | Installed via NodeSource setup_20.x |
| npm | 10.8.2 | Bundled with Node 20 |
| gcc | 13.3.0 | For native npm builds |
| python3 | 3.12 | System Python |
| msgfmt (gettext) | installed | Used for .mo locale compilation |
| Docker | 29.5.2 | docker-compose v5.1.4 |

### 1.3 Repo State

| Repo | Mac | VM | Origin |
|---|---|---|---|
| `tengis-wiki-fr` | `67d8376e4` ✅ clean | `67d8376e4` ✅ + 7 untracked `.mo` files | in sync |
| `tengis-wiki-docker` | `7d40ed3` + 2 **uncommitted** drafts | `18ce4eb` (1 behind, fast-forward available) | Mac is ahead |

The two uncommitted Mac drafts are:
- `Dockerfile` — adds two COPY lines for `frontend/build/` and `webpack-stats.pro.json`
- `.dockerignore` — adds `!tengis-wiki-fr/frontend/build` and `!tengis-wiki-fr/frontend/webpack-stats.pro.json`

**⚠️ THESE DRAFTS ARE INCORRECT.** They assume `frontend/build/` is the only thing needed. They do NOT include collectstatic output (`media/assets/`) which is what Django actually serves. **Do not commit them as-is.** They'll need to be rewritten based on whatever path we choose tomorrow.

### 1.4 Deployment State

| Item | State |
|---|---|
| Image | `tengis/tengis-wiki:13.0.21` (2.39GB, ID `8df46899cbdc`) |
| Containers | `tengis-wiki`, `tengis-redis`, `tengis-db` — all healthy |
| Network | `tengis-net` |
| Deploy file | `/opt/tengis/seafile-server.yml` (NOT in git) |
| Backup | `/opt/tengis/seafile-server.yml.bak` exists |
| Compose env | `/opt/tengis/.env` (see v1.3 §6.12 for full content) |

### 1.5 Frontend Build State

| Item | State |
|---|---|
| `~/tengiswiki/tengis-wiki-fr/frontend/node_modules` | 1011 MB, install complete ✅ |
| `npm run build` | NOT yet run |
| `frontend/build/` | Does NOT exist on disk (would be created by build) |
| Build script | `node scripts/build.js` (custom, per `package.json`) |
| Expected output path | `frontend/build/frontend/` (per `paths.js` line 29: `BUILD_PATH = 'build/frontend'`) — **unverified, only confirmable by running build** |

### 1.6 Mystery Files Cleanup (this session)

The VM repo had four empty 0-byte files at root from a shell typo: `4355`, `72937`, `8049`, `FETCH_HEAD`. All confirmed empty, deleted with `rm`. The real `.git/FETCH_HEAD` at 105 bytes is intact.

---

## SECTION 2 — What This Session Investigated

The session goal was to validate the frontend build approach before committing to a Dockerfile rewrite. Specifically: prove that `collectstatic` (the Django step required to make React build output servable) could be executed cleanly somewhere reachable.

This led to four cumulative experiments inside the running container, each fixing one layer of failure and revealing the next.

### 2.1 The Critical Architecture Finding (Did Not Change)

The running container serves React assets from `media/assets/` (159 MB), NOT from `frontend/build/`. The base image's upstream build process did the following at image build time:
1. `npm install && npm run build` → produced `frontend/build/frontend/...`
2. Django's `STATICFILES_DIRS` reads from `frontend/build/`
3. `python manage.py collectstatic` copied files to `media/assets/` with hash-mangled names
4. `frontend/build/` was deleted from the final image (only `webpack-stats.pro.json` was kept)
5. Final image ships with `media/assets/` baked in; nginx serves from there

**For our rebrand to appear, we need:** new `media/assets/` content reflecting the new React source. This requires running `collectstatic` after `npm run build`.

### 2.2 Layer 1 — PYTHONPATH Discovery

**Attempt:**
```bash
docker exec tengis-wiki bash -c "cd /opt/seafile/seafile-server-13.0.21/seahub && python3 manage.py collectstatic --dry-run --noinput"
```

**Failure:** `ModuleNotFoundError: No module named 'seaserv'` at `settings.py` line 10.

**Reason:** `docker exec bash -c` starts a fresh shell with no inherited PYTHONPATH. The seaserv module is a Python wrapper for the libseafile C library, installed at a non-standard path.

**Fix discovered:** The seahub.sh startup script exports:
```
PYTHONPATH=$INSTALLPATH/seafile/lib/python3/site-packages:$INSTALLPATH/seafile/lib64/python3/site-packages:$INSTALLPATH/seahub:$INSTALLPATH/seahub/thirdpart:$PYTHONPATH
```

Where `INSTALLPATH=/opt/seafile/seafile-server-13.0.21`.

### 2.3 Layer 2 — Seaserv Config Path Variables

**Attempt:** Re-ran with PYTHONPATH set.

**Failure:** `ImportError: Seaserv cannot be imported, because environment variable SEAFILE_CONF_DIR is undefined.`

**Reason:** `seaserv/service.py` requires either `SEAFILE_DATA_DIR` OR `SEAFILE_CONF_DIR` (the latter is legacy fallback) at import time. Also `SEAFILE_CENTRAL_CONF_DIR` is unconditionally required.

**Source from seaserv/service.py (read during this session):**
```python
def _load_data_dir():
    data_dir = _load_path_from_env('SEAFILE_DATA_DIR', check=False)
    if data_dir:
        return data_dir
    return _load_path_from_env('SEAFILE_CONF_DIR')

SEAFILE_DATA_DIR = _load_data_dir()
SEAFILE_CENTRAL_CONF_DIR = _load_path_from_env('SEAFILE_CENTRAL_CONF_DIR', check=True)
SEAFILE_RPC_PIPE_PATH = _load_path_from_env("SEAFILE_RPC_PIPE_PATH", check=False)
```

### 2.4 Layer 3 — seahub_settings.py Location

**Discovery:** The seahub_settings.py file lives at `/opt/seafile/conf/seahub_settings.py` — NOT inside the seahub source tree. It's created by the entrypoint at first container run.

**Implication:** PYTHONPATH must also include `/opt/seafile/conf` so Django's `from seahub_settings import *` can resolve.

### 2.5 Layer 4 — seafevents_api (The Wall)

**Attempt:** Re-ran with all the above env set:

```bash
docker exec \
  -e SEAFILE_CENTRAL_CONF_DIR=/opt/seafile/conf \
  -e SEAFILE_DATA_DIR=/opt/seafile/seafile-data \
  -e SEAFILE_RPC_PIPE_PATH=/opt/seafile/seafile-server-13.0.21/runtime \
  -e PYTHONPATH=...full path including /opt/seafile/conf... \
  -e JWT_PRIVATE_KEY=... \
  -e SEAFILE_MYSQL_DB_HOST=tengis-db \
  ... (13 env vars total) \
  tengis-wiki \
  bash -c "cd /opt/seafile/seafile-server-13.0.21/seahub && python3 manage.py collectstatic --dry-run --noinput"
```

**Failure:**
```
File "/opt/seafile/seafile-server-13.0.21/seahub/seahub/utils/__init__.py", line 577, in <module>
    SeafEventsSession = seafevents_api.init_db_session_class()
AttributeError: 'NoneType' object has no attribute 'init_db_session_class'
```

**Reason:** Seahub's `utils/__init__.py` imports `seafevents_api` (the Pro-edition event subsystem), which initializes to `None` when seafevents config isn't fully wired. The next layer would require getting seafevents to load — which needs more config from `seafevents.conf` plus possibly working DB connections.

**Decision made:** Stop chasing layers. Each fix uncovered the next. Continuing would consume an evening with no guarantee of success.

### 2.6 The Valuable By-Products of the Failed Investigation

Even though we never got collectstatic to run, we learned:

1. **`media/assets/` is fully derivable from `STATICFILES_DIRS`.** Inspection showed only `frontend/`, `scripts/`, and `staticfiles.json` — all reproducible via collectstatic. So `--clear` is safe in principle.

2. **🌟 Django wraps webpack hashes with its own ManifestStaticFilesStorage hashes.** The `staticfiles.json` showed double-hashed paths like:
   ```
   "frontend/static/js/2405.f6d72ea3.chunk.js": "frontend/static/js/2405.f6d72ea3.chunk.d524003f1d7d.js"
   ```
   The first hash (`f6d72ea3`) is webpack's. The second (`d524003f1d7d`) is Django's post-processing hash. **This eliminates one of the biggest feared failure modes for Option D** — webpack hashes don't need to "match" Django's hashing scheme because Django wraps them either way.

3. **The 13 env vars needed for collectstatic are now documented** (Appendix B). If we go for collectstatic-during-Dockerfile-build, we know exactly what to pass.

4. **`/opt/seafile/seafile-server.yml` is NOT in any git repo.** Already known from v1.3 but reconfirmed — manual backup before tag changes is required.

5. **`docker compose exec` behaves the same as `docker exec`.** Tried both during this session — neither inherits PID 1's runtime environment. Don't waste cycles retrying `docker compose exec` thinking it might be different.

6. **The `--env-file <(...)` bash process-substitution trick** (passing the container's PID 1 env back as `--env-file`) was attempted and produced the same seaserv import failure. Either the process substitution didn't pipe cleanly into docker, or PID 1 (the supervisor `my_init`) doesn't have the gunicorn-worker env we needed. Not worth retrying without proving PID 1 has the right env.

7. **`seahub_settings.py` lives at `/opt/seafile/conf/seahub_settings.py`** — runtime-generated by the entrypoint, NOT shipped with the base image. This means Option D would need to either generate or stub a minimal one during build.

---

## SECTION 3 — Three Strategic Options (Architecture Level)

These are the high-level choices about HOW the rebranded product should be structured. Not just "what do we do tonight" but "what's the right shape going forward."

### 3.1 Strategy 1 — Pure Official Customization (Most Maintainable)

**Concept:** Use Seafile's built-in customization mechanism (the `seahub-data/custom/` directory + `seahub_settings.py` overrides). The Docker image stays vanilla `seafileltd/seafile-mc:13.0-latest`. Bind-mount a `custom/` directory that holds logos, favicons, CSS, and template overrides.

**Pros:**
- Survives upstream upgrades automatically (no rebuild)
- Per-customer customization via the bind mount
- Documented official path — no surprises
- Cleanest for selling to multiple customers with different branding

**Cons:**
- Cannot handle the `info.js` React-bundled string (still needs React rebuild)
- Cannot handle locale `.po` translation overrides (still needs file replacement in image)
- Cannot handle Docker container/network names (still needs docker-compose edits)
- Throws away the work invested in the current heavy custom image

**See Appendix A for full reference.**

### 3.2 Strategy 2 — Continue Current Heavy Custom Image Approach (90% Done)

**Concept:** Keep going with what's built. The custom image overlays everything (logos, CSS, templates, locales). Add the React frontend build + collectstatic to it. Result: one image that contains everything Tengis-branded.

**Pros:**
- Most work already done — only frontend build remains
- One artifact (`tengis/tengis-wiki:13.0.21-r2`) that's fully Tengis-branded
- No bind mounts needed at deploy time

**Cons:**
- Per-upgrade cost is high (must rebuild image, must merge upstream changes, must repeat collectstatic)
- Customizing per-customer means a new image variant per customer
- The collectstatic-during-build step is unproven (this session's findings)

### 3.3 Strategy 3 — Hybrid (Recommended Long-Term)

**Concept:** Keep the heavy custom image as the "Tengis base" (containing the React rebuild + locale fixes + identity changes that CAN'T be done via custom/). On top of that, support per-customer overrides via the `custom/` bind mount for logos, colors, etc.

**Pros:**
- Best of both worlds — Tengis identity baked in, customer touches in bind mount
- Per-customer deployment requires no image rebuild
- Future-proof against Strategy 1 migration

**Cons:**
- Two layers of customization to document and reason about
- Slightly more deployment complexity

---

## SECTION 4 — Three Tactical Options (To Get `info.js` Visible)

These are the immediate "what do we do tomorrow" options.

### 4.1 Option A — docker exec collectstatic (FAILED THIS SESSION)

**Concept:** Run `npm run build` on VM, `docker cp` the result INTO the running container, `docker exec` collectstatic to regenerate `media/assets/`, `docker cp` it back OUT, COPY into new image build.

**Status:** ❌ **Investigated and abandoned.** Fails at the seafevents_api layer. Documented in §2 for future reference.

**Why it failed:** Running collectstatic in a *running container* triggers seafevents subsystem initialization that we don't have control over. Not recoverable without significant Seahub code-level intervention.

### 4.2 Option C — Surgical docker cp Hot-Swap (Untested, Validation-Only)

**Concept:** Run `npm run build`. Identify the specific compiled chunk file (e.g., `sysAdmin.[hash].chunk.js`) that contains the changed `info.js` source. Use `docker cp` to replace the existing file inside the running container's `media/assets/frontend/static/js/` with the new content — keeping the EXISTING hashed filename so `staticfiles.json` references still work.

**Pros:**
- No collectstatic needed
- No rebuild needed
- Fast validation that the React change actually compiles correctly and looks right in the browser

**Cons:**
- Changes do NOT persist across `docker compose down/up`
- Not a production approach — purely diagnostic
- Requires identifying which chunk file the change ended up in

**Recommended use:** "Smoke test" only — to verify the build is good before investing in a permanent solution. Then immediately move to a real bake (Option D or Strategy 1).

### 4.3 Option D — Multi-Stage Dockerfile with collectstatic-during-build (Untested, Most Aligned with Upstream)

**Concept:** Write a multi-stage Dockerfile:
- Stage 1: `FROM node:20-bullseye` — runs `npm install` and `npm run build`
- Stage 2: `FROM seafileltd/seafile-mc:13.0-latest` — COPYs the build output + rebrand files, then runs `collectstatic` in the fresh image layer

**Pros:**
- Mirrors what upstream Seafile does in their GitHub Actions CI
- Single `docker build` produces the final image — fully reproducible
- No VM-side Node concerns long-term (Node lives only in the build stage)
- Collectstatic runs in a *fresh* image layer (no runtime state) — DIFFERENT failure mode from the running-container approach we just saw fail
- Standard pattern across Django+webpack production deployments (multiple sources cited in research)

**Cons:**
- Untested for this codebase — we don't know yet if collectstatic-during-build hits the same seafevents wall
- Build will be slow (~10-15 min) because Node stage re-installs everything inside docker
- Wastes the 1011 MB of node_modules already on the VM (sunk cost — acceptable)
- May need to stub a minimal `seahub_settings.py` for the build phase

**Estimated success probability:** 60-70% on first try. If it fails, the docker build will show the exact error in stdout — much easier to iterate on than the running-container approach.

**Why it might work where docker exec didn't:**
A `RUN collectstatic` during `docker build` runs in a fresh image layer with NO container state. The seafevents subsystem we hit was triggered by *runtime* initialization that depends on having a fully-booted container. A fresh build layer doesn't have that boot state — Django might just load settings, run collectstatic, and exit cleanly.

**Why it might fail anyway:**
If Seahub's `settings.py` or any imported module unconditionally tries to connect to the seafevents pipe/socket, it'll fail in the build the same way. Without running it, we don't know.

---

## SECTION 5 — Decision Matrix for Tomorrow

### 5.1 If the goal is "ship info.js fix tonight, plan properly later"
1. Run `npm run build` (validates React side)
2. Do Option C surgical hot-swap (5 minutes to verify in browser)
3. Stop. Plan Strategy 1 vs Strategy 3 in a clean session.

### 5.2 If the goal is "do it right, multi-stage Dockerfile attempt"
1. Run `npm run build`
2. Draft multi-stage Dockerfile (Option D)
3. Try `docker build` — see what error or success comes out
4. Time-box: 2-3 attempts, ~30 minutes
5. If it works → done. If not → fall back to Option C and replan.

### 5.3 If the goal is "rethink the whole approach"
1. Do nothing tactical
2. Spend a planning session on Strategy 1 vs Strategy 3
3. Decide if the current heavy custom image is the right shape at all
4. Possibly restructure the project for long-term maintainability

### 5.4 My Recommendation

**Decision 5.2 (Option D attempt) is the highest-information move.** Either it works (best case, we ship), or it fails with a clear docker-build error that tells us exactly what's wrong (still better than nothing). The risk of wasting 30 minutes is low. The reward is potentially shipping the whole thing.

After Option D, regardless of outcome, sit down and decide Strategy 1 vs Strategy 3 properly. The 5-minute Option C validation could happen in parallel to provide a confidence baseline.

---

## SECTION 6 — Open Questions for Tomorrow

These are real unknowns that need answering or accepting:

1. **Does `npm run build` actually output to `frontend/build/frontend/` or `frontend/build/`?**
   Per `paths.js` line 29, default is `build/frontend`. The Dockerfile draft assumes `build/`. Only running the build resolves this.

2. **Where does `webpack-stats.pro.json` get written?**
   Currently exists at `frontend/webpack-stats.pro.json` in the running container. Build will regenerate it — need to verify the new file ends up where the Dockerfile expects it.

3. **Will collectstatic-during-Dockerfile-build hit the same seafevents wall as docker exec?**
   Unknown until tried. The fresh-layer hypothesis says no, but unproven.

4. **Does the running container's `seahub_settings.py` need to be available at docker build time?**
   Probably yes — `from seahub_settings import *` is the standard Seahub pattern. We'd need to either stub one for build or extract the running one.

5. **What is the file ownership pattern expected by the running Seahub?**
   `docker cp` into running container creates files with potentially wrong ownership. Worth checking what gunicorn expects (probably root for read-only static files, but verify).

6. **Are there hidden customization knobs we missed?**
   We documented the major ones (Appendix A) but the full `settings.py` is 1416 lines — there may be more obscure options for things like the "Community Edition" string, login page text, etc.

7. **Should the `.mo` locale files be committed to `tengis-wiki-fr`?**
   v1.3 Appendix C.6 says they were already committed. They are NOT. They're untracked on the VM, would need a commit before the next build to ensure reproducibility. Non-blocking but should be resolved.

---

## SECTION 7 — Concrete Commands Used This Session (Reference)

All commands are organized by where they ran and what they tested.

### 7.1 VM Pre-flight Checks

```bash
# Resources
free -h && echo "---" && df -h / && echo "---" && nproc
# Result: 31Gi RAM, 80GB free disk, 4 vCPUs ✅

# Toolchain
node --version && npm --version && gcc --version | head -1 && which msgfmt
# Result: v20.20.2, 10.8.2, gcc 13.3.0, /usr/bin/msgfmt ✅

# Repo state
cd ~/tengiswiki/tengis-wiki-fr && git log --oneline -3 && git status
cd ~/tengiswiki/tengis-wiki-docker && git log --oneline -3 && git status

# Deploy file backup
ls -lh /opt/tengis/seafile-server.yml /opt/tengis/seafile-server.yml.bak

# Running stack
docker ps && echo "---" && docker images | grep tengis
```

### 7.2 Mystery File Cleanup

```bash
cd ~/tengiswiki/tengis-wiki-fr
ls -lh 4355 72937 8049 FETCH_HEAD
file 4355 72937 8049 FETCH_HEAD
# Result: all empty 0-byte files
rm 4355 72937 8049 FETCH_HEAD
ls -lh .git/FETCH_HEAD
# Result: 105 bytes, intact
```

### 7.3 Inspecting the Running Container

```bash
# Confirm frontend/build/ does NOT exist
docker exec tengis-wiki ls /opt/seafile/seafile-server-13.0.21/seahub/frontend/build/

# Find where assets actually live
docker exec tengis-wiki ls /opt/seafile/seafile-server-13.0.21/seahub/media/assets/
# Result: frontend, scripts, staticfiles.json

# Size of assets
docker exec tengis-wiki du -sh /opt/seafile/seafile-server-13.0.21/seahub/media/assets/
# Result: 159 MB

# Webpack stats file
docker exec tengis-wiki find /opt/seafile/seafile-server-13.0.21/seahub/frontend -maxdepth 3 -name 'webpack-stats*.json'
# Result: /opt/seafile/seafile-server-13.0.21/seahub/frontend/webpack-stats.pro.json (75 KB)

# Django settings inspection
docker exec tengis-wiki grep -E "STATIC|MEDIA|WEBPACK" /opt/seafile/seafile-server-13.0.21/seahub/seahub/settings.py | head -20
```

### 7.4 Failed Collectstatic Dry-Run Sequence

```bash
# Attempt 1 — bare (FAILED: seaserv missing)
docker exec tengis-wiki bash -c "cd /opt/seafile/seafile-server-13.0.21/seahub && python3 manage.py collectstatic --dry-run --noinput"

# Find required PYTHONPATH from seahub.sh
docker exec tengis-wiki bash -c "cat /opt/seafile/seafile-server-13.0.21/seahub.sh | grep -E 'PYTHONPATH|export PATH' | head -20"

# Locate seaserv
docker exec tengis-wiki bash -c "find /opt/seafile -name 'seaserv*' -type d 2>/dev/null"
# Result: /opt/seafile/seafile-server-13.0.21/seafile/lib/python3/site-packages/seaserv

# Attempt 2 — with PYTHONPATH (FAILED: SEAFILE_CONF_DIR undefined)
docker exec tengis-wiki bash -c "
export INSTALLPATH=/opt/seafile/seafile-server-13.0.21
export PYTHONPATH=\$INSTALLPATH/seafile/lib/python3/site-packages:\$INSTALLPATH/seafile/lib64/python3/site-packages:\$INSTALLPATH/seahub:\$INSTALLPATH/seahub/thirdpart:\$PYTHONPATH
cd \$INSTALLPATH/seahub && python3 manage.py collectstatic --dry-run --noinput
"

# Get full env from running gunicorn
docker exec tengis-wiki bash -c "cat /proc/\$(pgrep -f 'gunicorn.*seahub' | head -1)/environ | tr '\0' '\n' | grep -iE 'SEAFILE|CCNET|PYTHON|PATH|JWT|CACHE|REDIS' | sort"

# Inspect seaserv source
docker exec tengis-wiki bash -c "head -45 /opt/seafile/seafile-server-13.0.21/seafile/lib/python3/site-packages/seaserv/service.py"

# Inspect Seahub config dirs
docker exec tengis-wiki bash -c "ls /opt/seafile/conf/ /opt/seafile/seafile-data/"
# Result: conf has gunicorn.conf.py, seafdav.conf, seafevents.conf, seafile.conf, seahub_settings.py
# Result: seafile-data has current_version, httptemp, library-template, storage, tmpfiles

# Attempt 3 — full env (FAILED: seafevents_api NoneType)
docker exec \
  -e SEAFILE_CENTRAL_CONF_DIR=/opt/seafile/conf \
  -e SEAFILE_DATA_DIR=/opt/seafile/seafile-data \
  -e SEAFILE_RPC_PIPE_PATH=/opt/seafile/seafile-server-13.0.21/runtime \
  -e PYTHONPATH=/opt/seafile/seafile-server-13.0.21/seafile/lib/python3/site-packages:/opt/seafile/seafile-server-13.0.21/seafile/lib64/python3/site-packages:/opt/seafile/seafile-server-13.0.21/seahub:/opt/seafile/seafile-server-13.0.21/seahub/thirdpart:/opt/seafile/conf \
  -e JWT_PRIVATE_KEY=b85c69cd52ae4cf8a9b943722875ebe2 \
  -e SEAFILE_MYSQL_DB_HOST=tengis-db \
  -e SEAFILE_MYSQL_DB_USER=seafile \
  -e SEAFILE_MYSQL_DB_PASSWORD=Ankara123 \
  -e SEAFILE_MYSQL_DB_PORT=3306 \
  -e SEAFILE_MYSQL_DB_CCNET_DB_NAME=ccnet_db \
  -e SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=seafile_db \
  -e SEAFILE_MYSQL_DB_SEAHUB_DB_NAME=seahub_db \
  -e REDIS_HOST=tengis-redis \
  -e REDIS_PORT=6379 \
  -e CACHE_PROVIDER=redis \
  tengis-wiki \
  bash -c "cd /opt/seafile/seafile-server-13.0.21/seahub && python3 manage.py collectstatic --dry-run --noinput"
```

### 7.5 Not Yet Run (Tomorrow's Starting Point)

```bash
# The build that we never got to
cd ~/tengiswiki/tengis-wiki-fr/frontend
NODE_OPTIONS=--max-old-space-size=4096 npm run build

# Then inspect output
ls -la frontend/build/
find frontend -name 'webpack-stats*.json'
```

---

## APPENDIX A — Official Seafile Customization Mechanism (FULL REFERENCE)

**This is the appendix the user explicitly wants prominent.** It documents the official Seafile customization mechanism that the project never used. Use this for future strategic decisions.

### A.1 Branding Paths — All Overridable in `seahub_settings.py`

Source: `seahub/settings.py` from upstream master (verified during this session via direct GitHub fetch).

| Setting | Default Value | What It Controls |
|---|---|---|
| `LOGO_PATH` | `'img/seafile-logo.png'` | Main logo (top-left header) |
| `LOGO_WIDTH` | `''` (auto) | Logo width in pixels |
| `LOGO_HEIGHT` | `32` | Logo height in pixels |
| `FAVICON_PATH` | `'favicons/favicon.png'` | Browser tab icon |
| `APPLE_TOUCH_ICON_PATH` | `'favicons/favicon.png'` | iOS home-screen icon |
| `LOGIN_BG_IMAGE_PATH` | `'img/login-bg.jpg'` | Login page background |
| `CUSTOM_LOGO_PATH` | `'custom/mylogo.png'` | Convention path for custom logo |
| `CUSTOM_FAVICON_PATH` | `'custom/favicon.ico'` | Convention path for custom favicon |
| `CUSTOM_LOGIN_BG_PATH` | `'custom/login-bg.jpg'` | Convention path for custom login bg |
| `BRANDING_CSS` | `''` | Path to custom CSS file (e.g., `'custom/custom.css'`) |
| `ENABLE_BRANDING_CSS` | `False` | Enables admin UI to set CSS via web interface (6.3+) |

### A.2 Identity / Text Strings — All Overridable

| Setting | Default Value | What It Controls |
|---|---|---|
| `SITE_TITLE` | `'Private Seafile'` | Browser tab title |
| `SITE_NAME` | `'Seafile'` | Name used in emails |
| `SITE_DESCRIPTION` | `''` | HTML head meta description (SEO) |
| `HELP_LINK` | `''` | URL of help page (replaces default seafile.com link) |
| `PRIVACY_POLICY_LINK` | `''` | Footer privacy policy link |
| `TERMS_OF_SERVICE_LINK` | `''` | Footer terms link |
| `SUPPORT_EMAIL` | `''` | Support contact email |

### A.3 Template Overrides — THE BIG ONE

**Source:** `seahub/settings.py` TEMPLATES configuration:
```python
TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [
        os.path.join(PROJECT_ROOT, '../../seahub-data/custom/templates'),
        os.path.join(PROJECT_ROOT, 'seahub/templates'),
    ],
    ...
}]
```

**Implication:** Django checks `seahub-data/custom/templates/` **BEFORE** `seahub/templates/`. Any HTML template can be overridden by placing a file with the same relative path under the custom dir.

**What this means in practice:** Instead of editing files inside the image (current heavy custom image approach), drop overriding templates into a bind-mounted directory. Examples:

| Original Template Path | Override Path |
|---|---|
| `seahub/templates/download.html` | `seahub-data/custom/templates/download.html` |
| `seahub/templates/footer.html` | `seahub-data/custom/templates/footer.html` |
| `seahub/help/templates/help/base.html` | `seahub-data/custom/templates/help/base.html` |
| `seahub/help/templates/help/install.html` | `seahub-data/custom/templates/help/install.html` |
| (all 25 help template files) | (mirror under `custom/templates/help/`) |
| Any email template | `seahub-data/custom/templates/<original-path>` |

### A.4 Navigation Override

```python
CUSTOM_NAV_ITEMS = [
    {'icon': 'sf2-icon-star', 'desc': 'Custom navigation 1', 'link': 'https://example.com'},
    {'icon': 'sf2-icon-wiki-view', 'desc': 'Help', 'link': 'https://redirish.global/help'},
    {'icon': 'sf2-icon-wrench', 'desc': 'Tools', 'link': 'https://tools.example.com'},
]
```

Icons must start with `sf2-icon-` (Seafile's built-in icon set).

### A.5 What Official Customization CAN Replace From Current Tengis Wiki Work

| Current Heavy Custom Image Overlay | Official Equivalent |
|---|---|
| `media/img/seafile-logo.png` baked into image | `custom/mylogo.png` + `LOGO_PATH = 'custom/mylogo.png'` |
| `media/img/seafile-logo-dark.png` baked | `custom/mylogo-dark.png` + (uses CSS for dark mode) |
| `media/favicons/favicon.png` baked | `custom/favicon.png` + `FAVICON_PATH = 'custom/favicon.png'` |
| `media/css/seafile-ui.css` edits (color tokens) | `custom/custom.css` + `BRANDING_CSS = 'custom/custom.css'` |
| `seahub/templates/download.html` baked | `seahub-data/custom/templates/download.html` |
| 25 help templates baked into image | `seahub-data/custom/templates/help/*.html` |
| Site Title (admin panel) | `SITE_TITLE = 'Tengis Wiki'` in `seahub_settings.py` |
| Site Name in emails | `SITE_NAME = 'Tengis Wiki'` in `seahub_settings.py` |

### A.6 What CANNOT Be Done Via Official Customization (Custom Image STILL Required)

1. **The `info.js` React-bundled "Community Edition" string** — React source must be rebuilt and collectstatic'd.
2. **Locale `.po` / `.mo` translation overrides** — These live inside `seahub/locale/` (a specific Django app dir, not in TEMPLATES.DIRS). The `custom/` mechanism does NOT cover locale files.
3. **Docker container names** — Set in `seafile-server.yml`, no in-image override.
4. **Docker image registry name** — `seafileltd/seafile-mc` vs `tengis/tengis-wiki` is a Docker tag concern, not a Seahub config.
5. **Network names** — `seafile-net` vs `tengis-net` is Docker compose only.

### A.7 The Deployment Shape Under Pure custom/ Approach (Strategy 1)

If Tengis Wiki went pure-official customization, the deployment would look like:

```
/opt/tengis/
├── seafile-server.yml          # Docker compose (uses vanilla seafileltd/seafile-mc:13.0-latest)
├── .env                        # Environment variables
├── seafile-server.yml.bak      # Manual backup
└── seahub-data/                # ← BIND-MOUNTED into container at /shared/seahub/
    └── custom/
        ├── mylogo.png          # 256×64 Tengis logo
        ├── mylogo-dark.png     # 256×64 dark variant
        ├── favicon.png         # 512×512 favicon
        ├── login-bg.jpg        # (optional) custom login background
        ├── custom.css          # All Tengis color variables + custom styles
        └── templates/          # Template overrides
            ├── download.html
            ├── footer.html
            └── help/           # Override directory
                ├── base.html
                ├── install.html
                ├── ... (25 files total, only those needing override)
```

And `seahub_settings.py` (typically at `/opt/seafile/conf/seahub_settings.py`) would include:

```python
# Branding paths
LOGO_PATH = 'custom/mylogo.png'
LOGO_WIDTH = 256
LOGO_HEIGHT = 64
FAVICON_PATH = 'custom/favicon.png'
APPLE_TOUCH_ICON_PATH = 'custom/favicon.png'
LOGIN_BG_IMAGE_PATH = 'custom/login-bg.jpg'  # optional
BRANDING_CSS = 'custom/custom.css'

# Identity
SITE_TITLE = 'Tengis Wiki'
SITE_NAME = 'Tengis Wiki'
SITE_DESCRIPTION = 'Tengis Wiki - File sync, share, and knowledge management'
HELP_LINK = 'https://redirish.global/help'
PRIVACY_POLICY_LINK = 'https://redirish.global/privacy'
TERMS_OF_SERVICE_LINK = 'https://redirish.global/terms'
SUPPORT_EMAIL = 'support@tengis.local'

# Optional navigation customization
CUSTOM_NAV_ITEMS = [
    {'icon': 'sf2-icon-wiki-view', 'desc': 'Tengis Help', 'link': 'https://redirish.global/help'},
]
```

### A.8 Commands to Set This Up (If Strategy 1 Is Chosen)

```bash
# On VM
sudo mkdir -p /opt/tengis/seahub-data/custom/templates/help

# Place logo files (use Python Pillow to resize to required dimensions per v1.3 §C.4)
cp /path/to/tengis_256.png /opt/tengis/seahub-data/custom/mylogo.png
cp /path/to/tengis_dark.png /opt/tengis/seahub-data/custom/mylogo-dark.png
cp /path/to/tengis_512.png /opt/tengis/seahub-data/custom/favicon.png

# Create custom CSS (the color overrides from v1.3 §3.4 go here)
cat > /opt/tengis/seahub-data/custom/custom.css << 'EOF'
:root {
    --bs-primary: #4A4EC7;
    --bs-link-color: #4A4EC7;
    --bs-link-hover-color: #3a3ea0;
    --bs-body-color: #0D0D0D;
    --bs-primary-rgb: 74,78,199;
}
EOF

# Mirror templates from the running container (for those needing override)
docker cp tengis-wiki:/opt/seafile/seafile-server-13.0.21/seahub/seahub/templates/download.html \
    /opt/tengis/seahub-data/custom/templates/download.html
# Then edit it on the host

# Add volume mount in seafile-server.yml (under tengis-wiki service):
# volumes:
#   - /opt/tengis/seahub-data:/shared/seahub-data
# Note: actual mount path may differ — verify with `docker inspect` and the official docs

# Add settings to seahub_settings.py (the running container's copy)
docker cp tengis-wiki:/opt/seafile/conf/seahub_settings.py /tmp/seahub_settings.py
# Edit /tmp/seahub_settings.py to add all the LOGO_PATH, SITE_TITLE etc.
docker cp /tmp/seahub_settings.py tengis-wiki:/opt/seafile/conf/seahub_settings.py

# Restart
cd /opt/tengis && docker compose restart tengis-wiki
```

**⚠️ Caveats for Strategy 1:**
1. The exact bind mount path inside the container is **not yet verified**. The official docs use `seahub-data/custom/...` paths assuming binary installation; the docker mount equivalent may be at `/shared/seahub-data/...` (volume convention) or elsewhere. **Must be confirmed before implementing.**
2. `seahub_settings.py` lives at `/opt/seafile/conf/` inside the container. Whether this is bind-mounted to the host (via docker volumes) needs confirmation.
3. Help templates need `mkdir templates/help/` AND the parent's `base.html` to be copied if just one help page is overridden (per official docs).

---

## APPENDIX B — Environment Variables Required for Collectstatic

The known env vars that Seahub needs for Django to load far enough to attempt collectstatic. Documented for future use (if Strategy 2 path is chosen and we attempt Option D).

```bash
# Paths (configuration locations)
SEAFILE_CENTRAL_CONF_DIR=/opt/seafile/conf
SEAFILE_DATA_DIR=/opt/seafile/seafile-data
SEAFILE_RPC_PIPE_PATH=/opt/seafile/seafile-server-13.0.21/runtime
SEAHUB_DIR=/opt/seafile/seafile-server-13.0.21/seahub
SEAHUB_LOG_DIR=/opt/seafile/logs
SEAFILE_LOG_TO_STDOUT=false

# Python path (so seaserv, settings, etc. can be imported)
PYTHONPATH=/opt/seafile/seafile-server-13.0.21/seafile/lib/python3/site-packages:/opt/seafile/seafile-server-13.0.21/seafile/lib64/python3/site-packages:/opt/seafile/seafile-server-13.0.21/seahub:/opt/seafile/seafile-server-13.0.21/seahub/thirdpart:/opt/seafile/conf:/opt/seafile/seafile-server-13.0.21/pro/python

# Secrets
JWT_PRIVATE_KEY=b85c69cd52ae4cf8a9b943722875ebe2

# Database connection (used by seafevents and admin commands)
SEAFILE_MYSQL_DB_HOST=tengis-db
SEAFILE_MYSQL_DB_USER=seafile
SEAFILE_MYSQL_DB_PASSWORD=Ankara123
SEAFILE_MYSQL_DB_PORT=3306
SEAFILE_MYSQL_DB_CCNET_DB_NAME=ccnet_db
SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=seafile_db
SEAFILE_MYSQL_DB_SEAHUB_DB_NAME=seahub_db

# Cache
CACHE_PROVIDER=redis
REDIS_HOST=tengis-redis
REDIS_PORT=6379
REDIS_PASSWORD=

# Server identity
SEAFILE_SERVER=seafile-server
SEAFILE_VERSION=13.0.21
SEAFILE_SERVER_HOSTNAME=192.168.2.111
SEAFILE_SERVER_PROTOCOL=http

# Pro/optional (may not be required)
SEAFES_DIR=/opt/seafile/seafile-server-13.0.21/pro/python/seafes
SEAFILE_AI_SECRET_KEY=b85c69cd52ae4cf8a9b943722875ebe2
SEAFILE_AI_SERVER_URL=http://seafile-ai:8888
```

**Note:** Even with all these set, the seafevents_api initialization still failed in our dry-run. The cause is deeper than env vars — it's the runtime state of the seafevents subsystem (sockets, supervisor processes) that doesn't exist outside a fully-booted container.

---

## APPENDIX C — Key File Paths Reference

For quick lookup when planning the next session.

### C.1 Inside the Running Container (tengis-wiki)

| Path | Purpose |
|---|---|
| `/opt/seafile/seafile-server-13.0.21/` | INSTALLPATH — main install dir |
| `/opt/seafile/seafile-server-13.0.21/seahub/` | Seahub Django source |
| `/opt/seafile/seafile-server-13.0.21/seahub/seahub/settings.py` | Django defaults |
| `/opt/seafile/seafile-server-13.0.21/seahub/manage.py` | Django entry point |
| `/opt/seafile/seafile-server-13.0.21/seahub/media/assets/` | Static files served by nginx (159 MB) |
| `/opt/seafile/seafile-server-13.0.21/seahub/media/assets/staticfiles.json` | Django ManifestStaticFilesStorage manifest |
| `/opt/seafile/seafile-server-13.0.21/seahub/frontend/webpack-stats.pro.json` | webpack-loader stats file |
| `/opt/seafile/seafile-server-13.0.21/seafile/lib/python3/site-packages/seaserv/` | seaserv Python bindings |
| `/opt/seafile/conf/seahub_settings.py` | Runtime-generated Django settings |
| `/opt/seafile/conf/seafile.conf` | Seafile server config |
| `/opt/seafile/conf/seafevents.conf` | Event system config |
| `/opt/seafile/conf/seafdav.conf` | WebDAV config |
| `/opt/seafile/seafile-data/` | Seafile data dir |
| `/opt/seafile/seafile-server-13.0.21/seahub.sh` | Seahub startup script (where PYTHONPATH is exported) |

### C.2 On the VM (host)

| Path | Purpose |
|---|---|
| `~/tengiswiki/tengis-wiki-fr/` | Seahub rebrand repo (in sync with Mac at 67d8376e4) |
| `~/tengiswiki/tengis-wiki-fr/frontend/` | React source |
| `~/tengiswiki/tengis-wiki-fr/frontend/node_modules/` | 1011 MB, install complete |
| `~/tengiswiki/tengis-wiki-fr/locale/` | .po files + 7 untracked .mo files |
| `~/tengiswiki/tengis-wiki-docker/` | Docker repo (1 behind Mac at 18ce4eb) |
| `~/tengiswiki/tengis-wiki-docker/Dockerfile` | Current Dockerfile (unchanged from origin) |
| `~/tengiswiki/tengis-wiki-docker/.dockerignore` | Current .dockerignore (unchanged from origin) |
| `/opt/tengis/seafile-server.yml` | Active compose file |
| `/opt/tengis/.env` | Compose environment variables |
| `/opt/tengis/seafile-server.yml.bak` | Manual backup |

### C.3 On the Mac

| Path | Purpose |
|---|---|
| `~/tengiswiki/tengis-wiki-fr/` | Synced to GitHub at 67d8376e4 |
| `~/tengiswiki/tengis-wiki-docker/` | At 7d40ed3, with TWO uncommitted (incorrect) drafts |
| `~/tengiswiki/tengis-wiki-docker/Dockerfile` | Draft adds frontend/build/ COPY (incorrect — doesn't address collectstatic) |
| `~/tengiswiki/tengis-wiki-docker/.dockerignore` | Draft adds !frontend/build and !webpack-stats.pro.json |

---

## APPENDIX D — New Session Handoff Note

Copy-paste this at the start of the next session:

```
I am continuing the Tengis Wiki project. Read these documents in order:
1. tengis-wiki-project-guide-v1.3.md (overall context)
2. tengis-wiki-frontend-build-v1.0.md (npm install session)
3. tengis-wiki-frontend-build-v1.1.md (this session — read fully)

CURRENT STATE:
- VM: 192.168.2.111, user akin, 32GB RAM, 80GB free disk
- Node.js 20 installed, npm install complete (1011 MB node_modules)
- tengis-wiki-fr at 67d8376e4 on both Mac and VM
- tengis-wiki-docker: Mac at 7d40ed3 + 2 INCORRECT uncommitted drafts; VM at 18ce4eb (1 behind)
- Image tengis/tengis-wiki:13.0.21 running healthy
- Frontend NOT yet built (npm run build not executed)
- collectstatic via docker exec FAILED — see v1.1 Section 2

DECISION NEEDED:
Choose between:
- Strategy 1 (pure official customization with custom/ dir + seahub_settings.py)
- Strategy 2 (continue current heavy custom image, try Option D)
- Strategy 3 (hybrid — Strategy 2 base + custom/ overlay for per-customer)

AND for tonight's tactical move:
- Option C (docker cp surgical hot-swap, validation only)
- Option D (multi-stage Dockerfile with collectstatic-during-build)
- Run npm run build first to validate React side, then decide

THE BIG NEW INSIGHT (Appendix A of v1.1):
Seafile has an official customization mechanism using seahub-data/custom/ directory
and seahub_settings.py overrides for LOGO_PATH, FAVICON_PATH, BRANDING_CSS, SITE_TITLE,
SITE_NAME, template overrides via TEMPLATES.DIRS, and CUSTOM_NAV_ITEMS. This was never used.
It could potentially replace 70% of the current custom-image overlays.

LIKELY NEXT MOVE:
1. Run npm run build to validate React side
2. Decide Strategy 1 vs 3
3. If 3, try Option D (multi-stage Dockerfile) — accept ~30 min iteration time-box
4. If Option D fails, fall back to Option C for tonight, replan
```

---

## APPENDIX E — Errors Encountered (Quick Reference)

For pattern-matching in the next session.

### E.1 ModuleNotFoundError: seaserv
**Symptom:** `ModuleNotFoundError: No module named 'seaserv'` at line 10 of `seahub/settings.py`
**Cause:** PYTHONPATH not set when invoking via `docker exec bash -c`
**Fix:** Set PYTHONPATH to include seaserv's directory (see Appendix B)

### E.2 ImportError: SEAFILE_CONF_DIR undefined
**Symptom:** `ImportError: Seaserv cannot be imported, because environment variable SEAFILE_CONF_DIR is undefined.`
**Cause:** seaserv's `service.py` requires `SEAFILE_DATA_DIR` (or `SEAFILE_CONF_DIR` legacy) plus `SEAFILE_CENTRAL_CONF_DIR`
**Fix:** Set both via -e flags on docker exec

### E.3 ModuleNotFoundError: seahub_settings
**Symptom:** `ModuleNotFoundError: No module named 'seahub_settings'`
**Cause:** `/opt/seafile/conf/` not in PYTHONPATH (that's where seahub_settings.py lives)
**Fix:** Add `/opt/seafile/conf` to PYTHONPATH

### E.4 AttributeError: 'NoneType' object has no attribute 'init_db_session_class'
**Symptom:** Error at `seahub/utils/__init__.py` line 577
**Cause:** `seafevents_api` initialized to None — seafevents subsystem requires runtime state (sockets, supervisor) that doesn't exist outside a fully-booted container
**Fix:** Unknown via docker exec route. Possibly resolved by running collectstatic in a fresh build layer (Option D) which doesn't have boot state expectations.

---

## APPENDIX F — Web Research Sources Consulted

For future reference, the authoritative sources used in this session's research, in priority order:

### F.1 Primary (Authoritative for Seafile)

| Source | Purpose | URL |
|---|---|---|
| Seafile Admin Manual — Seahub Customization | Official customization options (LOGO_PATH, FAVICON_PATH, BRANDING_CSS, templates) | `https://manual.seafile.com/12.0/config/seahub_customization/` |
| Upstream seahub/settings.py (master) | Source-of-truth for all overridable settings | `https://github.com/haiwen/seahub/blob/master/seahub/settings.py` |
| seafile-admin-docs (master) | Markdown source of the admin manual | `https://github.com/haiwen/seafile-admin-docs/blob/master/manual/config/seahub_customization.md` |

### F.2 Primary (Authoritative for Django+webpack pattern)

| Source | Purpose | URL |
|---|---|---|
| django-webpack-loader docs | The library Seahub uses; pattern docs explicitly recommend "production pipeline generates bundle + stats during deployment, use collectstatic" | (search for `django-webpack-loader` on PyPI; library author: django-webpack) |

### F.3 Pattern References (How Others Do It)

| Source | Pattern | URL |
|---|---|---|
| nezhar.com — Django static files docker image | ENV stubs (SECRET_KEY=static, DATABASE_URL=static, etc.) before RUN collectstatic | `https://nezhar.com/blog/create-docker-image-to-store-django-static-files/` |
| MasterKale/Docker-Django Dockerfile | ARG DJANGO_SECRET_KEY at build time | `https://github.com/MasterKale/Docker-Django/blob/master/Dockerfile` |
| Django-q issue #743 | Discussion of SECRET_KEY-only requirement for collectstatic | `https://github.com/Koed00/django-q/issues/743` |

### F.4 Forum / Anecdotal (Use With Care)

- Seafile community forum threads on custom CSS (older 7.x discussions; some patterns deprecated in 13.x)
- Various Stack Overflow answers on docker-django collectstatic (general patterns, not Seahub-specific)

**⚠️ Note:** Forum content older than ~2022 may reference deprecated Seafile config patterns. The settings.py from upstream master (F.1) is the canonical source.

---

## APPENDIX G — What Definitely Works (Don't Touch)

A list of things that ARE working today, anchoring future planning. The next session should not accidentally break these.

### G.1 Current Visible Working Features

- Container `tengis-wiki` running healthy on VM port 80 → admin@tengis.local / Ankara123 login works
- Tengis logo appears in header (light + dark mode)
- Tengis favicon in browser tab
- Tengis Blue (`#4A4EC7`) primary color throughout UI (`media/css/seafile-ui.css`)
- All Help pages show "Tengis Wiki" branding (`seahub/help/templates/*.html`)
- About dialog shows © Tengis Wiki (`seahub/templates/`)
- All Turkish (`tr`) and Indonesian (`id`) locale strings show Tengis branding
- All English (`en`, `en_US`) msgstr translations show Tengis Wiki
- All redis/mariadb services attached to `tengis-net` with `tengis-*` container names
- Image `tengis/tengis-wiki:13.0.21` is 2.39 GB, ID `8df46899cbdc`

### G.2 The Base Image Is Proof-of-Concept

`seafileltd/seafile-mc:13.0-latest` itself was built somewhere with a successful collectstatic step (visible in the running container's `media/assets/staticfiles.json` with `/home/runner/work/seahub/seahub/...` paths — GitHub Actions runner paths).

This proves the collectstatic + multi-stage pattern works for Seahub. We're not trying to invent a new pattern; we're trying to reproduce one whose solution is known to upstream. If we can't, the fallback is: use upstream's pre-built collectstatic output (via the base image) and only overlay non-collectstatic-requiring changes.

### G.3 Things NOT Visible But Already in the Image

These are in commit `67d8376e4` of `tengis-wiki-fr` and were already baked into the running image (per v1.3 image build):
- CSS color fix (`--bs-primary-rgb`)
- Logo/favicon files
- Help templates
- `.mo` locale binaries
- Most rebrand strings in non-React templates

These don't need rebuilding. **Only the React-bundled `info.js` change requires a frontend rebuild.**

---

## APPENDIX H — Mac Repo Cleanup Before Next Session

⚠️ **Action needed before any image rebuild work.**

The Mac copy of `tengis-wiki-docker` has TWO uncommitted modifications:
- `Dockerfile` (adds COPY for frontend/build/ and webpack-stats.pro.json)
- `.dockerignore` (adds !frontend/build and !webpack-stats.pro.json re-includes)

These drafts are **architecturally incorrect** (they don't address collectstatic / `media/assets/`). They should not be committed as-is. Two options for the next session start:

### H.1 Option 1 — Stash and Set Aside (Recommended)
```bash
cd ~/tengiswiki/tengis-wiki-docker
git stash push -m "v1.0-frontend-build-drafts-do-not-use" Dockerfile .dockerignore
git status   # should now be clean
```

This preserves them for reference but gets them out of the way. Recoverable via `git stash list` and `git stash show stash@{0}`.

### H.2 Option 2 — Revert Cleanly
```bash
cd ~/tengiswiki/tengis-wiki-docker
git checkout -- Dockerfile .dockerignore
git status   # should now be clean
```

This throws them away entirely. They're documented in this v1.1 file's §1.3 if you ever need to reconstruct.

### H.3 Then Sync the VM
```bash
ssh akin@192.168.2.111
cd ~/tengiswiki/tengis-wiki-docker
git pull origin master   # fast-forwards from 18ce4eb → 7d40ed3
git log --oneline -1     # should show 7d40ed3
```

After this, Mac and VM are both at `7d40ed3` with clean working trees, ready for whatever fresh approach is chosen.

---

## APPENDIX I — Token / Context Budget Notes for Next Session

This session consumed significant context window in the chat-based Claude assistant. To preserve budget in the next session:

1. **Upload this v1.1 document and the previous v1.0 + v1.3 files**, then have Claude skim, not deep-read.
2. **Don't paste full `docker exec` traces** — `tail -30` plus a line count is enough for diagnostics.
3. **Don't repaste full file contents** if Claude has already seen them in a previous session via the uploaded handoff doc.
4. **For npm build output**, just paste the final summary lines (success or first error), not the full log.
5. **`docker build` output** can be enormous — pipe to a file and paste only the failure region if one occurs.

Approximate budget heuristic: this session used ~30-40% of the context window. With the new uploads, next session starts at ~15-20% from documents alone, leaving 80% for actual work. Be mindful of long paste-outs.

---

**End of v1.2.**

Update this document at the end of the next session with v1.3 covering whichever path was taken.
