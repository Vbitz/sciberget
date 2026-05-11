# Recipes

Recipes live under `recipes/<tool>/build.yaml` and use the vendored
Neurocontainers YAML schema.

For the MVP, create one recipe per common Kali tool or natural suite. Do not use
full Kali metapackages as containers; use those names only as categories.
Operational images such as `sciberget-desktop` and `sciberget-cvmfs-server`
are also recipes and should use normal build directives, not hand-maintained
Dockerfiles.

Minimum recipe shape:

```yaml
name: nmap
version: "7.95"

architectures:
  - x86_64

categories:
  - information gathering

build:
  kind: neurodocker
  base-image: kalilinux/kali-rolling:latest
  pkg-manager: apt
  directives:
    - environment:
        DEBIAN_FRONTEND: noninteractive
    - install:
        - ca-certificates
        - nmap
    - run:
        - command -v nmap
        - apt-get clean
        - rm -rf /var/lib/apt/lists/*

deploy:
  bins:
    - nmap
```

Useful commands:

```bash
make validate
make generate APP=nmap
make release APP=nmap
make apps-json
make desktop
make cvmfs-server
```

GUI-capable tools can add:

```yaml
gui_apps:
  - name: wiresharkGUI
    exec: wireshark
```

Keep tests cheap and offline. Avoid commands that contact targets, update
templates from the internet, or require hardware.
