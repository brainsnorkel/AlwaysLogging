#!/usr/bin/env python3
"""Manifest integrity checks for an ESO addon.

The game is unforgiving here and fails silently: a file missing from the
manifest is simply never loaded, and a folder whose name does not match the
manifest makes the whole addon invisible in the add-ons list. Both have
already cost us a debugging session, so they are checked here.
"""
import os
import re
import sys

REQUIRED_DIRECTIVES = ["Title", "Author", "Version", "AddOnVersion", "APIVersion", "SavedVariables"]
LOADABLE_SUFFIXES = (".lua", ".xml")
# Directories whose contents the game never loads.
EXCLUDED_DIRS = {".git", ".github", ".githooks", "tests"}

errors = []
warnings = []


def fail(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


def find_manifest(root):
    manifests = [f for f in os.listdir(root)
                 if f.endswith(".txt") and os.path.isfile(os.path.join(root, f))
                 and not f.upper().startswith("README")]
    if len(manifests) != 1:
        fail(f"expected exactly one manifest .txt in the addon root, found {sorted(manifests)}")
        return None
    return manifests[0]


def loadable_files_on_disk(root):
    found = set()
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDED_DIRS]
        for name in filenames:
            if name.endswith(LOADABLE_SUFFIXES):
                rel = os.path.relpath(os.path.join(dirpath, name), root)
                found.add(rel.replace(os.sep, "/"))
    return found


def main():
    root = os.getcwd()
    manifest = find_manifest(root)
    if manifest is None:
        report()
        return

    addon_name = manifest[:-4]
    folder_name = os.path.basename(root)
    if folder_name != addon_name:
        fail(f"folder name '{folder_name}' must match the manifest name '{addon_name}' "
             f"or the game will not load the addon")

    with open(os.path.join(root, manifest), "rb") as f:
        raw = f.read()
    if b"\r\n" not in raw:
        warn(f"{manifest} has no CRLF line endings; ESO manifests conventionally use them")
    text = raw.decode("utf-8-sig", errors="replace")

    directives = {}
    listed = []
    for lineno, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith(("##", ";", "#")):
            m = re.match(r"^##\s*([A-Za-z]+)\s*:\s*(.*)$", stripped)
            if m:
                directives[m.group(1)] = m.group(2).strip()
            continue
        listed.append((stripped.replace("\\", "/"), lineno))

    for key in REQUIRED_DIRECTIVES:
        if key not in directives:
            fail(f"{manifest} is missing the '## {key}:' directive")

    api = directives.get("APIVersion", "")
    if api:
        for token in api.split():
            if not re.fullmatch(r"\d{6}", token):
                fail(f"{manifest}: APIVersion '{token}' is not a six digit number")
    if directives.get("AddOnVersion") and not directives["AddOnVersion"].isdigit():
        fail(f"{manifest}: AddOnVersion must be an integer, got '{directives['AddOnVersion']}'")

    listed_paths = set()
    for path, lineno in listed:
        if not path.endswith(LOADABLE_SUFFIXES):
            fail(f"{manifest}:{lineno}: '{path}' is listed for loading but the game "
                 f"only loads .lua and .xml files")
            continue
        listed_paths.add(path)
        if "$(language)" in path:
            continue
        if not os.path.isfile(os.path.join(root, path)):
            fail(f"{manifest}:{lineno}: '{path}' is listed but does not exist on disk")

    on_disk = loadable_files_on_disk(root)
    for path in sorted(on_disk - listed_paths):
        fail(f"'{path}' exists but is not listed in {manifest}, so the game will never load it")

    print(f"manifest: {manifest}  addon: {addon_name}  files listed: {len(listed_paths)}")
    report()


def report():
    for w in warnings:
        print(f"::warning:: {w}")
    if errors:
        for e in errors:
            print(f"::error:: {e}")
        print(f"\n{len(errors)} manifest problem(s)")
        sys.exit(1)
    print("manifest checks passed")
    sys.exit(0)


if __name__ == "__main__":
    main()
