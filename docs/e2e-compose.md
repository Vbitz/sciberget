# Compose End-To-End Test

This harness starts a local CVMFS server, publishes a selected subset of local
SIF containers into that repository, starts the Guacamole desktop, mounts the
repository inside the desktop container, and verifies the selected tools can run
from CVMFS.

Default test:

```bash
make e2e-compose
```

Select a subset:

```bash
make e2e-compose E2E_APPS=nmap,ffuf
```

The harness builds missing SIFs before starting compose. It defaults to `nmap`
because that is small enough for a quick smoke test. By default it also removes
the previous E2E compose volumes before starting; set `SCIBERGET_E2E_CLEAN=false`
to keep an existing local repository between runs.

Services:

- `cvmfs-server`: local Stratum 0 HTTP server for `sciberget.local`
- `desktop`: Guacamole/LXDE desktop configured to mount `sciberget.local`

The selected SIFs and module files are published by executing the publish script
inside the running `cvmfs-server` container. That keeps publication in the same
CVMFS server environment that initialized the repository.

Useful URLs after a successful run:

- Desktop: `http://localhost:8080/`
- CVMFS HTTP repository: `http://localhost:8081/cvmfs/sciberget.local/`

The Guacamole username is `sciberget`. The password is randomly generated at
desktop startup and printed in the desktop container logs. Set
`SCIBERGET_DESKTOP_PASSWORD=...` before `make e2e-compose` to force a known
password for local testing.

Stop and remove the test volumes:

```bash
make e2e-compose-down
```

The desktop container runs as root only long enough to configure and mount CVMFS,
then drops to the `sciberget` user before starting VNC, Guacamole, and Tomcat.
