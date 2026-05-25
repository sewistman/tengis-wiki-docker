# Tengis Wiki — Path Inventory & Branding Boundary Reference

This document records every file surfaced in the Seafile → Tengis Wiki branding audit of
the Docker repo. Each entry shows whether it was changed or must never be touched, and the
reason for that classification. Use it as the authoritative reference before making any
further branding edits.

Rule source: `CLAUDE.md` in this repo.

---

## 1. Docker Image Scripts — CHANGED

These files contain publicly visible Docker Hub / registry image names. CLAUDE.md requires
all image names to use the `tengis` prefix and must not reference `seafile` or `seafileltd`.

| File | Lines changed | What changed |
|------|--------------|--------------|
| `image/docker-manifest-push.sh` | 7, 9, 11, 15, 17, 19, 23, 24 | `seafileltd/seafile-mc:*` → `tengis/tengis-wiki:*` |
| `image/docker-manifest-push-pro.sh` | 7, 9, 11, 15, 17, 19, 23, 25, 27, 31, 33, 35, 39, 40, 41, 42 | `seafileltd/seafile-pro-mc:*` and `docker.seafile.top/seafileltd/seafile-pro-mc:*` → `tengis/tengis-wiki:*` |
| `image/seafile_13.0/docker-build-push.sh` | 6, 10, 14 | `seafileltd/seafile-mc:*` → `tengis/tengis-wiki:*` |
| `image/seafile_13.0_arm/docker-build-push.sh` | 6, 10, 14 | same |
| `image/pro_seafile_13.0/docker-build-push.sh` | 6, 8, 12, 14, 18, 19 | `seafileltd/seafile-pro-mc:*` and `docker.seafile.top/seafileltd/seafile-pro-mc:*` → `tengis/tengis-wiki:*` |
| `image/pro_seafile_13.0_arm/docker-build-push.sh` | 6, 8, 12, 14, 18, 19 | same |
| `image/pro_seafile_14.0/docker-build-push.sh` | 6, 8, 12, 14, 18, 19 | same |

**Why changed:** Docker image names are user-visible registry artifacts. Anyone pulling or
referencing the image sees the name. CLAUDE.md explicitly requires image names to use the
`tengis` prefix.

**Note on `docker.seafile.top/` prefix:** The registry hostname `seafile.top` is not in the
CLAUDE.md domain replacement list (`seafile.com`, `seafileltd.com`, `manual.seafile.com`,
`forum.seafile.com`). The hostname was left unchanged; only the image name path segment
was updated.

---

## 2. Build Scripts — CHANGED (echo status messages only)

These scripts emit operator-visible status text during image builds. The product name
"Seafile" in those messages was replaced with "Tengis Wiki". All internal path references,
variable names, and artifact names on non-echo lines were untouched.

| File | Lines changed | What changed |
|------|--------------|--------------|
| `build/seafile_11.0/seafile-build.sh` | 188 | `"Info: Seafile Version [ ${tag} ]"` → `"Info: Tengis Wiki Version [ ${tag} ]"` |
| `build/seafile_12.0/seafile-build.sh` | 202 | same |
| `build/seafile_13.0/seafile-build.sh` | 203 | same |
| `build/seafile_14.0/seafile-build.sh` | 203 | same |

**Why changed:** These `echo` lines are the only user-visible strings in the build scripts.
The substitution was scoped to lines matching `/echo/` and was case-sensitive (`Seafile` not
`seafile`), so lowercase references to `seafile-server` in artifact filenames on other lines
were not affected.

**Lines NOT changed in the same files:**

| Line example | Reason |
|--------------|--------|
| `echo 'Usage: ./seafile-build.sh $version'` (line 5) | Lowercase `seafile` — refers to the script filename, not the product name |
| `echo "Info: Successfully built seafile-server-${version}"` (line 206/220/221) | `seafile-server` is a technical artifact name (lowercase), not a product label |
| `git clone https://github.com/haiwen/seafile-server.git` | Internal upstream source repo — not user-facing |
| `cd ${code_path}/seafile-server` | Internal path convention |
| `python3 ./seafile-build.py ...` | Internal build script reference |

---

## 3. Operator Scripts — CHANGED (echo status messages only)

Runtime scripts that print status messages to administrator terminals. "Seafile" in those
messages was replaced with "Tengis Wiki". All internal logic, paths, and variable names
were untouched.

### gc.sh (all versions: 7.1, 8.0, 9.0, 10.0, 11.0)

| File | Lines changed | Before → After |
|------|--------------|----------------|
| `scripts/scripts_7.1/gc.sh` | 9, 15 | `"Seafile CE: Stop Seafile..."` → `"Tengis Wiki CE: Stop Tengis Wiki..."` / `"Seafile Pro: Perform online..."` → `"Tengis Wiki Pro: Perform online..."` |
| `scripts/scripts_8.0/gc.sh` | 9, 15 | same |
| `scripts/scripts_9.0/gc.sh` | 9, 15 | same |
| `scripts/scripts_10.0/gc.sh` | 9, 15 | same |
| `scripts/scripts_11.0/gc.sh` | 9, 15 | same |

Note: `scripts/scripts_12.0/gc.sh`, `scripts_13.0/gc.sh`, and `scripts_14.0/gc.sh` had no
matching echo lines — the CE/Pro messages were already absent in those versions.

### cluster_server.sh (all versions: 8.0–14.0)

| File | Lines changed | Before → After |
|------|--------------|----------------|
| `scripts/scripts_8.0/cluster_server.sh` | 37, 69 | `"Seafile cluster conf not exists!"` → `"Tengis Wiki cluster conf not exists!"` / `"Seafile cluster $CLUSTER_MODE mode"` → `"Tengis Wiki cluster $CLUSTER_MODE mode"` |
| `scripts/scripts_9.0/cluster_server.sh` | 37, 69 | same |
| `scripts/scripts_10.0/cluster_server.sh` | 37, 69 | same |
| `scripts/scripts_11.0/cluster_server.sh` | 37, 69 | same |
| `scripts/scripts_12.0/cluster_server.sh` | 40, 74 | same |
| `scripts/scripts_13.0/cluster_server.sh` | 40, 74 | same |
| `scripts/scripts_14.0/cluster_server.sh` | 40, 74 | same |

**Why changed:** These `echo` strings are what an administrator sees in the container log
or terminal when running GC or cluster operations. They are operator-facing product labels,
not internal identifiers.

---

## 4. Dockerfiles — DO NOT TOUCH

All `Dockerfile` files under `image/` and `custom/` contain internal build instructions.
Every "seafile" reference in them is a path, env var name, binary name, or copy source —
none are user-visible strings.

| Pattern | Example | Reason |
|---------|---------|--------|
| `ENV SEAFILE_SERVER=seafile-pro-server` | All `image/*/Dockerfile` line 2–3 | `SEAFILE_SERVER` is an internal env var name passed to application code. CLAUDE.md explicitly lists env var names as never-touch. |
| `ENV SEAFILE_VERSION=` | Same files | Same — internal env var. |
| `WORKDIR /opt/seafile` | All `image/*/Dockerfile` | Volume mount path the application reads by convention. CLAUDE.md: volume mount paths must not change. |
| `COPY seafile-pro-server-${SEAFILE_VERSION} /opt/seafile/...` | All `image/*/Dockerfile` | Internal filesystem path and binary directory name. |
| `# Seafile` section comment | All `image/*/Dockerfile` | Internal code comment. CLAUDE.md: internal code comments are not user-facing and must not be changed. |
| `mv /services/seafile.nginx.conf /etc/nginx/sites-enabled/seafile.nginx.conf` | `image/seafile_13.0/Dockerfile:64`, `image/pro_seafile_13.0/Dockerfile:72`, etc. | Internal filesystem operation referencing a config filename the nginx service reads by convention. |
| `RUN wget .../seafile-pro-server_${SEAFILE_VERSION}_x86-64_Ubuntu.tar.gz` | `image/pro_seafile_7.1/Dockerfile:62`, `image/pro_seafile_8.0/Dockerfile:74` | Internal artifact download URL (not a seafile.com URL per CLAUDE.md list — this is `download.seafile.top`). |

**Affected Dockerfiles (do not touch):**
- `image/seafile_7.1/Dockerfile`
- `image/seafile_8.0/Dockerfile`
- `image/seafile_9.0/Dockerfile`, `image/seafile_9.0_arm/Dockerfile`
- `image/seafile_10.0/Dockerfile`, `image/seafile_10.0_arm/Dockerfile`
- `image/seafile_11.0/Dockerfile`, `image/seafile_11.0_arm/Dockerfile`
- `image/seafile_12.0/Dockerfile`, `image/seafile_12.0_arm/Dockerfile`
- `image/seafile_13.0/Dockerfile`, `image/seafile_13.0_arm/Dockerfile`
- `image/pro_seafile_7.1/Dockerfile`
- `image/pro_seafile_8.0/Dockerfile`
- `image/pro_seafile_9.0/Dockerfile`, `image/pro_seafile_9.0_arm/Dockerfile`
- `image/pro_seafile_10.0/Dockerfile`, `image/pro_seafile_10.0_arm/Dockerfile`
- `image/pro_seafile_11.0/Dockerfile`, `image/pro_seafile_11.0_arm/Dockerfile`
- `image/pro_seafile_12.0/Dockerfile`, `image/pro_seafile_12.0_arm/Dockerfile`
- `image/pro_seafile_13.0/Dockerfile`, `image/pro_seafile_13.0_arm/Dockerfile`
- `image/pro_seafile_14.0/Dockerfile`
- `custom/pro_seafile_9.0/Dockerfile`
- `custom/pro_seafile_10.0/Dockerfile`
- `custom/pro_seafile_11.0/Dockerfile`

---

## 5. Nginx Configs — DO NOT TOUCH

| File | Pattern | Reason |
|------|---------|--------|
| `services/nginx.conf:17` | `log_format seafileformat ...` | `seafileformat` is an internal nginx named format identifier. Renaming it would break the `access_log ... seafileformat` references throughout all server blocks. |
| `services/seafile.nginx.conf:19,33,50` | `access_log ... seafileformat` | References the internal nginx format name above. |
| `services/seafile.nginx.conf:20,34,51` | `error_log /shared/seafile/logs/...` | Log file paths inside the volume mount — internal path convention. |
| `services/seafile.nginx.conf:60` | `root /opt/seafile/seafile-server-latest/seahub` | Internal install path the nginx process reads by convention. |
| `image/pro_seafile_7.1/services/nginx.conf:17,19` | same `seafileformat` pattern | same |
| `image/pro_seafile_8.0/services/nginx.conf:17,19` | same | same |
| `image/pro_seafile_9.0/services/nginx.conf:17,19` | same | same |
| `image/pro_seafile_9.0_arm/services/nginx.conf:17,19` | same | same |
| `image/seafile_7.1/services/nginx.conf:17,19` | same | same |
| `image/seafile_8.0/services/nginx.conf:17,19` | same | same |
| `image/seafile_9.0/services/nginx.conf:17,19` | same | same |
| `image/seafile_9.0_arm/services/nginx.conf:17,19` | same | same |

---

## 6. Volume Paths — DO NOT TOUCH

All references to `/opt/seafile/` and `/shared/seafile/` throughout the scripts are
filesystem paths that the application binary reads by convention at runtime. Changing them
would break the running container without a corresponding change in the upstream application.

| Path pattern | Found in |
|-------------|----------|
| `/opt/seafile/` (install root) | All `scripts/scripts_*/enterpoint.sh`, `cluster_server.sh`, `gc.sh` |
| `/opt/seafile/conf` | All `scripts/scripts_*/cluster_server.sh` |
| `/opt/seafile/logs/enterpoint.log` | All `scripts/scripts_*/enterpoint.sh` |
| `/opt/seafile/seafile-server-latest/` | All `scripts/scripts_*/cluster_server.sh`, `gc.sh` |
| `/opt/seafile/pids` | `scripts/scripts_13.0/enterpoint.sh`, `scripts/scripts_14.0/enterpoint.sh` |
| `/shared/seafile/` (data volume root) | All `scripts/scripts_*/create_data_links.sh` |
| `/shared/seafile/logs/` | All `scripts/scripts_*/create_data_links.sh` |
| `/shared/seafile/seahub-data` | All `scripts/scripts_*/cluster_server.sh` |
| `/shared/seafile/$d` (symlink source) | All `scripts/scripts_*/create_data_links.sh` |
| `/shared/logs/seafile` (legacy log path) | All `scripts/scripts_*/create_data_links.sh` |
| `seafile.nginx.conf` (config filename) | All `scripts/scripts_*/create_data_links.sh:51–53` |

---

## 7. Environment Variable Names — DO NOT TOUCH

These env var names are read by application code and startup scripts. Renaming them would
break the entire container startup sequence.

| Variable | Used in | Reason |
|----------|---------|--------|
| `$SEAFILE_SERVER` | All `scripts/scripts_*/enterpoint.sh`, `cluster_server.sh`, `gc.sh` | Application code reads this to determine CE vs Pro mode. Also used in `$SEAFILE_SERVER == "seafile-pro-server"` conditionals that gate cluster logic. |
| `$SEAFILE_VERSION` | All `scripts/scripts_*/enterpoint.sh` | Used to locate the versioned install directory. |
| `$SEAFILE_BOOTSRAP` | All `scripts/scripts_*/create_data_links.sh:6` | Controls whether data link creation runs during bootstrap. |
| `$SEAFILE_DIR` | All `scripts/scripts_*/gc.sh:6` | Points to the server binary directory. |
| `SEAFILE_SERVER` (ENV in Dockerfile) | All `image/*/Dockerfile` | Dockerfile build-time declaration of the above runtime var. |
| `SEAFILE_VERSION` (ENV in Dockerfile) | All `image/*/Dockerfile` | Same. |

---

## 8. Binary Names and System Identifiers — DO NOT TOUCH

These are executable script names, system user/group names, and data directory names that
the application, OS, and init system refer to by their exact string.

| Identifier | Type | Found in | Reason |
|------------|------|---------|--------|
| `seafile.sh` | Binary | All `scripts/scripts_*/cluster_server.sh`, `enterpoint.sh`, `gc.sh` | Upstream server control script — name is set by the upstream package. |
| `seahub.sh` | Binary | All `scripts/scripts_*/cluster_server.sh` | Upstream web layer control script. |
| `seafile-background-tasks.sh` | Binary | All `scripts/scripts_*/cluster_server.sh` | Upstream background worker control script. |
| `seaf-gc.sh` | Binary | All `scripts/scripts_*/gc.sh` | Upstream garbage collection binary. |
| `seafile` (Linux user) | OS user | All `scripts/scripts_*/enterpoint.sh` (`groupadd`, `useradd`, `chown`) | System user the container process runs as. Changing it requires corresponding changes in file ownership and the application's expected user. |
| `seafile` (Linux group) | OS group | Same | Same. |
| `seafile-data` | Data dir name | All `scripts/scripts_*/create_data_links.sh:24` | Upstream application data directory name — must match what `seafile.sh` expects. |
| `seafile-license.txt` | License file | All `scripts/scripts_*/create_data_links.sh:27` | Upstream license file name read by the application at startup. |
| `seafile-server-latest` | Symlink target | All cluster and gc scripts | Convention symlink maintained by the installer — application code resolves it by this exact name. |
