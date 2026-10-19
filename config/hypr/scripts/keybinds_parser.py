#!/usr/bin/env python3
import json
import os
import re
import sys


def normalize_combo(combo):
    combo = combo.replace(" ", "").replace("\t", "")
    combo = combo.replace("mainMod", "SUPER")
    combo = combo.replace('"', "").replace("'", "")
    combo = combo.replace("..", "")
    return combo


def extract_conf_combo(line):
    rhs = line.split("=", 1)[1]
    parts = [p.strip() for p in rhs.split(",")]
    if len(parts) < 2:
        return None
    return f"{parts[0]},{parts[1]}"


def extract_lua_bind(line):
    match = re.match(r"^\s*hl\.bind\(\s*(.*?)\s*,", line, re.DOTALL)
    if not match:
        return None
    return normalize_combo(match.group(1))


def parse_file(path):
    with open(path, "r", encoding="utf-8", errors="strict") as handle:
        raw_lines = handle.readlines()

    idx = 0
    total = len(raw_lines)
    while idx < total:
        line = raw_lines[idx].rstrip("\n")
        idx += 1
        stripped = line.lstrip()
        if not line or stripped.startswith("#") or stripped.startswith("--"):
            continue
        if re.match(r"^\s*bind[a-z]*\s*=", line):
            combo = extract_conf_combo(line)
            if combo:
                yield normalize_combo(combo), line
            continue
        if re.match(r"^\s*hl\.bind\(", line):
            combined = line
            balance = line.count("(") - line.count(")")
            while balance > 0 and idx < total:
                next_line = raw_lines[idx].strip()
                idx += 1
                if next_line.startswith("--"):
                    continue
                combined = f"{combined} {next_line}"
                balance += next_line.count("(") - next_line.count(")")
            if ".. code" in combined and ".. key" in combined:
                for i in range(1, 11):
                    key = i % 10
                    code = 9 + (10 if i == 10 else i)
                    expanded = re.sub(r'(["\'])\s*\.\.\s*code', f"{code}\\1", combined)
                    expanded = re.sub(r'(["\'])\s*\.\.\s*key', f"{key}\\1", expanded)
                    expanded = re.sub(r"\bworkspace\s*=\s*i\b", f"workspace = {i}", expanded)
                    combo = extract_lua_bind(expanded)
                    if combo:
                        yield combo, expanded
                continue
            combo = extract_lua_bind(combined)
            if combo:
                yield combo, combined


def parse_files(files):
    binding_map = {}
    source_map = {}
    user_conf_path = files[-1] if len(files) > 1 else None

    for file_path in files:
        try:
            entries = list(parse_file(file_path))
        except (OSError, UnicodeError) as exc:
            print(f"Error reading {file_path}: {exc}", file=sys.stderr)
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
        lua_match = re.match(
            r'^\s*hl\.bind\(\s*(.*?)\s*,\s*.*?,\s*\{[^{}]*?description\s*=\s*(["\'])(.*?)\2',
            line,
            re.DOTALL,
        )
        if lua_match:
            formatted_lines.append(
                f"{normalize_combo(lua_match.group(1))} — {lua_match.group(3)}"
            )
            continue

        match = re.match(r"^\s*(bind[a-z]*)\s*=(.*)", line)
        if not match:
            continue
        binder = match.group(1).replace(" ", "").replace("\t", "")
        parts = [p.strip() for p in match.group(2).strip().split(",")]
        if len(parts) < 2:
            continue
        mods, key = parts[0], parts[1]
        has_desc = "d" in binder and binder != "bind"
        desc = parts[2] if has_desc and len(parts) >= 3 else ""
        dispatcher = (
            parts[3]
            if has_desc and len(parts) >= 4
            else (parts[2] if len(parts) >= 3 else "")
        )
        params = ", ".join(p for p in parts[(4 if has_desc else 3) :] if p)
        mods = mods.replace("$mainMod", "SUPER")
        mods = re.sub(r"[ \t]+", "+", mods)
        combo = f"{mods}+{key}" if mods and key else (key or mods)
        if has_desc and desc:
            formatted_lines.append(f"{combo} — {desc}")
        elif dispatcher:
            formatted_lines.append(
                f"{combo} — {dispatcher}{(' ' + params) if params else ''}"
            )
        else:
            formatted_lines.append(combo)
    return formatted_lines


def main():
    args = sys.argv[1:]
    if not args:
        return
    if len(args) >= 2 and args[0] == "--path":
        target_files = [p for p in args[1:] if p and os.path.isfile(p)]
        binds, _ = parse_files(target_files) if target_files else ([], {})
        children = []
        for entry in format_for_rofi(binds):
            if " — " in entry:
                combo, desc = entry.split(" — ", 1)
            else:
                combo, desc = entry, ""
            parts = [p for p in combo.split("+") if p]
            mods = parts[:-1] if len(parts) > 1 else []
            key = parts[-1] if parts else combo
            children.append(
                {
                    "mods": mods,
                    "key": key,
                    "comment": desc,
                }
            )
        print(json.dumps({"children": children}))
        return

    binds, _ = parse_files(args)
    if not binds:
        print("no keybinds found.")
        raise SystemExit(1)
    for line in format_for_rofi(binds):
        print(line)


if __name__ == "__main__":
    main()
