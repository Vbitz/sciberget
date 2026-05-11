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
- A Docker Compose end-to-end CVMFS plus desktop test in `tests/e2e/`.
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
make e2e-compose
make e2e-compose-down
```

Use `make e2e-compose E2E_APPS=nmap,ffuf` to publish and test a configurable
subset of tools. The Guacamole username is `sciberget`; the desktop password is
generated at container startup and printed in the container logs unless
`SCIBERGET_DESKTOP_PASSWORD` is set. See `PLAN.md` for the implementation plan
and `docs/` for architecture, recipe, CVMFS operator, and E2E compose notes.
