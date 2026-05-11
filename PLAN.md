# sci-ber-get MVP Plan

## Reviewed Inputs

This plan is based on a local review of the three vendored Neurodesk source repos under `local/`:

- `local/neurocontainers`
  - `builder/build.py`, `builder/validation.py`, `pyproject.toml`, `builder/README.md`
  - `.github/workflows/build-app.yml`, `manual-build.yml`, `auto-build.yml`, `recipes-ci.yml`, `validate-recipes.yml`, `update-apps-json.yml`
  - `tools/generate_apps_json.py`, `tools/generate_webapps_json.py`
  - `workflows/container_tester.py`, `workflows/test_runner.py`, `workflows/full_container_test.py`
  - sample recipe structure under `recipes/*/build.yaml`
- `local/neurocommand`
  - `build.sh`
  - `neurodesk/build_menu.py`, `fetch_and_run.sh`, `fetch_containers.sh`, `write_log.py`, `apps.json`, `webapps.json`
  - `cvmfs/sync_containers_to_cvmfs.sh`, `json_gen.py`, `clean_cvmfs_tags.sh`, `maintenance.sh`
  - `.github/workflows/upload_containers_simg.sh`
  - `docs/appsJsonMaintaince.md`
- `local/neurodesktop`
  - `Dockerfile`
  - `config/cvmfs/*`
  - `config/guacamole/guacamole.sh`, `init_secrets.sh`, `ensure_rdp_backend.sh`, `user-mapping*.xml`
  - `config/lxde/*`, `config/lmod/module.sh`
  - `config/jupyter/start_notebook.sh`, `before_notebook.sh`, `environment_variables.sh`
  - `.github/workflows/build-neurodesktop.yml`, `test-cvmfs.yml`
  - `docs/architecture.md`, `docs/environment-variables.md`

I also checked the current Kali documentation and tool listings. The MVP should use Kali's own metapackage groupings as category names, but should not build metapackage-sized containers. Kali's official `kali-tools-top10` list is a strong seed for initial tool selection, and Kali's front page highlights the same style of individual tools/suites.

## MVP Shape

The MVP should be a single repository that vendors the useful Neurodesk infrastructure but removes the current split-brain between Neurocontainers, Neurocommand, and Neurodesktop. The first usable system should build focused Kali tool/suite Apptainer/SIF containers, publish them into a sci-ber-get CVMFS repository, and expose them inside a browser desktop through Guacamole only.

Target repo layout:

```text
builder/                 # vendored and renamed Neurocontainers builder
recipes/                 # sci-ber-get tool/suite and infrastructure recipes
releases/                # generated release metadata per recipe/version
apps.json                # generated aggregate app catalogue
command/                 # vendored and renamed Neurocommand launcher/menu pieces
cvmfs/                   # Stratum 0 sync, publish, maintenance scripts
config/                  # CVMFS, Guacamole, LXDE, Lmod config for desktop image
workflows/               # local CI/test helpers from Neurocontainers
.github/workflows/       # build/test/publish workflows
docs/                    # architecture and operator notes
```

## Key Decisions To Validate

1. Repository identity
   - Pick final names for CVMFS FQRN, registry namespace, image names, and user-facing command names.
   - Working placeholders: `sciberget.org`, `ghcr.io/<owner>/sciberget`, `sci-ber-get-desktop`, `sbg`.

2. Container granularity
   - Follow Neurocontainers' actual collection pattern: one recipe per tool or coherent upstream suite, not one recipe per category.
   - A "suite" package can expose many binaries from one container when the upstream project is naturally a suite, for example `aircrack-ng`, `metasploit-framework`, `impacket-scripts`, or `sleuthkit`.
   - Avoid broad Kali metapackage containers for MVP. They create large images, blur update/test boundaries, and make CVMFS rollout riskier.
   - Use Kali metapackage names/categories only for menu organization, metadata, and validation.
   - Keep dependency sharing as a later optimization. The first pass should favor simple, independently testable containers.

3. Initial top-25 tool/suite containers
   - Selection basis:
     - Kali's official `kali-tools-top10` dependencies.
     - Tools highlighted on Kali's front page.
     - Commonly repeated tools in current practitioner-oriented Kali tool lists.
     - Coverage across recon, web, passwords, exploitation, sniffing/spoofing, wireless, forensics, reversing, and reporting.
   - Proposed MVP set:

```text
1.  nmap                  category: information gathering
2.  metasploit-framework  category: exploitation
3.  burpsuite             category: web applications
4.  wireshark             category: sniffing spoofing
5.  aircrack-ng           category: wireless
6.  hydra                 category: password attacks
7.  john                  category: password attacks
8.  hashcat               category: password attacks
9.  sqlmap                category: database assessment
10. netexec               category: exploitation
11. responder             category: sniffing spoofing
12. ffuf                  category: web applications
13. gobuster              category: web applications
14. nikto                 category: vulnerability analysis
15. nuclei                category: vulnerability analysis
16. exploitdb             category: exploitation
17. impacket-scripts      category: post exploitation
18. tcpdump               category: sniffing spoofing
19. netcat-traditional    category: exploitation
20. enum4linux-ng         category: information gathering
21. wpscan                category: web applications
22. zaproxy               category: web applications
23. autopsy               category: forensics
24. binwalk               category: hardware
25. ghidra                category: reverse engineering
```

   - Revisit before implementation:
     - `burpsuite`, `zaproxy`, `wireshark`, `autopsy`, and `ghidra` need GUI/browser handling and may deserve explicit desktop launchers.
     - `hashcat` needs GPU/driver expectations documented; still useful CPU-only for MVP smoke tests.
     - `netcat-traditional` may be too small to deserve its own container, but it is common enough to keep unless we create a compact "operators-basics" suite later.
     - `nuclei` availability/versioning should be checked in Kali apt before recipe work starts.

4. Category vocabulary
   - Use Kali category/metapackage labels for metadata and menus:
     - `information gathering`
     - `vulnerability analysis`
     - `web applications`
     - `database assessment`
     - `password attacks`
     - `wireless`
     - `reverse engineering`
     - `exploitation`
     - `sniffing spoofing`
     - `post exploitation`
     - `forensics`
     - `reporting`
     - `crypto stego`
     - `hardware`
     - `fuzzing`
     - `other`

5. Base image strategy
   - Prefer `kalilinux/kali-rolling` as the recipe base image.
   - Use recipe-level apt installs of individual Kali packages or coherent suites with pinned build dates captured in release metadata.
   - Add noninteractive apt, cleanup, and basic smoke tests for representative binaries.

6. Desktop and local CVMFS server scope
   - Treat the Guacamole desktop as `recipes/sciberget-desktop`, built through the normal recipe directives.
   - Treat a local-network CVMFS Stratum 0/HTTP host as `recipes/sciberget-cvmfs-server`, also built through the normal recipe directives.
   - Use Guacamole, Tomcat, guacd, TigerVNC, LXDE, Lmod, CVMFS, and Apptainer/Singularity in the desktop.
   - Remove JupyterLab, notebook startup hooks, Jupyter server proxy, code-server, notebook kernels, Slurm, neuroimaging packages, and AI assistant tooling from the MVP desktop image.
   - Keep the robust Guacamole secret rotation and per-user VNC/Tomcat port logic from Neurodesktop.

7. CVMFS publishing model
   - Keep the Neurodesk transparent-singularity model:
     - SIFs are built from recipe-generated Docker images.
     - SIFs are unpacked on Stratum 0 into `/cvmfs/<repo>/containers/<name>_<version>_<builddate>/`.
     - Lmod module files are exposed under `/cvmfs/<repo>/sciberget-modules/<category>/<tool>/<version>`.
   - Replace hard-coded `neurodesk.ardc.edu.au`, `neurodesk-modules`, `vnmd`, Nectar, and AWS URLs with repo-local configuration variables.

## Implementation Plan

### Phase 1: Vendor The Builder

- Copy from `local/neurocontainers`:
  - `builder/`
  - `macros/` only if recipes still use includes
  - `workflows/` test helpers
  - `tools/generate_apps_json.py`
  - `pyproject.toml` dependency and script definitions
- Rename package/user-facing strings from `neurocontainers`/`sf-*` only where it improves clarity.
  - Conservative MVP: keep `sf-*` commands initially to reduce churn.
  - Later polish: add aliases such as `sbg-generate`, `sbg-build`, `sbg-test`.
- Update validation categories for cyber security:
  - use the category vocabulary above.
- Add minimal recipes for the 25 focused Kali tool/suite containers.
- Build the first three recipes before copying the whole set:
  - `nmap` for a small CLI tool.
  - `metasploit-framework` for a large CLI suite.
  - `burpsuite` or `wireshark` for GUI integration.
- Add `requirements.txt` or rely on `pip install -e .`; do not keep both unless CI needs both.

### Phase 2: Build And Release Metadata

- Adapt `builder/build.py` release generation so `releases/<name>/<version>.json` produces sci-ber-get app metadata.
- Keep the existing release shape where possible:

```json
{
  "apps": {
    "nmap 7.95": {
      "version": "20260511",
      "exec": "",
      "apptainer_args": []
    }
  },
  "categories": ["information gathering"]
}
```

- Generate top-level `apps.json` from `releases/` with the existing `tools/generate_apps_json.py`.
- GUI launchers are useful for a subset of the 25 containers.
  - Add explicit GUI entries for `burpsuite`, `wireshark`, `zaproxy`, `autopsy`, and `ghidra` if they run cleanly through Apptainer + Guacamole.
  - Use terminal launchers for CLI tools such as `nmap`, `sqlmap`, `hydra`, `john`, `hashcat`, `ffuf`, `gobuster`, `nikto`, and `impacket-scripts`.
  - Add browser-open wrappers only where the service lifecycle is manageable, for example `zaproxy` or `autopsy`.

### Phase 3: Command/Menu Layer

- Copy from `local/neurocommand/neurodesk` into `command/`:
  - `build_menu.py`
  - `fetch_and_run.sh`
  - `fetch_containers.sh`
  - `write_log.py`
  - `configparser.sh`
  - `transparent-singularity/`
- Copy/adapt `local/neurocommand/build.sh` and `install.sh`.
- Rename paths and prompts:
  - `neurodesk` -> `sciberget`
  - `/neurocommand` -> `/sciberget-command`
  - `/neurodesktop-storage` -> `/sciberget-storage`
  - `NEURODESKTOP_LOCAL_CONTAINERS` -> `SCIBERGET_LOCAL_CONTAINERS`
- Keep Lmod as the module frontend.
- Generate `.desktop` entries for LXDE, but keep menu content small for MVP.

### Phase 4: CVMFS Scripts

- Copy from `local/neurocommand/cvmfs`:
  - `sync_containers_to_cvmfs.sh`
  - `json_gen.py`
  - `clean_cvmfs_tags.sh`
  - `maintenance.sh`
- Refactor hard-coded values into a single config file, for example `cvmfs/sciberget.env`:

```bash
SCIBERGET_CVMFS_REPO="sciberget.example.org"
SCIBERGET_CVMFS_ROOT="/cvmfs/${SCIBERGET_CVMFS_REPO}"
SCIBERGET_MODULES_DIR="sciberget-modules"
SCIBERGET_CONTAINERS_DIR="containers"
SCIBERGET_OBJECT_BASE_URL="https://..."
SCIBERGET_OBJECT_RCLONE_REMOTE="..."
SCIBERGET_COMMAND_REPO_PATH="${HOME}/sciberget"
```

- Remove Neurodesk-specific git pull and cross-repo commit behavior.
- Make Stratum 0 sync consume this repo's `apps.json` or generated `cvmfs/log.txt` directly.
- Keep:
  - transaction reuse handling
  - publish/abort safety
  - nested catalog marker creation
  - stale image disabling
  - latest module pointer repair
  - tag cleanup
- Add dry-run mode before enabling destructive stale image cleanup.

### Phase 5: Infrastructure Recipes

- Build `recipes/sciberget-desktop/build.yaml` by reducing `local/neurodesktop/Dockerfile` into standard recipe directives.
- Build `recipes/sciberget-cvmfs-server/build.yaml` for a local-network CVMFS server that can run in a VM or privileged Docker container.
- Keep:
  - Guacamole server build stage
  - Tomcat + Guacamole WAR
  - TigerVNC + LXDE
  - CVMFS client install and config
  - Apptainer runtime
  - Lmod
  - Firefox and terminal tools if useful for cyber workflows
  - Guacamole `init_secrets.sh`, `guacamole.sh`, user mapping templates, LXDE xstartup
- Remove:
  - Jupyter base image dependency
  - JupyterLab, notebooks, kernels, jupyter-server-proxy
  - code-server
  - Slurm
  - Nextflow/neuroimaging tools
  - AI coding assistants
  - neurodesktop-specific tests and docs
- Base image options to test:
  - `debian:bookworm-slim` or `ubuntu:24.04` for a smaller desktop host
  - keep Kali tools in CVMFS containers, not in the desktop image
- Desktop startup should run Guacamole directly, probably exposing Tomcat on `8080`.
- Provide Makefile targets for local testing:

```bash
make desktop
make desktop-run
make cvmfs-server
make cvmfs-server-run
```

### Phase 6: GitHub Actions

MVP workflows to create:

- `.github/workflows/validate-recipes.yml`
  - Adapt Neurocontainers validation workflow.
  - Run on recipe changes.

- `.github/workflows/build-app.yml`
  - Reusable workflow adapted from Neurocontainers.
  - Generate Dockerfile.
  - Build Docker image with Buildx.
  - Push to GHCR.
  - Build SIF with Apptainer.
  - Upload SIF as an artifact or object storage object.
  - Generate release JSON.

- `.github/workflows/manual-build.yml`
  - Dispatch with comma-separated recipe names.

- `.github/workflows/auto-build.yml`
  - Trigger on `recipes/**`.
  - Use a small allowlist/config file for auto-build in MVP.

- `.github/workflows/update-apps-json.yml`
  - Generate repo-local `apps.json` from `releases/`.
  - Commit or open a PR in this same repo.

- `.github/workflows/build-desktop.yml`
  - Build and push `sciberget-desktop`.
  - Start with `linux/amd64`; add arm64 after the Dockerfile is stable.

- `.github/workflows/test-cvmfs.yml`
  - Adapt Neurodesktop CVMFS tests to mount/check the sci-ber-get repo.

Defer Docker Hub, Zenodo DOI, Nectar-specific upload, dashboard publishing, issue automation, full container tests, and Jupyter tests until the basic build/publish/desktop loop works.

### Phase 7: Local Developer UX

- Add `Makefile` or `justfile` targets:
  - `make validate`
  - `make generate APP=nmap`
  - `make build APP=nmap`
  - `make release APP=nmap`
  - `make apps-json`
  - `make desktop`
  - `make desktop-run`
- Add `docs/architecture.md` explaining:
  - recipe -> Docker image -> SIF -> object storage -> CVMFS -> Lmod -> Guacamole desktop
- Add `docs/cvmfs-stratum0.md` with required host setup and cron/systemd timer.
- Add `docs/recipes.md` for adding a Kali tool or coherent suite recipe.

## First Milestone Definition

The first MVP is done when:

1. A recipe such as `recipes/nmap/build.yaml` validates.
2. CI or local commands generate and build a Docker image from that recipe.
3. A SIF is created from the image.
4. `releases/nmap/<version>.json` and top-level `apps.json` are generated.
5. A Stratum 0 script can publish that SIF into a configurable CVMFS repo.
6. The desktop container starts Guacamole at `http://localhost:8080/`.
7. Inside the desktop terminal, `module avail` shows at least one sci-ber-get module from CVMFS.
8. `module load nmap/<version>` exposes expected Kali tools.

## Immediate Next Work

1. Create the repo skeleton and copy the builder/test tooling.
2. Add one recipe, probably `nmap`, because it is small, officially top-10, and gives a quick smoke-test loop.
3. Generate a Dockerfile locally and fix builder assumptions that are neuroimaging-specific.
4. Add `metasploit-framework` to exercise large suite builds and module exposure.
5. Add one GUI recipe, probably `burpsuite` or `wireshark`, to validate Guacamole launch behavior.
6. Reduce the desktop Dockerfile to Guacamole + CVMFS + Lmod + Apptainer.
7. Refactor CVMFS scripts to use sci-ber-get config variables instead of Neurodesk hard-coding.
