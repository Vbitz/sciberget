# sci-ber-get

sci-ber-get is an MVP exploration of "Neurodesk, but for cyber security": a
Guacamole desktop backed by CVMFS-distributed Apptainer containers for common
Kali Linux security tools.

The current implementation includes:

- Vendored Neurocontainers-style builder tooling in `builder/`.
- 25 focused Kali tool/suite recipes in `recipes/`.
- Infrastructure recipes for the Guacamole desktop and a local CVMFS server.
- Generated release metadata in `releases/`, aggregate `apps.json`, and
  `cvmfs/log.txt`.
- A repo-local command/menu launcher layer in `command/`.
- Configurable CVMFS Stratum 0 scripts in `cvmfs/`.
- A Jupyter-free Guacamole desktop recipe in `recipes/sciberget-desktop/`.
- A hostable local-network CVMFS server recipe in `recipes/sciberget-cvmfs-server/`.
- MVP GitHub Actions for recipe validation, app builds, catalogue generation,
  desktop builds, and CVMFS script checks.

Useful local commands:

```bash
make validate
make generate APP=nmap
make release APP=nmap
make desktop
make desktop-run
make cvmfs-server
make cvmfs-server-run
```

See `PLAN.md` for the implementation plan and `docs/` for architecture,
recipe, and CVMFS operator notes.
