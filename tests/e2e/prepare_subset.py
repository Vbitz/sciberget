#!/usr/bin/env python3
"""Prepare a small manifest for the compose CVMFS desktop E2E test."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import yaml


def app_release(apps_json: dict, name: str, version: str) -> dict:
    container = apps_json.get(name)
    if not container:
        raise SystemExit(f"{name}: missing from apps.json")
    app_name = f"{name} {version}"
    app = container.get("apps", {}).get(app_name)
    if not app:
        available = ", ".join(sorted(container.get("apps", {}).keys()))
        raise SystemExit(f"{name}: missing app release {app_name!r}; available: {available}")
    return app


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apps", default="nmap", help="Comma-separated recipe names")
    parser.add_argument("--output", default="tests/e2e/.generated/subset.json")
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    apps_json = json.loads((repo_root / "apps.json").read_text())
    selected = [item.strip() for item in args.apps.split(",") if item.strip()]
    if not selected:
        raise SystemExit("No apps selected")

    manifest = {"apps": []}
    for name in selected:
        recipe_path = repo_root / "recipes" / name / "build.yaml"
        if not recipe_path.exists():
            raise SystemExit(f"{name}: missing recipe {recipe_path}")
        recipe = yaml.safe_load(recipe_path.read_text())
        version = str(recipe["version"])
        release = app_release(apps_json, name, version)
        build_date = str(release["version"])
        categories = recipe.get("categories") or apps_json[name].get("categories") or ["other"]
        bins = (recipe.get("deploy") or {}).get("bins") or [name]
        image_id = f"{name}_{version}_{build_date}"
        manifest["apps"].append(
            {
                "name": name,
                "version": version,
                "build_date": build_date,
                "image_id": image_id,
                "sif": f"sifs/{image_id}.simg",
                "categories": categories,
                "bins": bins,
            }
        )

    output = repo_root / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(manifest, indent=2) + "\n")
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
