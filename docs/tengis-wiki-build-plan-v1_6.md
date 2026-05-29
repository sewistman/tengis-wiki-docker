# Tengis Wiki — Docker Image Build Plan
**Version 1.6 — May 2026**
**Author:** Planning session between Akin and Claude
**Purpose:** Complete build plan for the next working session. Read from top to bottom before touching anything.

---

## VERSION HISTORY

| Version | Date | Changes |
|---|---|---|
| v1.0 | May 2026 | Initial plan; chose Strategy 3 (hybrid) + Option D (multi-stage Dockerfile with collectstatic in build stage). |
| v1.1 | May 2026 | After validation research: confirmed runtime `seahub_settings.py` is 3 lines, confirmed RPCProxy path is what CE actually uses, confirmed seafevents runs as standalone process independent of Django, confirmed `seafile-build.py` does NOT run collectstatic (upstream pre-builds elsewhere). Promoted **Option J (collectstatic on VM, COPY into image)** to primary path. Option D kept as fallback. Stub seahub_settings.py reduced from ~15 lines to 3 lines (mirrors real runtime). |
| v1.2 | May 2026 | **Option J executed successfully.** Four corrections from live execution: (1) `SEAFILE_VERSION` was already `6.3.3` in base repo — requires `sed` replacement, not append. (2) `manage.py` is at repo root, not inside `seahub/`. (3) `captcha` and other Django apps live in container's system Python (`/usr/local/lib/python3.12/dist-packages`) — requires a third `docker cp` to `system-dist-packages/`. (4) `DATABASES` sqlite3 override IS required in stub despite v1.1 saying otherwise — Django loads the DB backend during `INSTALLED_APPS` init even for `collectstatic`. Also confirmed: `frontend/build/` output is nested as `frontend/build/frontend/`; `media/assets/` lands at repo root, not `seahub/media/assets/`. **Build result: `tengis/tengis-wiki:13.0.21-r2` deployed, System Info shows "Tengis Wiki".** |
| v1.3 | May 2026 | **Claimed project complete** — but contained three errors in Phase 7: (1) `tengis-wiki-fr` final commit was `09f749085` — missing `seahub/settings.py` version fix and `.gitignore` build artifact entries. (2) VM `tengis-wiki-docker` was never synced after force push and was left at stale WIP commit `3ca9016`. (3) Mac `tengis-wiki-fr` was never pulled after VM pushed. Document stated all repos clean — this was incorrect. |
| v1.4 | May 2026 | **Verified step-by-step against actual terminal output.** Three Phase 7 issues discovered and fixed: VM docker repo synced to `27b3a9a` via `git fetch + git reset --hard`; Mac `tengis-wiki-fr` pulled to `09f749085` then to `4399bc278`; `seahub/settings.py` SEAFILE_VERSION change committed; `frontend/webpack-stats.pro.json` untracked and `.gitignore` updated for both it and `media/assets/`. Two new findings: `.dockerignore` placement bug (file must be at build context root, not adjacent to Dockerfile); build artifacts must be in `.gitignore` before first build. **True final commit: `tengis-wiki-fr` at `4399bc278`, `tengis-wiki-docker` at `27b3a9a`.** |
| v1.5 | May 2026 | **Documentation consolidation — no rebuild needed.** Folded in unique content from soon-to-be-deleted predecessor docs: image compressed sizes added to §2 (from v1.2); upstream `Seahub` class source code + GitHub URL added to Finding 6 (from v1.1); configparser detail added to Finding 3 (from v1.1); seafevents-in-CE explanation expanded in Finding 5 (from v1.1); four-bullet practical rationale for Option J added to §6 (from v1.1); two rejected-option rows added to Decision Record §12 (from v1.1); VM apt-install prerequisites note added to §8 Phase 1 (from frontend-build v1.0); §13 changelog updated to cover v1.4 → v1.5 transition. |
| v1.6 | May 2026 | **Absorbed v1.0 (the original planning document) into this plan; v1.0 deleted.** §9 (Phase 8 — Fallback to Option D) expanded from a 10-line stub into five subsections: when to use, the v1.4 corrections (preserved), full multi-stage Dockerfile sketch with v1.4 fixes baked in, error→cause→fix decision table for build failures, and explicit rollback procedure. Task 6.3 (Browser verification) extended with three seafevents-integration checks (file history, search, browser tab title) — these specifically validate that the build-time RPCProxy isolation didn't break runtime. New §14 (Future Seafile Upgrade Process) added — five-step recipe for handling upstream releases. After v1.6 is saved, `tengis-wiki-build-plan-v1_0.md` can be deleted; canonical doc set drops from 4 documents to 3. |

---

## 1. What This Document Is

This is a self-contained handoff plan. It explains what the project is, what was tried before, why it failed, what we learned from the actual Seafile source code, which approach we chose, and exactly what to do step by step.

If you are reading this for the first time, do not skip Sections 2, 3, and 4. Every decision in this plan depends on understanding what was already proven.

---

## 2. What You Are Building

You are rebranding Seafile — an open-source self-hosted file sync and wiki platform — into a commercial product called **Tengis Wiki**. The goal is a Docker image (`tengis/tengis-wiki`) where everything the end user sees says Tengis Wiki instead of Seafile or Community Edition.

### What is already done and working

The current image `tengis/tengis-wiki:13.0.21-r2` is running on VM `192.168.2.111`. The following customizations are visible in the browser:

- CSS color tokens (Tengis brand colors)
- Logos and favicons
- Help templates (25 files)
- Turkish and Indonesian locale overrides (`.mo` files committed and baked into image)
- Footer and download page templates
- **System Info admin page shows "Tengis Wiki"** (was "Community Edition" — fixed in v1.2 build)

### Repository state — TRUE FINAL (v1.4 verified)

| Repo | Commit | Mac | VM | Origin | Status |
|---|---|---|---|---|---|
| `tengis-wiki-fr` | `4399bc278` | ✅ | ✅ | ✅ | Clean, all in sync |
| `tengis-wiki-docker` | `27b3a9a` | ✅ | ✅ | ✅ | Clean, all in sync |

### Final commit log — `tengis-wiki-fr`

```
4399bc278  build: update settings version, gitignore build artifacts
09f749085  Add compiled Turkish and Indonesian locale files
67d8376e4  rebrand: fix primary-rgb color token and update sys-admin info strings
```

### Final commit log — `tengis-wiki-docker`

```
27b3a9a  Use pre-built frontend + collectstatic output (Option J)
7d40ed3  build: add .dockerignore for custom image build
18ce4eb  build: add custom image Dockerfile
671d90d  rebrand: replace Seafile product name in README and build/README.md
```

### Final Docker image state on VM

```
REPOSITORY                TAG          IMAGE ID       SIZE
tengis/tengis-wiki        13.0.21      8df46899cbdc   2.39GB   (old — still present, not removed)
tengis/tengis-wiki        13.0.21-r2   7923e5e4c72b   2.76GB   (ACTIVE — running in stack)
```

**Compressed sizes** (relevant if pushing to Docker Hub or computing pull bandwidth):

| Tag | Uncompressed | Compressed |
|---|---|---|
| `13.0.21` | 2.39 GB | 570 MB |
| `13.0.21-r2` | 2.76 GB | 644 MB |

The compressed delta (+74 MB) is the React frontend build output and the post-collectstatic `media/assets/` directory baked in by Option J.

### Final running stack state

```
NAMES          IMAGE                           STATUS
tengis-wiki    tengis/tengis-wiki:13.0.21-r2   Up (healthy)
tengis-redis   redis                           Up
tengis-db      mariadb:10.11                   Up (healthy)
```

### Browser verification result

| Check | Result |
|---|---|
| Login page | ✅ Tengis branding |
| Logo | ✅ Tengis logo |
| Admin → System Info | ✅ **"Tengis Wiki"** — primary goal achieved |
| Version shown | ✅ 13.0.21 |

---

## 3. What Was Tried Before and Why It Failed

### Option A — docker exec collectstatic on running container

The first attempt was to run `collectstatic` inside the already-running container using `docker exec`. This failed through four layers:

**Layer 1:** `ModuleNotFoundError: No module named 'seaserv'`
Fix: Set `PYTHONPATH` to include seaserv's non-standard install path.

**Layer 2:** `ImportError: Seaserv cannot be imported, because environment variable SEAFILE_CONF_DIR is undefined`
Fix: Set `SEAFILE_DATA_DIR` and `SEAFILE_CENTRAL_CONF_DIR`.

**Layer 3:** `ModuleNotFoundError: No module named 'seahub_settings'`
Fix: Add `/opt/seafile/conf` to `PYTHONPATH`.

**Layer 4 — The Wall:** `AttributeError: 'NoneType' object has no attribute 'init_db_session_class'`

This is where the attempt stopped. Django's `seahub/utils/__init__.py` imports `seafevents_api` and calls `init_db_session_class()` on it. In the running container context reached via `docker exec`, `seafevents_api` was imported successfully but returned `None`, and the existing `except ImportError` handler did not catch the `AttributeError`. The seafevents subsystem requires live sockets and a fully booted supervisor process — none of which exist in a fresh exec shell.

**This path is permanently closed.** Option A was abandoned.

---

## 4. What We Learned From Source Code and Live Inspection

### Finding 1 — The seafevents import is already conditional

From `seahub/utils/__init__.py` (verified from haiwen/seahub master):

```python
if EVENTS_CONFIG_FILE:
    try:
        from seafevents import seafevents_api
    except ImportError:
        logging.exception('Failed to import seafevents package.')
        seafevents_api = None
else:
    class RPCProxy(object):
        def __getattr__(self, name):
            return partial(self.method_missing, name)
        def method_missing(self, name, *args, **kwargs):
            return None
    seafevents_api = RPCProxy()
```

If `EVENTS_CONFIG_FILE` is absent or `None`, Python goes to the `else` branch and creates an `RPCProxy` — a null object that silently returns `None` for any method call. No code patches needed.

### Finding 2 — EVENTS_CONFIG_FILE comes from seahub_settings.py

```python
try:
    from seahub.settings import EVENTS_CONFIG_FILE
except ImportError:
    EVENTS_CONFIG_FILE = None
```

If `seahub_settings.py` does not define `EVENTS_CONFIG_FILE`, it defaults to `None`. The entire seafevents block is skipped. This is deliberate upstream design.

### Finding 3 — `is_cluster_mode()` is the real unconditional env risk

```python
CLUSTER_MODE = is_cluster_mode()
```

Called unconditionally at module load. Reads `SEAFILE_CENTRAL_CONF_DIR` or `SEAFILE_DATA_DIR` from environment variables. If neither is set, crashes with `KeyError`. This is the real unconditional env dependency. The file can be empty or absent — only the env vars must be set.

**Why the file can be absent:** `is_cluster_mode()` uses Python's `configparser` to look for an `[cluster]` section in `seafile.conf`. `configparser.has_option()` silently returns `False` if the file doesn't exist, rather than raising. This is the mechanism that makes the empty `~/tengiswiki/build-workspace/fake-conf/` directory work for collectstatic — Django imports succeed, cluster mode defaults to off, and nothing further is required.

### Finding 4 — The runtime `seahub_settings.py` is only 3 lines

Discovered via `docker exec tengis-wiki cat /opt/seafile/conf/seahub_settings.py`:

```python
# -*- coding: utf-8 -*-
SECRET_KEY = "ba5bmfn((48ob*-*&shgs(7bagbtw#^f*bk%rzx&ovp#@w=4p0"

TIME_ZONE = 'Europe/Istanbul'
```

Django pulls all its defaults from `seahub/settings.py`. Over-specifying the stub risks accidentally overriding things the real settings.py defines correctly.

### Finding 5 — seafevents runs as a SEPARATE PROCESS in CE

Discovered via `docker exec tengis-wiki ps aux | grep seafevents`:

```
PID 142: python3 -m seafevents.main --config-file /opt/seafile/conf/seafevents.conf ...
```

Runs independent of Django. Combined with Finding 4 (no `EVENTS_CONFIG_FILE` in runtime `seahub_settings.py`), this confirms the build-time RPCProxy behavior IS the runtime behavior.

**What seafevents actually does in CE:** The standalone process handles background event work — email notifications, statistics, file history — reading its own `seafevents.conf` directly. Django never talks to it in CE. The seafevents-dependent Django views (Pro-only features like activity reports, event statistics) all return `None` silently via the RPCProxy null-object pattern, which is the correct behavior for CE. There is **zero divergence between build-time and runtime** on the seafevents axis: both use RPCProxy. This is why omitting `EVENTS_CONFIG_FILE` from the build stub is safe, not a workaround.

### Finding 6 — Upstream's `seafile-build.py` does NOT run collectstatic

The `Seahub` class in the official build orchestrator has `build_commands = []`. No npm install. No collectstatic. Upstream only appends a `SEAFILE_VERSION` line to settings.py. The frontend build and collectstatic happen in a separate upstream CI pipeline.

**Source — verified directly from `https://raw.githubusercontent.com/haiwen/seafile-docker/master/build/seafile_13.0/seafile-build.py`:**

```python
class Seahub(Project):
    name = 'seahub'

    def __init__(self):
        Project.__init__(self)
        # nothing to do for seahub
        self.build_commands = []

    def build(self):
        self.write_version_to_settings_py()
        Project.build(self)

    def write_version_to_settings_py(self):
        settings_py = os.path.join(self.projdir, 'seahub', 'settings.py')
        line = '\nSEAFILE_VERSION = "%s"\n' % conf[CONF_VERSION]
        with open(settings_py, 'a+') as fp:
            fp.write(line)
```

`build_commands` is an empty list, `build()` only calls `write_version_to_settings_py()`, and that method only appends one line. This is exactly why our Option J flow mirrors upstream: do `npm run build` and `collectstatic` outside docker, then COPY the results in — same separation upstream uses between their dist pipeline and their docker pipeline.

### Finding 7 — Django wraps webpack hashes

The running container's `staticfiles.json` shows double-hashed paths:
```
"frontend/static/js/2405.f6d72ea3.chunk.js": "frontend/static/js/2405.f6d72ea3.chunk.d524003f1d7d.js"
```

The first hash is webpack's. The second is Django's `ManifestStaticFilesStorage`. Webpack hashes don't need to "match" anything — Django wraps them with its own post-processing hash.

### Finding 8 — collectstatic is the victim, not the cause

The Django import chain triggers when any Django management command runs, including `collectstatic`. The import of `seahub/utils/__init__.py` fires during startup. collectstatic itself does not cause the failure — the failure happens before collectstatic even starts.

### Finding 9 — captcha and other Django apps live in system Python (v1.2)

`captcha` is listed in `INSTALLED_APPS` but is NOT in `seahub/thirdpart/`. It lives in the container's system Python at `/usr/local/lib/python3.12/dist-packages/captcha/`. Fix: copy the entire `dist-packages` directory from the running container as `system-dist-packages/` and add it to `PYTHONPATH`. This catches captcha and any other system-installed Django apps in one shot.

### Finding 10 — DATABASES override IS required in build stub (v1.2)

v1.1 said "do not add DATABASES". This was wrong. Django loads the database backend during `INSTALLED_APPS` population, which happens during any management command including `collectstatic`. Without a DATABASES override, it tries to load MySQL (`MySQLdb`) which is not available on the VM. Fix: add a sqlite3 stub to `DATABASES`.

### Finding 11 — manage.py is at repo root, not inside seahub/ (v1.2)

The plan assumed `cd ~/tengiswiki/tengis-wiki-fr/seahub` to run `manage.py`. The actual location is `~/tengiswiki/tengis-wiki-fr/manage.py`. All `python3 manage.py` commands must be run from `~/tengiswiki/tengis-wiki-fr/`.

### Finding 12 — frontend/build/ output is nested (v1.2)

`npm run build` outputs to `frontend/build/frontend/` (nested), not `frontend/build/`. The Dockerfile COPY must use the nested path.

### Finding 13 — collectstatic media/assets/ lands at repo root (v1.2)

Because `manage.py` is at repo root, Django resolves `MEDIA_ROOT` relative to there. The output lands at `~/tengiswiki/tengis-wiki-fr/media/assets/`, not at `seahub/media/assets/`. The Dockerfile COPY source must use the repo-root path.

### Finding 14 — SEAFILE_VERSION is already present as '6.3.3' (v1.2)

The base repo already contains `SEAFILE_VERSION = '6.3.3'` in `seahub/settings.py`. The v1.1 plan used `grep -q || echo >>` (append if absent). Since the line IS present (wrong value), the append does nothing. Fix: use `sed` to replace the existing value.

**Robustness note:** The sed command below hardcodes `'6.3.3'`. A more future-proof version that replaces whatever value is present:

```bash
sed -i "s/SEAFILE_VERSION = '[^']*'/SEAFILE_VERSION = '13.0.21'/" \
  ~/tengiswiki/tengis-wiki-fr/seahub/settings.py
```

### Finding 15 — .dockerignore must be at the build context root (v1.4 NEW)

`tengis-wiki-docker/.dockerignore` exists adjacent to the Dockerfile. When `docker build -f tengis-wiki-docker/Dockerfile .` is run from `~/tengiswiki/`, Docker on this VM does NOT pick up the adjacent `.dockerignore`. It only checks the build context root (`~/tengiswiki/.dockerignore`). Since no such file exists, the entire `~/tengiswiki/` directory was sent as build context — including `node_modules` (1011 MB) and `build-workspace` (~1 GB). The build succeeded because nothing was excluded, but it was slow and sent ~3 GB of unnecessary data.

**For the next build:** Before running `docker build`, create `~/tengiswiki/.dockerignore` at the build context root. See Phase 5 for the correct content. The existing `tengis-wiki-docker/.dockerignore` is also missing the three critical exception lines for `frontend/build`, `webpack-stats.pro.json`, and `media/assets` — fix both.

### Finding 16 — Build artifacts must be in .gitignore before the first build (v1.4 NEW)

After `npm run build` and `collectstatic`, two files/dirs in `tengis-wiki-fr` become modified or untracked:

- `frontend/webpack-stats.pro.json` — regenerated by every `npm run build`; already tracked by git; must be untracked with `git rm --cached` and added to `.gitignore`
- `media/assets/` — 184 MB collectstatic output; was never tracked; must be added to `.gitignore`
- `seahub/settings.py` — SEAFILE_VERSION change is a real source change and should be committed, not ignored

Neither `webpack-stats.pro.json` nor `media/assets/` should ever be committed to the repo. They are reproducible build artifacts. The `.gitignore` additions were committed as `4399bc278`.

---

## 5. Strategic Decision (Unchanged)

**Strategy 3 — Hybrid (CHOSEN)**

Build a Tengis base image that handles everything requiring a custom image (React string, locale files, product identity). On top of that, use Seafile's official `custom/` bind-mount mechanism for per-customer branding.

---

## 6. Tactical Decision

**Primary path: Option J — Build collectstatic output on VM, COPY into image**

Upstream Seafile does NOT run collectstatic inside docker build. Their CE base image gets pre-built dist artifacts. Mirroring this pattern is the lowest-risk approach.

**Why this is the right shape, beyond "mirrors upstream":**

- **Normal Python environment.** Running on the VM means a real seaserv install, a real PYTHONPATH, real config dirs — no docker layering pretending to be a runtime.
- **Easy debugging if something fails.** A normal shell, normal stderr, normal `tail` on the log file. No need to keep rebuilding to inspect a failure that only shows up mid-build.
- **Reuses existing `node_modules`.** The VM already has `~/tengiswiki/tengis-wiki-fr/frontend/node_modules/` installed (~1011 MB). No re-install cost during builds.
- **Trivially simple Dockerfile.** Just `COPY` a pre-built `frontend/build/` and `media/assets/` into the image. No multi-stage, no complex environment variable injection at build time.

**The flow (proven in v1.2):**

1. `npm run build` in `frontend/` on VM
2. Set up env vars + build workspace on VM
3. `python3 manage.py collectstatic` from repo root on VM
4. Dockerfile COPYs pre-built `frontend/build/`, `webpack-stats.pro.json`, and `media/assets/` into the image
5. Build, deploy, verify

**Fallback path: Option D** — Multi-stage Dockerfile with collectstatic-in-build. Refer to `tengis-wiki-build-plan-v1_0.md`.

---

## 7. The Build Environment Contract

### Build-time stub `seahub_settings.py` (FINAL)

```python
# -*- coding: utf-8 -*-
# BUILD-TIME STUB ONLY — used exclusively for collectstatic on the VM.
# This file is NOT the runtime settings file.
SECRET_KEY = 'tengis-build-stub-key-not-used-in-production'
TIME_ZONE = 'UTC'
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': '/tmp/tengis-build-stub.db',
    }
}
```

**Why DATABASES is required:** Django loads the DB backend during `INSTALLED_APPS` population, which fires during any management command including `collectstatic`. Without this, it tries to load MySQLdb which is not installed on the VM. sqlite3 is always available in Python's standard library.

**Do NOT add:**
- `INSTALLED_APPS` (would override the real settings.py's list)
- `CACHES` (not needed for collectstatic)
- `STATIC_ROOT`, `MEDIA_ROOT`, `STATIC_URL`, `MEDIA_URL` (real settings.py has them)
- `EVENTS_CONFIG_FILE` (omitting it triggers RPCProxy, which is what CE runtime uses)
- `JWT_PRIVATE_KEY` (not needed at build time)

### Required environment variables for collectstatic

```bash
export SEAFILE_CENTRAL_CONF_DIR=~/tengiswiki/build-workspace/fake-conf
export SEAFILE_DATA_DIR=~/tengiswiki/build-workspace/fake-data

export PYTHONPATH=~/tengiswiki/build-workspace/site-packages-seafile:\
~/tengiswiki/tengis-wiki-fr/seahub:\
~/tengiswiki/build-workspace/seahub-thirdpart:\
~/tengiswiki/build-workspace/system-dist-packages:\
~/tengiswiki/build-workspace/build-conf

# Optional
export SEAFILE_RPC_PIPE_PATH=~/tengiswiki/build-workspace/fake-conf
```

---

## 8. The Full Phased Plan (Option J — Proven in v1.2, verified in v1.4)

### Pre-session checklist (before starting anything)

- [ ] Confirm VM is reachable: `ssh akin@192.168.2.111`
- [ ] Confirm running stack is healthy: `docker ps` — all three containers must be Up
- [ ] Confirm repo state on VM: `cd ~/tengiswiki/tengis-wiki-fr && git log --oneline -3 && git status`
- [ ] Confirm node_modules exist: `ls -lh ~/tengiswiki/tengis-wiki-fr/frontend/node_modules | head -5`
- [ ] Back up compose file: `cp /opt/tengis/seafile-server.yml /opt/tengis/seafile-server.yml.bak.$(date +%Y%m%d)`

---

### Phase 0 — Commit loose ends (15 minutes)

#### Task 0.1 — Commit the .mo locale files (VM)

```bash
cd ~/tengiswiki/tengis-wiki-fr
git add locale/
git commit -m "Add compiled Turkish and Indonesian locale files"
git log --oneline -3
```

**Checkpoint:** Clean working tree after commit.

#### Task 0.2 — Discard incorrect Dockerfile drafts (Mac)

```bash
cd ~/tengiswiki/tengis-wiki-docker
git checkout -- Dockerfile .dockerignore
git status
```

#### Task 0.3 — Sync VM docker repo (VM)

```bash
cd ~/tengiswiki/tengis-wiki-docker
git pull
git log --oneline -3
```

---

### Phase 1 — React build (20 minutes)

#### Task 1.0 — Confirm VM toolchain (VM, one-time setup)

If this is a fresh VM, install Node.js 20 plus the native build dependencies before running `npm install` or `npm run build`. This was a one-time setup on the current VM; skip if `node --version` already reports v20.x.

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs build-essential python3
node --version    # expect v20.x
npm --version
gcc --version | head -1
```

**Why `build-essential` and `python3`:** Some npm packages in Seahub's `frontend/` tree compile native C code during `npm install` (typically `node-gyp` doing addon builds). Without `gcc`, `make`, and headers from `build-essential`, those packages fail to install with errors that look like missing modules. `python3` is required because `node-gyp` invokes it for build script generation. The VM already has these installed; the snippet is here for fresh-VM scenarios and future image-rebuilds on new hardware.

#### Task 1.1 — Run the React build (VM)

```bash
cd ~/tengiswiki/tengis-wiki-fr/frontend
NODE_OPTIONS=--max-old-space-size=4096 npm run build 2>&1 | tail -20
```

**Checkpoint:** Build completes. Last lines mention bundle sizes. No errors.

#### Task 1.2 — Confirm actual output paths (VM)

```bash
find ~/tengiswiki/tengis-wiki-fr/frontend/build -maxdepth 3 -type d
find ~/tengiswiki/tengis-wiki-fr/frontend -name 'webpack-stats*.json'
du -sh ~/tengiswiki/tengis-wiki-fr/frontend/build/
```

**Expected (confirmed in v1.2):**
- Build output is nested: `frontend/build/frontend/static/js/` and `css/`
- `webpack-stats.pro.json` is at `frontend/webpack-stats.pro.json`
- Build size ~92M

#### Task 1.3 — Confirm info.js string compiled correctly (VM)

```bash
grep -rl "Tengis Wiki" ~/tengiswiki/tengis-wiki-fr/frontend/build/ | head -5
grep -rl "Community Edition" ~/tengiswiki/tengis-wiki-fr/frontend/build/ | head -5
```

**Checkpoint:** "Tengis Wiki" in `app`, `orgAdmin`, `sysAdmin` chunks. "Community Edition" not found.

---

### Phase 2 — Build environment preparation on VM (45 minutes)

#### Task 2.1 — Create build workspace (VM)

```bash
mkdir -p ~/tengiswiki/build-workspace
```

#### Task 2.2 — Copy seafile Python libs from running container (VM)

```bash
docker cp tengis-wiki:/opt/seafile/seafile-server-13.0.21/seafile/lib/python3/site-packages \
  ~/tengiswiki/build-workspace/site-packages-seafile

docker cp tengis-wiki:/opt/seafile/seafile-server-13.0.21/seahub/thirdpart \
  ~/tengiswiki/build-workspace/seahub-thirdpart

ls ~/tengiswiki/build-workspace/site-packages-seafile/seaserv/
ls ~/tengiswiki/build-workspace/seahub-thirdpart/django/ 2>/dev/null | head -5
```

**Checkpoint:** `seaserv/` and `django/` directories both exist.

#### Task 2.3 — Copy system dist-packages from running container (VM)

```bash
docker cp tengis-wiki:/usr/local/lib/python3.12/dist-packages \
  ~/tengiswiki/build-workspace/system-dist-packages

ls ~/tengiswiki/build-workspace/system-dist-packages/ | grep -i captcha
```

**Checkpoint:** `captcha` directory exists. Copy size ~449MB.

#### Task 2.4 — Fix SEAFILE_VERSION in settings.py (VM)

```bash
grep "SEAFILE_VERSION" ~/tengiswiki/tengis-wiki-fr/seahub/settings.py

sed -i "s/SEAFILE_VERSION = '[^']*'/SEAFILE_VERSION = '13.0.21'/" \
  ~/tengiswiki/tengis-wiki-fr/seahub/settings.py

grep "SEAFILE_VERSION" ~/tengiswiki/tengis-wiki-fr/seahub/settings.py
```

**Checkpoint:** Shows `SEAFILE_VERSION = '13.0.21'`.

#### Task 2.5 — Create the build-time stub seahub_settings.py (VM)

```bash
mkdir -p ~/tengiswiki/build-workspace/build-conf
cat > ~/tengiswiki/build-workspace/build-conf/seahub_settings.py << 'EOF'
# -*- coding: utf-8 -*-
# BUILD-TIME STUB ONLY — used exclusively for collectstatic on the VM.
# This file is NOT the runtime settings file.
SECRET_KEY = 'tengis-build-stub-key-not-used-in-production'
TIME_ZONE = 'UTC'
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': '/tmp/tengis-build-stub.db',
    }
}
EOF
cat ~/tengiswiki/build-workspace/build-conf/seahub_settings.py
```

**Checkpoint:** File matches exactly what is shown above.

#### Task 2.6 — Create fake config dirs (VM)

```bash
mkdir -p ~/tengiswiki/build-workspace/fake-conf
mkdir -p ~/tengiswiki/build-workspace/fake-data
touch ~/tengiswiki/build-workspace/fake-conf/seafile.conf
```

#### Task 2.7 — Dry-run collectstatic (VM)

```bash
cd ~/tengiswiki/tengis-wiki-fr

export SEAFILE_CENTRAL_CONF_DIR=~/tengiswiki/build-workspace/fake-conf
export SEAFILE_DATA_DIR=~/tengiswiki/build-workspace/fake-data
export PYTHONPATH=~/tengiswiki/build-workspace/site-packages-seafile:~/tengiswiki/tengis-wiki-fr/seahub:~/tengiswiki/build-workspace/seahub-thirdpart:~/tengiswiki/build-workspace/system-dist-packages:~/tengiswiki/build-workspace/build-conf

python3 manage.py collectstatic --dry-run --noinput 2>&1 | tail -30
```

**Checkpoint:** Output shows "Pretending to copy" lines. Last line: `X static files copied to '...media/assets'`. No errors.

**Troubleshooting table:**

| Error | Cause | Fix |
|---|---|---|
| `ModuleNotFoundError: seaserv` | PYTHONPATH wrong | Verify `site-packages-seafile/seaserv/` exists |
| `ImportError: SEAFILE_CONF_DIR undefined` | Env var missing | Re-export `SEAFILE_CENTRAL_CONF_DIR` and `SEAFILE_DATA_DIR` |
| `ModuleNotFoundError: seahub_settings` | Stub not on PYTHONPATH | Verify `build-conf` is in PYTHONPATH |
| `ModuleNotFoundError: captcha` | system-dist-packages missing | Verify Task 2.3 completed and path is in PYTHONPATH |
| `ImproperlyConfigured: Error loading MySQLdb` | DATABASES not in stub | Verify stub has the sqlite3 DATABASES block |
| `AttributeError: NoneType init_db_session_class` | EVENTS_CONFIG_FILE accidentally set | Remove it from stub |
| `python3: can't open file manage.py` | Wrong directory | `cd ~/tengiswiki/tengis-wiki-fr` (repo root) |

**Time-box:** Allow 3 attempts. If dry-run still fails after 3 tries, switch to Option D fallback.

---

### Phase 3 — Run real collectstatic on VM (15 minutes)

#### Task 3.1 — Backup any existing media/assets/ (VM)

```bash
ls ~/tengiswiki/tengis-wiki-fr/media/assets/ 2>/dev/null \
  && mv ~/tengiswiki/tengis-wiki-fr/media/assets \
        ~/tengiswiki/tengis-wiki-fr/media/assets.before-collectstatic-bak \
  || echo "clean slate"
```

#### Task 3.2 — Run real collectstatic (VM)

```bash
cd ~/tengiswiki/tengis-wiki-fr

export SEAFILE_CENTRAL_CONF_DIR=~/tengiswiki/build-workspace/fake-conf
export SEAFILE_DATA_DIR=~/tengiswiki/build-workspace/fake-data
export PYTHONPATH=~/tengiswiki/build-workspace/site-packages-seafile:~/tengiswiki/tengis-wiki-fr/seahub:~/tengiswiki/build-workspace/seahub-thirdpart:~/tengiswiki/build-workspace/system-dist-packages:~/tengiswiki/build-workspace/build-conf

python3 manage.py collectstatic --noinput --clear 2>&1 | tee /tmp/collectstatic-output.log | tail -5
```

**Checkpoint:** Last line: "X static files copied to ...". X was 367 in v1.2.

#### Task 3.3 — Verify the output (VM)

```bash
ls ~/tengiswiki/tengis-wiki-fr/media/assets/
du -sh ~/tengiswiki/tengis-wiki-fr/media/assets/
grep -rl "Tengis Wiki" ~/tengiswiki/tengis-wiki-fr/media/assets/frontend/static/js/ | head -3
```

**Checkpoint:** `frontend/  scripts/  staticfiles.json  termsandconditions`. Size ~184M. "Tengis Wiki" in at least one JS file.

---

### Phase 4 — Write the Dockerfile (30 minutes)

#### Task 4.1 — Write the Dockerfile (Mac)

```bash
cat > ~/tengiswiki/tengis-wiki-docker/Dockerfile << 'EOF'
FROM seafileltd/seafile-mc:13.0-latest

ARG SEAFILE_VERSION=13.0.21

COPY tengis-wiki-fr/media/css/             /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/media/css/
COPY tengis-wiki-fr/media/img/             /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/media/img/
COPY tengis-wiki-fr/media/favicons/        /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/media/favicons/
COPY tengis-wiki-fr/seahub/templates/      /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/seahub/templates/
COPY tengis-wiki-fr/seahub/help/templates/ /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/seahub/help/templates/
COPY tengis-wiki-fr/locale/                /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/locale/

COPY tengis-wiki-fr/frontend/build/                  /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/frontend/build/
COPY tengis-wiki-fr/frontend/webpack-stats.pro.json  /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/frontend/webpack-stats.pro.json
COPY tengis-wiki-fr/media/assets/                    /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/media/assets/

RUN find /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
EOF
cat ~/tengiswiki/tengis-wiki-docker/Dockerfile
```

**Path notes:**
- `media/assets/` source is `tengis-wiki-fr/media/assets/` (repo root, NOT `seahub/media/assets/`)
- `frontend/build/` COPY copies directory contents so `build/frontend/` lands correctly at `seahub/frontend/build/frontend/`

#### Task 4.2 — Create root-level .dockerignore (VM) — v1.4 REQUIRED

> **v1.4 finding:** Docker on this VM does NOT pick up `.dockerignore` adjacent to the Dockerfile. It only reads from the build context root (`~/tengiswiki/`). A root-level `.dockerignore` must be created before running `docker build`. Without it, the full `~/tengiswiki/` (~3 GB including `node_modules` and `build-workspace`) is sent to the daemon.

```bash
cat > ~/tengiswiki/.dockerignore << 'EOF'
# Build workspace — never goes into image context
build-workspace

# node_modules — very large, not needed for image
tengis-wiki-fr/frontend/node_modules

# Git history
tengis-wiki-fr/.git
tengis-wiki-docker/.git

# Exclude seahub app source not needed for overlay
tengis-wiki-fr/seahub
!tengis-wiki-fr/seahub/templates
!tengis-wiki-fr/seahub/help

# Exclude media in bulk — re-include only the three overlay subdirs + assets
tengis-wiki-fr/media
!tengis-wiki-fr/media/css
!tengis-wiki-fr/media/img
!tengis-wiki-fr/media/favicons
!tengis-wiki-fr/media/assets

# Exclude frontend source — re-include only compiled output
tengis-wiki-fr/frontend
!tengis-wiki-fr/frontend/build
!tengis-wiki-fr/frontend/webpack-stats.pro.json
EOF
cat ~/tengiswiki/.dockerignore
```

**Checkpoint:** All three `!` re-include lines for `frontend/build`, `webpack-stats.pro.json`, and `media/assets` are present.

#### Task 4.3 — Sync Dockerfile to VM (Mac then VM)

On **Mac**:
```bash
cd ~/tengiswiki/tengis-wiki-docker
git add Dockerfile
git commit -m "WIP: update Dockerfile for Option J build (pre-build commit)"
git push
```

On **VM**:
```bash
cd ~/tengiswiki/tengis-wiki-docker
git pull
cat Dockerfile | head -5
```

---

### Phase 5 — Build the image (15 minutes)

#### Task 5.1 — Build (VM)

```bash
cd ~/tengiswiki
docker build \
  -f tengis-wiki-docker/Dockerfile \
  --build-arg SEAFILE_VERSION=13.0.21 \
  -t tengis/tengis-wiki:13.0.21-r2 \
  . 2>&1 | tee /tmp/build.log | tail -20
```

**Checkpoint 5.1a:** Exit code 0.
**Checkpoint 5.1b:** `docker images | grep tengis` shows `13.0.21-r2`.

#### Task 5.2 — Inspect the new image (VM)

```bash
docker images | grep tengis-wiki

docker run --rm tengis/tengis-wiki:13.0.21-r2 \
  du -sh /opt/seafile/seafile-server-13.0.21/seahub/media/assets/

docker run --rm tengis/tengis-wiki:13.0.21-r2 \
  grep -rl "Tengis Wiki" /opt/seafile/seafile-server-13.0.21/seahub/media/assets/frontend/static/js/ | head -3
```

> **Note:** Do NOT use `*.js` glob in `grep` inside `docker run` — the glob does not expand in the container. Use the directory path directly.

**Checkpoint:** Size ~333M inside image. "Tengis Wiki" found in at least one JS file.

---

### Phase 6 — Deploy and verify (30 minutes)

#### Task 6.1 — Update compose file (VM)

```bash
cp /opt/tengis/seafile-server.yml /opt/tengis/seafile-server.yml.bak.pre-r2
sed -i 's|tengis/tengis-wiki:13.0.21|tengis/tengis-wiki:13.0.21-r2|g' /opt/tengis/seafile-server.yml
grep "tengis/tengis-wiki" /opt/tengis/seafile-server.yml
```

#### Task 6.2 — Restart the stack (VM)

```bash
cd /opt/tengis
docker compose down
docker compose up -d
sleep 30
docker ps
docker logs tengis-wiki --tail 20
```

**Checkpoint:** All three containers Up and healthy. No errors in logs.

#### Task 6.3 — Browser verification

The first six items verify cosmetic rebranding. **The last three items verify that the build-time RPCProxy isolation did not break runtime seafevents integration** — these are the operationally critical checks. A green build that fails on file history or search means the stub was over-suppressive and the image is unusable in production despite looking correct.

| Check | Expected | Validates |
|---|---|---|
| Login page | Tengis branding, no Seafile | Branding overlay |
| Browser tab title | Tengis Wiki (after admin sets `SITE_TITLE`) | Settings round-trip |
| Logo | Tengis logo | Image overlay |
| Primary color | Tengis Blue `#4A4EC7` | CSS overlay |
| **Admin → System Info** | **"Tengis Wiki" NOT "Community Edition"** ← primary goal | React `info.js` baked into `media/assets/` |
| File upload/download | Works | Core Seahub + fileserver |
| **File history** | Shows previous file versions | **seafevents** — was the build-time RPCProxy correctly replaced at runtime? |
| **Search** | Returns results across libraries | **seafevents** indexing |
| Turkish locale | Switch and verify UI strings change | `.mo` files in image |

#### Task 6.4 — Rollback procedure (if needed)

```bash
cd /opt/tengis
docker compose down
cp /opt/tengis/seafile-server.yml.bak.pre-r2 /opt/tengis/seafile-server.yml
docker compose up -d
docker ps
```

---

### Phase 7 — Commit and tag (v1.4 CORRECTED — 7 tasks, not 2)

> **v1.3 had only 2 tasks and left three issues unresolved.** v1.4 expands Phase 7 to cover everything needed for a truly clean close.

#### Task 7.1 — Push tengis-wiki-fr .mo commit (VM)

```bash
cd ~/tengiswiki/tengis-wiki-fr
git push
git log --oneline -3
```

**Checkpoint:** Origin now has the .mo commit.

#### Task 7.2 — Amend the WIP Dockerfile commit and force-push (Mac)

```bash
cd ~/tengiswiki/tengis-wiki-docker
git commit --amend -m "Use pre-built frontend + collectstatic output (Option J)

The seahub directory is now built externally on the VM:
  1. npm run build in frontend/ — output is nested at frontend/build/frontend/
  2. python3 manage.py collectstatic from repo root with env vars and
     stub seahub_settings.py (3 lines + sqlite3 DATABASES override)
     documented in tengis-wiki-build-plan-v1_4.md
  3. Dockerfile COPYs frontend/build/, webpack-stats.pro.json,
     and media/assets/ (at repo root) into the image

Key corrections from v1.1 plan:
  - manage.py is at repo root, not inside seahub/
  - SEAFILE_VERSION must be sed-replaced (was 6.3.3 in base repo)
  - system-dist-packages required in PYTHONPATH (captcha etc)
  - DATABASES sqlite3 stub required (Django loads DB backend at init)
  - media/assets/ lands at repo root, not seahub/media/assets/

Resolves: Community Edition string in System Info admin page."
git push --force
```

#### Task 7.3 — Sync VM docker repo after force push (VM)

> **v1.4 required:** Force push rewrites history on origin. VM must hard-reset, not just pull.

```bash
cd ~/tengiswiki/tengis-wiki-docker
git fetch
git reset --hard origin/master
git log --oneline -3
```

**Checkpoint:** VM shows the amended commit hash (same as Mac).

#### Task 7.4 — Sync Mac tengis-wiki-fr (Mac)

```bash
cd ~/tengiswiki/tengis-wiki-fr
git pull
git log --oneline -3
```

#### Task 7.5 — Commit build artifacts cleanup (VM)

> **v1.4 required:** After Phase 1 and Phase 3, `tengis-wiki-fr` has uncommitted changes. These must be handled before the repos can be called clean.

```bash
cd ~/tengiswiki/tengis-wiki-fr

# Add build artifacts to .gitignore
cat >> .gitignore << 'EOF'

# Build artifacts — generated by npm run build and collectstatic
frontend/webpack-stats.pro.json
media/assets/
EOF

# Untrack webpack-stats.pro.json (it was already tracked by git)
git rm --cached frontend/webpack-stats.pro.json

# Stage .gitignore and seahub/settings.py (SEAFILE_VERSION change)
git add .gitignore seahub/settings.py
git status
```

**Checkpoint:** Three changes staged: `.gitignore` modified, `webpack-stats.pro.json` deleted (untracked), `seahub/settings.py` modified. `media/assets/` not visible (correctly ignored).

#### Task 7.6 — Push the cleanup commit (VM)

```bash
cd ~/tengiswiki/tengis-wiki-fr
git commit -m "build: update settings version, gitignore build artifacts

- seahub/settings.py: update SEAFILE_VERSION 6.3.3 → 13.0.21
- .gitignore: add frontend/webpack-stats.pro.json and media/assets/
- untrack webpack-stats.pro.json (build artifact from npm run build)"
git push
git log --oneline -3
```

#### Task 7.7 — Final sync on Mac (Mac)

```bash
cd ~/tengiswiki/tengis-wiki-fr
git pull
git log --oneline -3
```

#### Task 7.8 — Final state verification (both)

On **VM**:
```bash
cd ~/tengiswiki/tengis-wiki-fr && git log --oneline -3 && git status
echo "---"
cd ~/tengiswiki/tengis-wiki-docker && git log --oneline -3 && git status
```

On **Mac**:
```bash
cd ~/tengiswiki/tengis-wiki-fr && git log --oneline -3
echo "---"
cd ~/tengiswiki/tengis-wiki-docker && git log --oneline -3
```

**Checkpoint:** All four repos (tengis-wiki-fr Mac/VM, tengis-wiki-docker Mac/VM) at matching commits, `nothing to commit, working tree clean`.

---

## 9. Phase 8 — Fallback to Option D (if Option J fails)

### 9.1 When to use this

Only execute Option D if Phase 2 or Phase 3 of Option J fails irrecoverably. "Irrecoverably" means the VM's Python environment is broken in ways that can't be fixed by reinstalling dependencies — at that point, isolating the build inside a clean Docker stage may be the only path forward. In every test build to date, Option J has succeeded; Option D is a contingency that has not been executed in practice.

### 9.2 Required corrections to v1.0's original Option D recipe

The original planning document (v1.0, now absorbed into this section) was written before any actual build was attempted. With the 16 findings from v1.2 and v1.4 execution, four corrections are mandatory for any Option D attempt:

1. **Stub must be 6 lines including `DATABASES`** — not 3 lines (Finding 10). Django loads the DB backend during `apps.populate()` even for collectstatic. The sqlite3 stub is required.
2. **PYTHONPATH must include `system-dist-packages` equivalent** (Finding 9). `captcha` and other Django apps live in the container's system Python at `/usr/local/lib/python3.12/dist-packages`, not just in the seafile virtualenv.
3. **All `manage.py` calls must `cd` to repo root inside the build stage** (Finding 11) — `manage.py` is at `/opt/seafile/seafile-server-13.0.21/seahub/`, not in a `seahub/seahub/` subdirectory.
4. **COPY paths for `media/assets/` are at repo root, not `seahub/media/assets/`** (Finding 13). collectstatic's `STATIC_ROOT` lands directly at `<repo>/media/assets/`.

### 9.3 Multi-stage Dockerfile structure

The shape below incorporates the four corrections above. Path placeholders marked `<...>` should be filled in based on what `npm run build` actually produces inside the Node stage (verify with `RUN ls -la build/` between stages, or build the Node stage standalone first).

```dockerfile
# ============================================================
# Stage 1: Node build
# ============================================================
FROM node:20-bullseye AS frontend-builder

WORKDIR /build
COPY tengis-wiki-fr/frontend/package.json tengis-wiki-fr/frontend/package-lock.json ./
RUN npm install
COPY tengis-wiki-fr/frontend/ ./
RUN NODE_OPTIONS=--max-old-space-size=4096 npm run build

# ============================================================
# Stage 2: Seafile base + collectstatic
# ============================================================
FROM seafileltd/seafile-mc:13.0-latest AS collectstatic-builder

# Environment variables required for Django to load in build context.
# SEAFILE_CENTRAL_CONF_DIR and SEAFILE_DATA_DIR prevent is_cluster_mode() from failing.
ENV SEAFILE_CENTRAL_CONF_DIR=/opt/seafile/conf
ENV SEAFILE_DATA_DIR=/opt/seafile/seafile-data

# Empty directories — paths must exist, contents not needed at build time.
RUN mkdir -p /opt/seafile/conf /opt/seafile/seafile-data

# Build-time stub seahub_settings.py — see §7 for the exact 6-line content.
# CRITICAL: must include DATABASES (Finding 10); must NOT include EVENTS_CONFIG_FILE.
COPY build-context/seahub_settings_build.py /opt/seafile/conf/seahub_settings.py

# Copy React build output from Stage 1.
# Verify the actual output path inside the Node stage before fixing this COPY.
COPY --from=frontend-builder /build/build/ \
     /opt/seafile/seafile-server-13.0.21/seahub/frontend/build/
COPY --from=frontend-builder /build/webpack-stats.pro.json \
     /opt/seafile/seafile-server-13.0.21/seahub/frontend/webpack-stats.pro.json

# Copy Tengis rebrand overlays (logos, CSS, templates, locales).
# Full list mirrors Phase 4 Task 4.1 — see the single-stage Option J Dockerfile.
COPY tengis-wiki-fr/media/                    /opt/seafile/seafile-server-13.0.21/seahub/media/
COPY tengis-wiki-fr/seahub/templates/         /opt/seafile/seafile-server-13.0.21/seahub/seahub/templates/
COPY tengis-wiki-fr/seahub/help/templates/    /opt/seafile/seafile-server-13.0.21/seahub/seahub/help/templates/
COPY tengis-wiki-fr/locale/                   /opt/seafile/seafile-server-13.0.21/seahub/locale/

# Fix SEAFILE_VERSION inside seahub/settings.py (Finding 14 — pre-existing '6.3.3' must be replaced).
RUN sed -i "s/SEAFILE_VERSION = '[^']*'/SEAFILE_VERSION = '13.0.21'/" \
    /opt/seafile/seafile-server-13.0.21/seahub/seahub/settings.py

# PYTHONPATH — five entries including system-dist-packages (Finding 9).
ENV PYTHONPATH=/opt/seafile/seafile-server-13.0.21/seafile/lib/python3/site-packages:\
/opt/seafile/seafile-server-13.0.21/seafile/lib64/python3/site-packages:\
/opt/seafile/seafile-server-13.0.21/seahub:\
/opt/seafile/seafile-server-13.0.21/seahub/thirdpart:\
/usr/local/lib/python3.12/dist-packages:\
/opt/seafile/conf

# Run collectstatic — cd to repo root, NOT seahub/seahub/ (Finding 11).
WORKDIR /opt/seafile/seafile-server-13.0.21/seahub
RUN python3 manage.py collectstatic --noinput --clear

# ============================================================
# Stage 3: Final image
# ============================================================
FROM seafileltd/seafile-mc:13.0-latest

# Copy the collectstatic output — note media/assets/ lives at REPO ROOT (Finding 13),
# not at seahub/media/assets/.
COPY --from=collectstatic-builder \
     /opt/seafile/seafile-server-13.0.21/seahub/media/assets/ \
     /opt/seafile/seafile-server-13.0.21/seahub/media/assets/

# Copy all the other overlays directly from local context (faster than transiting Stage 2).
COPY tengis-wiki-fr/media/                    /opt/seafile/seafile-server-13.0.21/seahub/media/
COPY tengis-wiki-fr/seahub/templates/         /opt/seafile/seafile-server-13.0.21/seahub/seahub/templates/
COPY tengis-wiki-fr/seahub/help/templates/    /opt/seafile/seafile-server-13.0.21/seahub/seahub/help/templates/
COPY tengis-wiki-fr/locale/                   /opt/seafile/seafile-server-13.0.21/seahub/locale/

# Remove the stub — runtime entrypoint generates the real seahub_settings.py.
RUN rm -f /opt/seafile/conf/seahub_settings.py
```

**Note on `.dockerignore`:** The same rule from Finding 15 applies — the `.dockerignore` file must live at the build context root (`~/tengiswiki/`), not adjacent to the Dockerfile.

### 9.4 Build failure decision table

If `docker build` fails during Stage 2 (collectstatic), map the error to the table below and fix one thing at a time. Do not guess — read the exact error, find its row, apply the fix, rebuild.

| Error | Cause | Fix |
|---|---|---|
| `ModuleNotFoundError: seahub_settings` | Stub not in PYTHONPATH | Verify `/opt/seafile/conf` is in PYTHONPATH ENV |
| `AttributeError: NoneType init_db_session_class` | `EVENTS_CONFIG_FILE` somehow set in stub | Check stub — remove it (Finding 1) |
| `KeyError: SEAFILE_CENTRAL_CONF_DIR` | ENV set after mkdir or RUN | Move ENV directives before any RUN/mkdir |
| `ModuleNotFoundError: seaserv` | PYTHONPATH missing seaserv path | Verify all five PYTHONPATH entries from §9.3 are present |
| `ModuleNotFoundError: captcha` | PYTHONPATH missing system-dist-packages | Add `/usr/local/lib/python3.12/dist-packages` (Finding 9) |
| `django.core.exceptions.ImproperlyConfigured` | Stub missing required key (usually DATABASES) | Verify stub matches §7 — 6 lines with sqlite3 DATABASES |
| `TemplateDoesNotExist` during collectstatic | INSTALLED_APPS reference missing template | Don't add INSTALLED_APPS to stub — let Django use the real one from `seahub/settings.py` |
| `Cannot find file '.../seahub/manage.py'` | WORKDIR wrong | Set `WORKDIR /opt/seafile/seafile-server-13.0.21/seahub` (Finding 11) |
| Any other error | Unmapped | Read the full traceback, identify the failing import, search v1.6 §4 for the matching finding |

**Time-box:** Allow 3 build attempts (~30 minutes total) for the dry-run with `collectstatic --dry-run`. If still failing after 3 attempts, stop and re-read the error carefully — repeated failures usually indicate a wrong assumption, not a missing setting.

### 9.5 Rollback procedure

If the Option D build succeeds but the resulting image misbehaves at runtime (Phase 6 Task 6.3 checks fail, especially file history or search), roll back to the last known good image:

```bash
cd /opt/tengis

# Stop the broken stack
docker compose down

# Restore the previous compose file (the .bak was written before the image tag was bumped)
cp /opt/tengis/seafile-server.yml.bak.pre-r2 /opt/tengis/seafile-server.yml

# Start with the previous image — it is still in the local registry
docker compose up -d
docker ps
```

The previous image (e.g., `tengis/tengis-wiki:13.0.21`) is **not removed** when a new tag is built. It stays in the local Docker registry indefinitely — verify with `docker images | grep tengis` before relying on this rollback. If you have manually run `docker image prune` since the last build, the rollback target may have been deleted; in that case you must rebuild the old version from its commit before rollback is possible.

---

## 10. Key Reference — Environment Variables

```bash
# Required for collectstatic to run on VM
export SEAFILE_CENTRAL_CONF_DIR=~/tengiswiki/build-workspace/fake-conf
export SEAFILE_DATA_DIR=~/tengiswiki/build-workspace/fake-data

# PYTHONPATH — all five entries required
export PYTHONPATH=\
~/tengiswiki/build-workspace/site-packages-seafile:\
~/tengiswiki/tengis-wiki-fr/seahub:\
~/tengiswiki/build-workspace/seahub-thirdpart:\
~/tengiswiki/build-workspace/system-dist-packages:\
~/tengiswiki/build-workspace/build-conf

# Optional
export SEAFILE_RPC_PIPE_PATH=~/tengiswiki/build-workspace/fake-conf
```

---

## 11. Key Reference — File Paths

```
Inside running container:
  /opt/seafile/seafile-server-13.0.21/seahub/                   Seahub Django source
  /opt/seafile/seafile-server-13.0.21/seahub/media/assets/      Static files (~333M uncompressed, nginx serves this)
  /opt/seafile/seafile-server-13.0.21/seahub/frontend/          React source and build output
  /opt/seafile/conf/seahub_settings.py                          Runtime Django settings (3 lines only)
  /opt/seafile/seafile-server-13.0.21/seafile/lib/python3/site-packages/seaserv/
  /usr/local/lib/python3.12/dist-packages/                      System Python — captcha and other Django apps

On VM (Option J workspace):
  ~/tengiswiki/tengis-wiki-fr/                                   Seahub rebrand repo
  ~/tengiswiki/tengis-wiki-fr/manage.py                         Django manage.py — REPO ROOT (not inside seahub/)
  ~/tengiswiki/tengis-wiki-fr/seahub/settings.py                SEAFILE_VERSION = '13.0.21' committed at 4399bc278
  ~/tengiswiki/tengis-wiki-fr/frontend/                         React source
  ~/tengiswiki/tengis-wiki-fr/frontend/node_modules/            ~1011 MB, 1210 entries
  ~/tengiswiki/tengis-wiki-fr/frontend/build/                   npm run build output (gitignored via webpack-stats)
  ~/tengiswiki/tengis-wiki-fr/frontend/build/frontend/          Nested JS/CSS output (v1.2 confirmed)
  ~/tengiswiki/tengis-wiki-fr/frontend/webpack-stats.pro.json   gitignored — untracked at 4399bc278
  ~/tengiswiki/tengis-wiki-fr/media/assets/                     collectstatic output — REPO ROOT, gitignored
  ~/tengiswiki/tengiswiki-fr/.gitignore                         Includes: frontend/webpack-stats.pro.json, media/assets/
  ~/tengiswiki/build-workspace/site-packages-seafile/           Copied from container — seaserv
  ~/tengiswiki/build-workspace/seahub-thirdpart/                Copied from container — Django thirdpart
  ~/tengiswiki/build-workspace/system-dist-packages/            Copied from container — system Python (~449MB)
  ~/tengiswiki/build-workspace/build-conf/seahub_settings.py    Build-time stub (3 lines + sqlite3 DATABASES)
  ~/tengiswiki/build-workspace/fake-conf/                       Empty dir for SEAFILE_CENTRAL_CONF_DIR
  ~/tengiswiki/build-workspace/fake-data/                       Empty dir for SEAFILE_DATA_DIR
  ~/tengiswiki/.dockerignore                                    ROOT-LEVEL — must exist before docker build (v1.4)
  ~/tengiswiki/tengis-wiki-docker/                              Docker repo
  /opt/tengis/seafile-server.yml                                Active compose file (NOT in git)
  /opt/tengis/.env                                              Compose environment variables
```

---

## 12. Summary Decision Record

| Question | v1.0 | v1.1 | v1.2 | v1.4 | Reason |
|---|---|---|---|---|---|
| Primary tactical option | Option D | Option J | Executed, succeeded | Same | — |
| Stub size | ~15 lines | 3 lines | 3 lines + DATABASES | Same | — |
| Define DATABASES in stub? | sqlite3 | Not at all | Yes — sqlite3 | Same | Django loads DB backend during apps.populate() |
| system-dist-packages needed? | N/A | N/A | Yes | Same | captcha not in thirdpart |
| manage.py location | assumed seahub/ | assumed seahub/ | repo root | Same | — |
| frontend/build/ path | unknown | unknown | nested build/frontend/ | Same | — |
| media/assets/ path | seahub/media/ | seahub/media/ | repo root media/ | Same | — |
| SEAFILE_VERSION handling | append | append | sed replace | Same | Was already 6.3.3 |
| .dockerignore placement | N/A | N/A | adjacent to Dockerfile | **root context required** | Docker on this VM ignores adjacent .dockerignore |
| Build artifacts in .gitignore? | N/A | N/A | not addressed | **Required before build** | webpack-stats + media/assets must be gitignored |
| Phase 7 scope | N/A | N/A | 2 tasks | **8 tasks** | v1.3 missed VM sync, Mac pull, and artifact cleanup |
| Add BUILD_MODE / SEAFILE_RUNTIME flag? | No | Same | Same | Same | Rejected — RPCProxy already gives correct build vs runtime divergence (zero) without adding a flag |
| Patch lazy import into Seafile source? | No | Same | Same | Same | Rejected — upstream's existing `else: RPCProxy()` branch already handles this; no patch needed |

---

## 13. What Changed Between Versions

### v1.0 → v1.1
1. Primary tactical option: Option D → Option J
2. Stub `seahub_settings.py`: ~15 lines → 3 lines
3. New evidence: container inspection + upstream seafile-build.py source

### v1.1 → v1.2
1. Option J executed successfully — System Info shows "Tengis Wiki"
2. `manage.py` at repo root, not seahub/
3. `SEAFILE_VERSION` must `sed` replace `6.3.3`, not append
4. `system-dist-packages` — third `docker cp` required
5. `DATABASES` in stub IS required
6. `frontend/build/` is nested at `build/frontend/`
7. `media/assets/` at repo root

### v1.2 → v1.3 (superseded — contained errors)
1. Claimed project complete — incorrect
2. Three Phase 7 issues were not caught or fixed

### v1.3 → v1.4
1. **Step-by-step verification** of all executed commands against actual terminal output
2. **Three Phase 7 issues discovered and fixed** during verification
3. **Phase 7 expanded** from 2 tasks to 8 tasks with correct sequence
4. **Finding 15** — `.dockerignore` must be at build context root (`~/tengiswiki/`), not adjacent to Dockerfile; Task 4.2 rewritten accordingly
5. **Finding 16** — build artifacts (`webpack-stats.pro.json`, `media/assets/`) must be gitignored before first build; Task 7.5 added to handle this
6. **Final `tengis-wiki-fr` commit** corrected from `09f749085` to `4399bc278`
7. **SEAFILE_VERSION sed command** made more robust — now uses `'[^']*'` pattern instead of hardcoded `'6.3.3'`

### v1.4 → v1.5
Documentation-consolidation pass. No technical changes, no rebuild, no new findings — only material folded in from predecessor documents before those documents are deleted.

1. **Compressed image sizes** added to §2 — `13.0.21` is 570 MB compressed, `13.0.21-r2` is 644 MB compressed; the +74 MB delta is the baked-in React build and `media/assets/` (from build-plan v1.2)
2. **Upstream `Seahub` class source code** (8 lines) plus the verifying GitHub URL added to Finding 6 (from build-plan v1.1)
3. **configparser behavior detail** added to Finding 3 — explains *why* the empty `fake-conf/` directory works: `configparser.has_option()` silently returns `False` on missing files (from build-plan v1.1)
4. **seafevents-in-CE explanation expanded** in Finding 5 — what the standalone process actually does (email, statistics, file history), why Pro-only views returning `None` via RPCProxy is correct CE behavior, and the explicit "zero divergence" claim between build-time and runtime (from build-plan v1.1)
5. **Four-bullet practical rationale for Option J** added to §6 — normal Python environment, easy debugging, reuses existing `node_modules`, trivially simple Dockerfile (from build-plan v1.1)
6. **Two rejected-option rows** added to Decision Record §12 — `BUILD_MODE`/`SEAFILE_RUNTIME` flag and source-level lazy-import patch were both considered and rejected; recorded so they don't get re-proposed (from build-plan v1.1)
7. **Task 1.0 prerequisites step** added to Phase 1 — Node.js 20 + `build-essential` + `python3` apt-install. The `build-essential` rationale (native npm packages compile C code) was previously undocumented in this plan (from frontend-build v1.0)

After v1.5 is saved, these predecessor documents can be deleted: `tengis-wiki-build-plan-v1_1.md`, `tengis-wiki-build-plan-v1_2.md`, `tengis-wiki-build-plan-v1_3.md`, `tengis-wiki-frontend-build-v1_0.md`. (`tengis-wiki-build-plan-v1_0.md` is retained as the Option D fallback reference per §9.)

### v1.5 → v1.6
Absorbed v1.0 (the original planning document) into this plan. v1.0's unique content — multi-stage Dockerfile sketch, build-failure decision table, rollback procedure, runtime validation checklist, future upgrade process — has been folded into §9 and §6.3 and a new §14, with all four v1.4-era corrections baked in directly. **After v1.6 is saved, `tengis-wiki-build-plan-v1_0.md` can be deleted.** Canonical doc set drops from 4 documents to 3.

1. **§9 expanded** from a 10-line stub into five subsections (~140 lines): §9.1 when to use, §9.2 the four v1.4 corrections preserved verbatim, §9.3 full multi-stage Dockerfile sketch with all v1.4 fixes baked in, §9.4 error→cause→fix decision table for build failures (9 rows mapped to Findings 1, 9, 10, 11, 14), §9.5 explicit rollback procedure with caveat about `docker image prune`
2. **Task 6.3 (Browser verification) extended** from 6 items to 9 — added file history, search, and browser tab title checks. The seafevents-integration items are now explicitly called out as the operationally critical checks since they verify the build-time RPCProxy isolation did not suppress runtime functionality
3. **New §14 (Future Seafile Upgrade Process)** added at end of plan — five-step recipe for handling new upstream Seafile releases (re-verify findings, confirm RPCProxy still present, bump base image tag, re-run Phases 0–7, tag and release)
4. **Deletion list updated** — v1.0 removed from "retained" status; canonical doc set drops to 3 files

---

## 14. Future Seafile Upgrade Process

When Seafile releases a new upstream version (13.1, 14.0, etc.) and Tengis Wiki needs to track it, the upgrade process is:

### 14.1 Re-verify the source-code findings

Before any build work, confirm that the assumptions this plan rests on are still true in the new Seafile version. Specifically:

1. **The conditional seafevents import (Finding 1)** — verify `seahub/utils/__init__.py` still has the `if EVENTS_CONFIG_FILE: ... else: RPCProxy()` pattern. If upstream restructures this, the build-time stub strategy needs re-thinking.
2. **`is_cluster_mode()` (Finding 3)** — verify the function still reads `SEAFILE_CENTRAL_CONF_DIR` / `SEAFILE_DATA_DIR` from environment variables and that `configparser.has_option()` is still used for the cluster check. If the implementation changes, the empty `fake-conf/` directory pattern may no longer work.
3. **Upstream `seafile-build.py` Seahub class (Finding 6)** — confirm `build_commands = []` and that no `npm run build` or `collectstatic` was added to the upstream docker build pipeline. If upstream starts running these inside their build, our Option J approach can be simplified to match theirs.

```bash
# Quick verification
curl -s https://raw.githubusercontent.com/haiwen/seahub/master/seahub/utils/__init__.py | grep -A 10 "EVENTS_CONFIG_FILE"
curl -s https://raw.githubusercontent.com/haiwen/seafile-docker/master/build/seafile_<NEW_VERSION>/seafile-build.py | grep -A 5 "class Seahub"
```

### 14.2 Bump the base image tag

In the Dockerfile:

```dockerfile
FROM seafileltd/seafile-mc:<NEW_TAG>
```

And update `SEAFILE_VERSION` in two places:
- The `sed` command in the build that rewrites `seahub/settings.py` (Phase 2)
- The `ARG SEAFILE_VERSION=` line in the Dockerfile (Phase 4)
- All `INSTALLPATH` references throughout the Dockerfile if the version directory name changed (`seafile-server-13.0.21` → `seafile-server-X.Y.Z`)

### 14.3 Run the full pipeline

Execute Phases 0–7 from §8 against the new version. Specifically watch for:

- Phase 1 React build — new Seafile versions sometimes change `frontend/package.json` dependencies; `npm install` may need to run again even if `node_modules/` exists
- Phase 3 collectstatic — if new Django apps were added, the `media/assets/` size will change; verify the output is reasonable (not significantly smaller than before)
- Phase 6 browser checklist — pay special attention to the seafevents items (file history, search). New Seafile versions sometimes change the seafevents protocol, and a build that works at the image-build stage can still fail at runtime if the version contract drifted

### 14.4 Tag and release

```bash
docker tag tengis/tengis-wiki:test-build tengis/tengis-wiki:<NEW_VERSION>
docker tag tengis/tengis-wiki:test-build tengis/tengis-wiki:latest
```

Update §2 of this plan with the new image state. Commit and push both repos.

### 14.5 Keep the previous version available for rollback

Do not delete the previous tagged image after a release. Keep at least one prior version in the local registry (and on Docker Hub if you push there) so that the §9.5 rollback procedure remains usable. A reasonable retention policy is "keep the current and the previous two major versions."

### 14.6 Update upstream tracking

If you've patched or rebased your `tengis-wiki-fr` fork against upstream Seahub, rebase against the new upstream tag:

```bash
cd ~/tengiswiki/tengis-wiki-fr
git remote add upstream https://github.com/haiwen/seahub.git   # if not already set
git fetch upstream
git rebase upstream/v<NEW_TAG>
# Resolve any conflicts in rebrand files (media/, templates/, locale/, info.js)
```

Most rebrand work lives in files that upstream rarely touches, so conflicts are usually minimal. The biggest risk areas are `frontend/src/pages/sys-admin/info.js` (the React `info.js` fix from Fix 3 in the project guide) and any CSS files where upstream changed token names.

---

**End of plan. For a new build cycle, start at Section 8, Pre-session checklist.**
