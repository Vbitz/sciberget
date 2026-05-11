# Architecture

sci-ber-get follows the useful Neurodesk pattern, but keeps all MVP state in one
repository.

The flow is:

1. A focused Kali tool, coherent suite, or sci-ber-get infrastructure image is described in `recipes/<name>/build.yaml`.
2. The vendored builder turns the recipe into `build/<name>/<name>_<version>.Dockerfile`.
3. CI or a local build creates a Docker image and optionally converts it to a SIF.
4. `releases/<name>/<version>.json` records the app metadata.
5. `tools/generate_apps_json.py` consolidates release files into `apps.json`.
6. `cvmfs/generate_log.py` creates `cvmfs/log.txt` for the Stratum 0 sync script.
7. `cvmfs/sync_containers_to_cvmfs.sh` publishes SIFs into CVMFS and exposes Lmod modules.
8. The Guacamole desktop recipe builds a browser desktop that mounts CVMFS and lets users load tools with `module load`.

The first 25 Kali recipes are individual tools/suites, not Kali metapackages.
Kali metapackage labels are used as categories for metadata and desktop menus.
`recipes/sciberget-desktop` and `recipes/sciberget-cvmfs-server` are operational
recipes for running the MVP on a VM or Docker host.

## Runtime Layout

- CVMFS root: `/cvmfs/${SCIBERGET_CVMFS_REPO}`
- Containers: `/cvmfs/${SCIBERGET_CVMFS_REPO}/containers`
- Category modules: `/cvmfs/${SCIBERGET_CVMFS_REPO}/sciberget-modules`
- Local fallback containers: `/sciberget-storage/containers`
- Desktop URL: `http://localhost:8080/`
- Local CVMFS server URL: `http://localhost:8081/cvmfs/<repo>`

The placeholder CVMFS repository name is `sciberget.example.org`. Replace it,
the CVMFS public key, and object storage URL before operating a real Stratum 0.
