# CVMFS Stratum 0

The MVP Stratum 0 entry point is `cvmfs/sync_containers_to_cvmfs.sh`.

Configure it with environment variables or by editing `cvmfs/sciberget.env`:

```bash
export SCIBERGET_CVMFS_REPO=sciberget.example.org
export SCIBERGET_OBJECT_BASE_URL=https://object.example.org/sciberget
export SCIBERGET_DRY_RUN=true
```

Run a dry run first:

```bash
SCIBERGET_DRY_RUN=true bash cvmfs/sync_containers_to_cvmfs.sh
```

For production use, replace the placeholder CVMFS public key in
`config/cvmfs/sciberget.example.org.pub`, configure the real server URL in
`config/cvmfs/sciberget.example.org.conf`, and make sure object storage contains
SIFs named as:

```text
<tool>_<version>_<builddate>.simg
```

The sync script opens CVMFS transactions, clones transparent-singularity into
new container directories, unpacks the SIF, publishes the transaction, and
copies generated module files into category paths under `sciberget-modules`.
