#!/usr/bin/env python3
import os
import re
import sys


def normalize_combo(combo):
    return combo.replace(" ", "").replace("\t", "")


def extract_conf_combo(line):
    rhs = line.split("=", 1)[1]
    parts = [p.strip() for p in rhs.split(",")]
    if len(parts) < 2:
        return None
    return f"{parts[0]},{parts[1]}"


def extract_lua_bind(line):
    match = re.match(r'^\s*hl\.bind\(\s*(["\'])(.*?)\1\s*,', line)
    if not match:
        return None
    combo = match.group(2).replace("..", "")
    combo = combo.replace('" + "', "+").replace("' + '", "+")
    combo = combo.replace("mainMod", "SUPER")
    return combo


def parse_file(path):
    with open(path, "r", encoding="utf-8", errors="strict") as handle:
        for raw in handle:
            line = raw.rstrip("\n")
            if not line or line.lstrip().startswith("#") or line.lstrip().startswith("--"):
                continue
            if re.match(r'^\s*bind[a-z]*\s*=', line):
                combo = extract_conf_combo(line)
                if combo:
                    yield normalize_combo(combo), line
                continue
            combo = extract_lua_bind(line)
            if combo:
                yield normalize_combo(combo), line


def parse_files(files):
    binding_map = {}
    source_map = {}
    user_conf_path = files[-1] if len(files) > 1 else None

    for file_path in files:
        try:
            entries = list(parse_file(file_path))
        except OSError as exc:
            print(f"Error reading {file_path}: {exc}", file=sys.stderr)
            continue
        except UnicodeError as exc:
            print(f"Error decoding {file_path}: {exc}", file=sys.stderr)
            continue

        for combo, line in entries:
            is_user_file = file_path == user_conf_path
            if is_user_file or combo not in binding_map:
                binding_map[combo] = line
                source_map[combo] = file_path

    return list(binding_map.values()), source_map


def format_for_rofi(raw_binds):
    formatted_lines = []
    for line in raw_binds:
        lua_match = re.match(r'^\s*hl\.bind\(\s*(["\'])(.*?)\1\s*,\s*.*?,\s*\{\s*description\s*=\s*(["\'])(.*?)\3', line)
        if lua_match:
            combo = lua_match.group(2).replace("mainMod", "SUPER")
            formatted_lines.append(f"{normalize_combo(combo)} — {lua_match.group(4)}")
            continue

        match = re.match(r'^\s*(bind[a-z]*)\s*=(.*)', line)
        if not match:
            continue
        binder = match.group(1).replace(" ", "").replace("\t", "")
        parts = [p.strip() for p in match.group(2).strip().split(",")]
        if len(parts) < 2:
            continue
        mods, key = parts[0], parts[1]
        has_desc = "d" in binder and binder != "bind"
        desc = parts[2] if has_desc and len(parts) >= 3 else ""
        dispatcher = parts[3] if has_desc and len(parts) >= 4 else (parts[2] if len(parts) >= 3 else "")
        params = ", ".join(p for p in parts[(4 if has_desc else 3):] if p)
        mods = mods.replace("$mainMod", "SUPER")
        mods = re.sub(r"[ \t]+", "+", mods)
        combo = f"{mods}+{key}" if mods and key else (key or mods)
        if has_desc and desc:
            formatted_lines.append(f"{combo} — {desc}")
        elif dispatcher:
            formatted_lines.append(f"{combo} — {dispatcher}{(' ' + params) if params else ''}")
        else:
            formatted_lines.append(combo)
    return formatted_lines


def main():
    files = sys.argv[1:]
    if not files:
        return
    binds, _ = parse_files(files)
    if not binds:
        print("no keybinds found.")
        raise SystemExit(1)
    for line in format_for_rofi(binds):
        print(line)


if __name__ == "__main__":
    main()
