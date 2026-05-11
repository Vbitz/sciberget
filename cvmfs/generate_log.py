#!/usr/bin/env python3
"""Generate cvmfs/log.txt from the repo-local apps.json."""

import argparse
import json
from pathlib import Path

INFRASTRUCTURE_CONTAINERS = {
    "sciberget-cvmfs-server",
    "sciberget-desktop",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apps-json", default="apps.json")
    parser.add_argument("--output", default="cvmfs/log.txt")
    args = parser.parse_args()

    apps_path = Path(args.apps_json)
    output_path = Path(args.output)
    data = json.loads(apps_path.read_text())

    lines = []
    for container_name, container_data in sorted(data.items()):
        if container_name in INFRASTRUCTURE_CONTAINERS:
            continue

        categories = ",".join(container_data.get("categories") or ["other"])
        for app_name, app_data in sorted(container_data.get("apps", {}).items()):
            if app_data.get("exec"):
                continue
            name, version = app_name.rsplit(" ", 1)
            build_date = app_data["version"]
            lines.append(f"{name}_{version}_{build_date} categories:{categories},")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines) + ("\n" if lines else ""))
    print(f"Wrote {len(lines)} entries to {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
