#!/usr/bin/env python3
"""Install LXDE menu and desktop entries for sci-ber-get."""

from __future__ import annotations

import configparser
import json
import os
import pwd
import shutil
from pathlib import Path
import xml.etree.ElementTree as ET


INSTALL_DIR = Path("/sciberget-command")
APPS_JSON = INSTALL_DIR / "apps.json"
APPLICATIONS_DIR = Path("/usr/share/applications")
DIRECTORIES_DIR = Path("/usr/share/desktop-directories/sciberget")
MERGED_MENU = Path("/etc/xdg/menus/applications-merged/sciberget-applications.menu")
LXDE_MENU = Path("/etc/xdg/menus/lxde-applications.menu")
DESKTOP_DIR = Path("/home/sciberget/Desktop")
ICON_SOURCE_DIR = INSTALL_DIR / "icons"
ICON_DIR = Path("/usr/share/icons/sciberget")
LIBFM_CONFIGS = [
    Path("/etc/xdg/libfm/libfm.conf"),
    Path("/home/sciberget/.config/libfm/libfm.conf"),
]

CATEGORIES = [
    "information gathering",
    "vulnerability analysis",
    "web applications",
    "database assessment",
    "password attacks",
    "wireless",
    "reverse engineering",
    "exploitation",
    "sniffing spoofing",
    "post exploitation",
    "forensics",
    "reporting",
    "crypto stego",
    "hardware",
    "fuzzing",
    "other",
]


def slug(value: str) -> str:
    return value.strip().lower().replace(" ", "-")


def write_desktop(path: Path, values: dict[str, str]) -> None:
    entry = configparser.ConfigParser(interpolation=None)
    entry.optionxform = str
    entry["Desktop Entry"] = values
    with path.open("w") as fh:
        entry.write(fh, space_around_delimiters=False)
    path.chmod(0o755)


def icon_for(name: str) -> str:
    first = name.split()[0].split("-")[0].lower()
    candidates = [
        ICON_SOURCE_DIR / f"{first}.png",
        ICON_SOURCE_DIR / "neurodesk.png",
        ICON_SOURCE_DIR / "aedapt.png",
    ]
    for candidate in candidates:
        if candidate.exists():
            ICON_DIR.mkdir(parents=True, exist_ok=True)
            target = ICON_DIR / candidate.name
            shutil.copyfile(candidate, target)
            return str(target)
    return "utilities-terminal"


def command_for(app_name: str, app_data: dict[str, object]) -> tuple[str, bool]:
    parts = app_name.split()
    module_name = parts[0]
    module_version = parts[1] if len(parts) > 1 else "latest"
    exec_name = str(app_data.get("exec") or "")
    command = f"/sciberget-command/fetch_and_run.sh {module_name} {module_version}"
    if exec_name:
        command = f"{command} {exec_name}"
    # CLI tools should leave the terminal open so users can read errors/output.
    return f"lxterminal --title='{app_name}' -e bash -lc '{command}; exec bash'", False


def write_directory(name: str) -> str:
    DIRECTORIES_DIR.mkdir(parents=True, exist_ok=True)
    filename = f"{slug(name)}.directory"
    entry = configparser.ConfigParser(interpolation=None)
    entry.optionxform = str
    entry["Desktop Entry"] = {
        "Name": name,
        "Comment": name,
        "Icon": icon_for(name),
        "Type": "Directory",
    }
    with (DIRECTORIES_DIR / filename).open("w") as fh:
        entry.write(fh, space_around_delimiters=False)
    return f"sciberget/{filename}"


def install_app_entries() -> None:
    data = json.loads(APPS_JSON.read_text())
    APPLICATIONS_DIR.mkdir(parents=True, exist_ok=True)
    DESKTOP_DIR.mkdir(parents=True, exist_ok=True)

    write_desktop(
        APPLICATIONS_DIR / "sciberget-terminal.desktop",
        {
            "Name": "Terminal",
            "Comment": "Open a terminal",
            "Exec": "lxterminal",
            "Icon": "utilities-terminal",
            "Type": "Application",
            "Categories": "sci-ber-get;System;TerminalEmulator;",
            "Terminal": "false",
        },
    )
    shutil.copyfile(
        APPLICATIONS_DIR / "sciberget-terminal.desktop",
        DESKTOP_DIR / "Terminal.desktop",
    )

    for menu_name, menu_data in data.items():
        category = slug(menu_name)
        for app_name, app_data in menu_data.get("apps", {}).items():
            exec_line, terminal = command_for(app_name, app_data)
            basename = f"sciberget-{slug(app_name).replace('.', '_')}.desktop"
            write_desktop(
                APPLICATIONS_DIR / basename,
                {
                    "Name": app_name,
                    "GenericName": app_name,
                    "Comment": f"sci-ber-get {app_name}",
                    "Exec": exec_line,
                    "Icon": icon_for(app_name),
                    "Type": "Application",
                    "Categories": f"sci-ber-get;All-Applications;{category};",
                    "Terminal": str(terminal).lower(),
                },
            )

    shutil.copyfile(
        APPLICATIONS_DIR / "sciberget-nmap-7_95.desktop",
        DESKTOP_DIR / "Nmap.desktop",
    )


def install_menu() -> None:
    ET.register_namespace("", "http://www.freedesktop.org/standards/menu-spec/1.0")
    root = ET.Element("Menu")
    ET.SubElement(root, "Name").text = "Applications"
    sci = ET.SubElement(root, "Menu")
    ET.SubElement(sci, "Name").text = "sci-ber-get"
    ET.SubElement(sci, "Directory").text = write_directory("sci-ber-get")
    include = ET.SubElement(sci, "Include")
    ET.SubElement(include, "Category").text = "sci-ber-get"

    all_apps = ET.SubElement(sci, "Menu")
    ET.SubElement(all_apps, "Name").text = "All Applications"
    ET.SubElement(all_apps, "Directory").text = write_directory("All Applications")
    all_include = ET.SubElement(all_apps, "Include")
    ET.SubElement(all_include, "Category").text = "All-Applications"

    for category in CATEGORIES:
        menu = ET.SubElement(sci, "Menu")
        ET.SubElement(menu, "Name").text = category.title()
        ET.SubElement(menu, "Directory").text = write_directory(category.title())
        include = ET.SubElement(menu, "Include")
        ET.SubElement(include, "Category").text = slug(category)

    MERGED_MENU.parent.mkdir(parents=True, exist_ok=True)
    tree = ET.ElementTree(root)
    tree.write(MERGED_MENU, encoding="utf-8", xml_declaration=True)
    with MERGED_MENU.open("r+") as fh:
        content = fh.read()
        fh.seek(0)
        fh.write(
            '<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN" '
            '"http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">\n'
            + content
        )
        fh.truncate()

    merge_line = "\t<MergeFile>applications-merged/sciberget-applications.menu</MergeFile>\n"
    if LXDE_MENU.exists():
        content = LXDE_MENU.read_text()
        if "sciberget-applications.menu" not in content:
            marker = "</Name>"
            index = content.find(marker)
            if index >= 0:
                index += len(marker)
                content = content[:index] + "\n" + merge_line + content[index:]
                LXDE_MENU.write_text(content)


def install_pcmanfm_defaults() -> None:
    for path in LIBFM_CONFIGS:
        parser = configparser.ConfigParser(interpolation=None)
        parser.optionxform = str
        if path.exists():
            parser.read(path)
        if "config" not in parser:
            parser["config"] = {}
        parser["config"]["quick_exec"] = "1"
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w") as fh:
            parser.write(fh, space_around_delimiters=False)


def main() -> None:
    install_app_entries()
    install_menu()
    install_pcmanfm_defaults()
    sciberget = pwd.getpwnam("sciberget")
    os.chown(DESKTOP_DIR, sciberget.pw_uid, sciberget.pw_gid)
    for path in DESKTOP_DIR.glob("*.desktop"):
        os.chown(path, sciberget.pw_uid, sciberget.pw_gid)
        path.chmod(0o755)
    for path in LIBFM_CONFIGS:
        if path.exists() and path.is_relative_to(Path("/home/sciberget")):
            for item in (path.parent, path):
                os.chown(item, sciberget.pw_uid, sciberget.pw_gid)


if __name__ == "__main__":
    main()
