#!/usr/bin/env python3
"""
golden_unit_hash.py v2.2.0 — Named-unit hashing and four-way classification
for the Golden-Unit Protocol v5.3.

WHAT THIS SCRIPT DOES
---------------------
Implements §1 (atomization) and the hashing half of §2/§3 ONLY.

It deliberately does NOT attempt:
  - The digest comparison in §3 ("does the new digest semantically contain
    everything the old one guaranteed?")
  - The architectural gate in §4

Both of those require reading and judgment, not string comparison. The protocol
is explicit that collapsing them into the hash check is itself a violation (§3,
final paragraph). The model performs those steps; this script only produces the
MISSING / UNCHANGED / CHANGED / NEW skeleton for it to reason over.

WHAT IS NEW IN v2.2.0 (GUP v5.3 — MANDATORY ATOMIZER MITIGATION)
----------------------------------------------------------------
The atomizer is now LEXICALLY CONTEXT-AWARE before structural brace
accounting.  The scanner runs a per-language lexical dispatch:

    SOURCE
      |
      v
    LEXICAL DISPATCH
      |
      +-- # comment -------> consume to newline
      |                       apostrophes inert
      |                       braces inert
      +-- quoted string ---> consume according to quote/escape rules
      |                       braces inert
      +-- regex literal ---> consume regex body according to regex/escape rules
      |                       quotes inert
      |                       braces inert
      +-- ordinary code ---> structural brace accounting

CRITICAL INVARIANT (GUP v5.3):

    Only syntactically active code may modify structural brace depth.

Thus a comment such as

    # don't let this apostrophe change lexical state { }

must remain structurally neutral, and regex content such as

    [[ "$x" =~ /['"{]foo['"}]/ ]]

must not leak its quote or brace characters into the surrounding scanner
state.  v2.1.0 violated this invariant: comments were not lexical states at
all (an apostrophe inside a comment opened a phantom string that swallowed
the rest of the file — wave.js lost 100% of its units this way), regex
literals leaked quotes and braces into the scanner (any function containing
/['"{]foo['"}]/ silently vanished), per-line brace counting used raw
line.count('{') including inert regions, and method detection matched
keywords (`if (…) {` inside a class produced a bogus `ClassName.if` unit).
All of these are mitigated in v2.2.0 by the lexical dispatch above.

Additional v2.2.0 changes:
- Bash / POSIX shell is now a first-class extraction language (functions are
  the natural units), with a full bash lexical profile: `#` comments,
  single/double quotes with their distinct escape rules, `$'…'` ANSI-C and
  `$"…"` locale quoting, backticks, `$(` / `$((` command and arithmetic
  substitution, `${…}` parameter expansion, brace groups, brace expansion,
  `<<`/`<<-`/`<<'DELIM'` heredocs (body fully inert), and `[[ … =~ regex ]]`
  unquoted regex literals consumed with quotes and braces inert per the
  invariant above.
- JS/TS extraction now recovers unit spans from scanner events, so braces
  inside strings, comments, template-literal text and regexes can never
  corrupt unit boundaries; template `${…}` interpolations count as active
  code (their delimiters form a balanced pair, so enclosing scopes stay
  correct); multiline function signatures and class bodies whose brace opens
  on the following line are now found; declaration keywords (if/for/while/
  switch/catch/with…) can never be claimed as method names.
- --selftest runs the invariant battery (including the two examples above,
  verbatim) and exits non-zero on any violation.
- Python extraction is unchanged: the stdlib `ast` module is lexically
  correct by construction.

UNIT IDENTITY
-------------
Units are identified by NAME, never by position. A line-range window (e.g.
"lines 501-1000") is exactly the anti-pattern §1 rules out, so this script
refuses to fall back to fixed-size segmentation. If a language has no parser
support here, units must be supplied manually as named blocks (see
--manual-units below).

SUPPORTED AUTOMATIC EXTRACTION
--------------------------------
  Python    — via the stdlib `ast` module; names are exact, spans are taken
              from the original source line numbers (no re-serialization, which
              would normalize whitespace/comments and silently change the hash
              basis).
  JS / TS   — via the v5.3 lexically context-aware scanner (comments, string
              literals, template literals and regex literals are consumed by
              their own lexical rules BEFORE any brace accounting) anchored on
              a conservative set of declaration patterns.
  Bash / sh — via the v5.3 bash lexical profile; `name() { … }` and
              `function name { … }` bodies are recovered from scanner events.

For any other domain (prose claims, math lemmas, contract clauses, data
schemas), supply units manually as a JSON list:
  [{"name": "Lemma 3.2", "content": "..."}]
via --manual-units <file.json>.

USAGE
-----
  # Auto-extract units from a baseline and a candidate file, compare:
  python3 golden_unit_hash.py --baseline old.py --candidate new.py

  # Just produce a manifest for one file (no comparison):
  python3 golden_unit_hash.py --baseline old.py --manifest-only

  # Bash (auto-detected from .sh/.bash extension or a bash shebang):
  python3 golden_unit_hash.py --baseline ffx --manifest-only

  # Run the GUP v5.3 invariant battery:
  python3 golden_unit_hash.py --selftest

  # Manual units (any domain):
  python3 golden_unit_hash.py --manual-units baseline_units.json \\
                               --manual-units-candidate candidate_units.json

OUTPUT
------
JSON to stdout with the manifest(s) and, if both sides are given, a per-unit
verdict list. The model reads this and fills in digest, class, and the §4 gate
— this script never invents those fields.

Exit codes:
  0  — no MISSING units (NEW units present but not a hard-fail at script level)
  1  — one or more MISSING units detected (hard fail), or selftest failure

Note: NEW units exit 0 because whether a NEW unit is acceptable depends on the
§4 architectural gate, which requires model judgment. They are surfaced to
stderr so a CI pipeline can capture and route them for review.
"""

import argparse
import ast
import hashlib
import json
import sys
from bisect import bisect_right
from typing import Dict, List, Optional, Tuple

__version__ = "2.2.0"
GUP_PROTOCOL = "GUP v5.3"


# ---------------------------------------------------------------------------
# Hashing
# ---------------------------------------------------------------------------

def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def ensure_unique_unit_ids(units: Dict[str, str], side: str) -> None:
    """Reject duplicate stable identities before any comparison is trusted."""
    if len(units) != len(set(units)):
        raise ValueError(f"duplicate stable unit identity in {side} manifest")


# ---------------------------------------------------------------------------
# Python extraction — uses the real ast module, so names are exact and spans
# are taken from the original source via line numbers (no re-serialization,
# which would normalize whitespace/comments and silently change the hash
# basis).  Unchanged from v5.2: `ast` is already lexically correct, so the
# v5.3 atomizer mitigation does not touch it.
# ---------------------------------------------------------------------------

def extract_python_units(source: str) -> Dict[str, str]:
    tree = ast.parse(source)
    lines = source.splitlines(keepends=True)
    units: Dict[str, str] = {}

    def span_text(node) -> str:
        start = node.lineno - 1
        end = getattr(node, "end_lineno", node.lineno)
        return "".join(lines[start:end])

    def qualified_name(node, prefix: str) -> str:
        return f"{prefix}{node.name}" if prefix else node.name

    def walk(node, prefix: str = "") -> None:
        for child in ast.iter_child_nodes(node):
            if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)):
                name = qualified_name(child, prefix)
                units[name] = span_text(child)
                walk(child, prefix=f"{name}.")
            elif isinstance(child, ast.ClassDef):
                name = qualified_name(child, prefix)
                units[name] = span_text(child)
                walk(child, prefix=f"{name}.")
            else:
                walk(child, prefix=prefix)

    walk(tree)
    ensure_unique_unit_ids(units, "python")
    return units


# ===========================================================================
# GUP v5.3 LEXICAL DISPATCH ENGINE
#
# The invariant enforced by every scanner below:
#
#     Only syntactically active code may modify structural brace depth.
#
# Each scanner walks the source once through a per-language lexical dispatch
# (comment / quoted string / regex literal / ordinary code) and emits ONLY
# the structural events found in ordinary code.  Inert regions are consumed
# whole, so apostrophes, quotes and braces inside them can never leak into
# the surrounding scanner state.
# ===========================================================================


# ---------------------------------------------------------------------------
# JS / TS lexical profile
# ---------------------------------------------------------------------------

# Words after which a `/` starts a regex literal rather than division.
_JS_REGEX_KEYWORDS = frozenset((
    "return", "case", "typeof", "instanceof", "in", "of", "new", "delete",
    "void", "do", "else", "yield", "await", "throw",
))


def _js_regex_allowed(last_kind: str, last_word: str) -> bool:
    """Regex-vs-division disambiguation for the `/` operator.

    A `/` may open a regex literal when the previous significant token cannot
    end an expression: file start, an opening punctuation char, or one of the
    keywords above.  After an identifier, number, closing paren/bracket,
    string, template or postfix ++/-- it is division.
    """
    if last_kind == "":
        return True
    if last_kind == "word":
        return last_word in _JS_REGEX_KEYWORDS
    if last_kind in ("string", "template"):
        return False
    # last_kind is the literal punctuation token (single char, or '++'/'--')
    if last_kind in (")", "]", "++", "--"):
        return False
    return True


def scan_js(source: str) -> dict:
    """Lexically context-aware scan of JS/TS source.

    Returns a dict:
      braces    — ordered [(index, '{' | '}')] for braces in ordinary code.
                  Template `${` and its closing `}` are emitted as a balanced
                  pair: interpolation contents are active code, and the pair
                  nets to zero inside the enclosing scope, so unit matching
                  stays exact.
      parens    — ordered [(index, '(' | ')')] for parens in ordinary code.
      warnings  — human-readable notes for unterminated constructs.

    Lexical dispatch: `//` and `/* */` comments are consumed whole (apostrophes
    and braces inert); '…', "…" and `…` strings are consumed per their escape
    rules (braces inert); regex literals — including char classes — are
    consumed per regex escape rules (quotes and braces inert); template
    literal text is inert while `${…}` interpolation bodies recurse into
    ordinary code.
    """
    braces: List[Tuple[int, str]] = []
    parens: List[Tuple[int, str]] = []
    warnings: List[str] = []
    n = len(source)
    i = 0
    # Frame stack for template literals: ('tpl',) while inside `…` text,
    # ('interp', [depth]) while inside an ordinary-code ${…} body.
    stack: list = []
    last_kind = ""      # '', 'word', 'string', 'template', or punct token
    last_word = ""

    while i < n:
        ch = source[i]
        top = stack[-1] if stack else None

        if top is not None and top[0] == "tpl":
            if ch == "\\":
                i += 2
                continue
            if ch == "`":
                stack.pop()
                last_kind = "template"
                last_word = ""
                i += 1
                continue
            if ch == "$" and i + 1 < n and source[i + 1] == "{":
                # Interpolation: active code.  The delimiters form a balanced
                # brace pair (net zero for the enclosing scope).
                braces.append((i + 1, "{"))
                stack.append(("interp", [0]))
                i += 2
                continue
            i += 1
            continue

        # ---- ordinary code (top-level or inside an interpolation) ----
        if ch == "/" and i + 1 < n and source[i + 1] == "/":
            j = source.find("\n", i)
            i = n if j == -1 else j
            continue

        if ch == "/" and i + 1 < n and source[i + 1] == "*":
            j = source.find("*/", i + 2)
            if j == -1:
                warnings.append(f"unterminated block comment at offset {i}")
                i = n
            else:
                i = j + 2
            continue

        if ch == "'" or ch == '"':
            j = i + 1
            while j < n:
                c = source[j]
                if c == "\\":
                    j += 2
                    continue
                if c == ch:
                    break
                if c == "\n":
                    # Raw newline: not a legal string body — end the "string"
                    # here so the rest of the file stays scannable.
                    break
                j += 1
            if j >= n:
                warnings.append(f"unterminated string at offset {i}")
                i = n
            elif source[j] == "\n":
                warnings.append(f"string not closed before newline at offset {i}")
                i = j
            else:
                i = j + 1
            last_kind = "string"
            last_word = ""
            continue

        if ch == "`":
            stack.append(("tpl",))
            i += 1
            continue

        if ch == "/":
            if _js_regex_allowed(last_kind, last_word):
                # Consume a regex literal per regex/escape rules.  A regex
                # body cannot contain a raw newline; if we hit one, this was
                # division after all and we fall through untouched.
                j = i + 1
                in_class = False
                closed = -1
                while j < n:
                    c = source[j]
                    if c == "\\":
                        j += 2
                        continue
                    if c == "\n":
                        break
                    if in_class:
                        if c == "]":
                            in_class = False
                    elif c == "[":
                        in_class = True
                    elif c == "/":
                        closed = j
                        break
                    j += 1
                if closed != -1:
                    i = closed + 1
                    while i < n and (source[i].isalnum() or source[i] in "_$"):
                        i += 1  # regex flags
                    last_kind = "word"
                    last_word = ""  # flags behave like a non-keyword word
                    continue
            last_kind = "/"
            last_word = ""
            i += 1
            continue

        if ch == "{":
            braces.append((i, "{"))
            if top is not None and top[0] == "interp":
                top[1][0] += 1
            last_kind = "{"
            last_word = ""
            i += 1
            continue

        if ch == "}":
            if top is not None and top[0] == "interp":
                if top[1][0] == 0:
                    # Closes the ${ … } interpolation: balanced with its open.
                    braces.append((i, "}"))
                    stack.pop()
                    i += 1
                    continue
                top[1][0] -= 1
            braces.append((i, "}"))
            last_kind = "}"
            last_word = ""
            i += 1
            continue

        if ch == "(":
            parens.append((i, "("))
            last_kind = "("
            last_word = ""
            i += 1
            continue

        if ch == ")":
            parens.append((i, ")"))
            last_kind = ")"
            last_word = ""
            i += 1
            continue

        if ch.isalnum() or ch in "_$":
            j = i
            while j < n and (source[j].isalnum() or source[j] in "_$."):
                j += 1
            last_kind = "word"
            last_word = source[i:j]
            i = j
            continue

        if ch in " \t\r\n":
            i += 1
            continue

        # Operators / punctuation.  Track ++ and -- so a following `/` is
        # treated as division (postfix), never as a regex opener.
        if ch in "+-" and last_kind == ch:
            last_kind = ch * 2
            i += 1
            continue
        if ch in "+-":
            last_kind = ch
            i += 1
            continue
        last_kind = ch
        last_word = ""
        i += 1
        continue

    if stack:
        warnings.append(
            "unterminated template literal (backtick) at end of source"
        )
    return {"braces": braces, "parens": parens, "warnings": warnings}


def _pair_events(events: List[Tuple[int, str]]) -> Tuple[dict, dict]:
    """Match open/close events into pairs via one stack pass.

    Returns (pairs, unmatched_close_count) where pairs maps open index ->
    close index.  Balanced active-code events pair exactly; leftovers are
    reported so the caller can warn instead of guessing.
    """
    pairs: Dict[int, int] = {}
    stack: List[int] = []
    unmatched = 0
    for idx, ch in events:
        if ch in "{(":
            stack.append(idx)
        else:
            if stack:
                pairs[stack.pop()] = idx
            else:
                unmatched += 1
    return pairs, unmatched


def _line_offsets(source: str) -> Tuple[List[str], List[int]]:
    lines = source.splitlines(keepends=True)
    offsets = [0]
    for line in lines:
        offsets.append(offsets[-1] + len(line))
    return lines, offsets


def _line_of(offsets: List[int], idx: int) -> int:
    return max(0, bisect_right(offsets, idx) - 1)


# ---------------------------------------------------------------------------
# JS/TS unit extraction — anchored on the same conservative declaration
# patterns as v5.2, but every brace decision now comes from scanner events,
# so inert braces can never corrupt a boundary.
# ---------------------------------------------------------------------------

import re

_JS_FUNCTION_PATTERN = re.compile(
    r"^\s*(?:export\s+)?(?:async\s+)?function\s+([A-Za-z_$][\w$]*)\s*\("
)
_JS_CLASS_PATTERN = re.compile(
    r"^\s*(?:export\s+)?class\s+([A-Za-z_$][\w$]*)\b"
)
_JS_ARROW_CONST_PATTERN = re.compile(
    r"^\s*(?:export\s+)?(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*"
    r"(?:async\s*)?(?:\([^)]*\)|[A-Za-z_$][\w$]*)\s*=>\s*\{"
)
_JS_METHOD_PATTERN = re.compile(
    r"^\s*(?:async\s+)?([A-Za-z_$][\w$]*)\s*\([^)]*\)\s*\{"
)

# Declaration keywords can never be method names (v2.2.0 mitigation: the
# v2.1.0 scanner emitted bogus `ClassName.if` / `ClassName.for` units).
_JS_RESERVED = frozenset((
    "if", "for", "while", "switch", "catch", "with", "return", "function",
    "typeof", "new", "delete", "void", "in", "of", "do", "else", "try",
    "await", "yield", "throw", "case", "default", "var", "let", "const",
    "class", "extends", "import", "export", "break", "continue", "label",
))


def extract_js_units(source: str) -> Dict[str, str]:
    """Scan top-down, tracking which class (if any) the current line falls
    inside via STRUCTURAL brace depth (scanner events, never raw
    line.count), so methods are recorded as 'ClassName.method' and inert
    braces in comments/strings/regexes can no longer corrupt the scope.
    """
    scan = scan_js(source)
    brace_pairs, unmatched_close = _pair_events(scan["braces"])
    paren_pairs, _ = _pair_events(scan["parens"])
    open_positions = sorted(brace_pairs)
    warnings = list(scan["warnings"])
    if unmatched_close:
        warnings.append(f"{unmatched_close} unmatched closing brace(s)")

    lines, offsets = _line_offsets(source)

    # Net structural brace delta per line, from events only.
    line_delta = [0] * len(lines)
    for idx, ch in scan["braces"]:
        line_delta[_line_of(offsets, idx)] += 1 if ch == "{" else -1

    def next_open_brace(abs_pos: int) -> Optional[int]:
        """First structural open brace at or after abs_pos."""
        k = bisect_right(open_positions, abs_pos - 1)
        return open_positions[k] if k < len(open_positions) else None

    units: Dict[str, str] = {}
    class_stack: List[Tuple[str, int]] = []
    depth = 0

    for line_no, line in enumerate(lines):
        current_class = class_stack[-1][0] if class_stack else ""

        class_m = _JS_CLASS_PATTERN.match(line)
        if class_m:
            name = class_m.group(1)
            # Class body brace: first structural open after the class name —
            # works for `class A {`, `class A extends B {` and `class A\\n{`.
            open_idx = next_open_brace(offsets[line_no] + class_m.end())
            if open_idx is not None and open_idx in brace_pairs:
                qualified = f"{current_class}.{name}" if current_class else name
                units.setdefault(
                    qualified, source[offsets[line_no]:brace_pairs[open_idx] + 1]
                )
                class_stack.append((qualified, depth))
            depth += line_delta[line_no]
            continue

        matched = False
        for pattern, is_method_shorthand in (
            (_JS_FUNCTION_PATTERN, False),
            (_JS_ARROW_CONST_PATTERN, False),
            (_JS_METHOD_PATTERN, True),
        ):
            m = pattern.match(line)
            if not m:
                continue
            # Method shorthand only counts inside a class body; otherwise
            # it's ambiguous with object-literal methods and other syntax
            # this script doesn't attempt to disambiguate.
            if is_method_shorthand and not current_class:
                continue
            name = m.group(1)
            if is_method_shorthand and name in _JS_RESERVED:
                continue  # `if (…) {` etc. are not methods.
            if pattern is _JS_FUNCTION_PATTERN:
                # Signature: match the `(`, find its structural `)`, then the
                # first structural `{` after it.  Handles multiline
                # signatures and destructured/default parameters.
                paren_open = offsets[line_no] + (m.end() - 1)
                paren_close = paren_pairs.get(paren_open)
                if paren_close is None:
                    continue
                open_idx = next_open_brace(paren_close + 1)
            else:
                # Arrow/method patterns end with the body `{` on this line.
                cand = offsets[line_no] + m.end() - 1
                open_idx = cand if cand in brace_pairs else next_open_brace(
                    offsets[line_no] + m.end()
                )
            if open_idx is None or open_idx not in brace_pairs:
                continue
            unit_text = source[offsets[line_no]:brace_pairs[open_idx] + 1]
            qualified = (
                f"{current_class}.{name}"
                if (is_method_shorthand and current_class)
                else name
            )
            units.setdefault(qualified, unit_text)
            matched = True
            break

        depth += line_delta[line_no]
        if matched:
            continue

        # Pop class scope once we've closed back past the class's own depth.
        while class_stack and depth <= class_stack[-1][1]:
            class_stack.pop()

    if warnings:
        for w in warnings:
            print(f"[gup atomizer] warning: {w}", file=sys.stderr)

    return units


# ---------------------------------------------------------------------------
# Bash / POSIX shell lexical profile
#
# Function bodies (`name() { … }`, `function name { … }`) are the structural
# units.  Everything else that can contain braces — comments, every quoting
# form, ${…} parameter expansion, brace expansion, brace groups, heredoc
# bodies, and `[[ … =~ regex ]]` literals — is consumed by its own lexical
# rules and is structurally neutral.
# ---------------------------------------------------------------------------

_BASH_WORD_START_PREV = frozenset(" \t\n;|&(){}")
_BASH_CMDPOS_PREV = frozenset("\n;&|)")


def _bash_word_start(source: str, i: int) -> bool:
    """True when the char at i starts a new word (comment `#`, `[[`, `{`)."""
    if i == 0:
        return True
    return source[i - 1] in _BASH_WORD_START_PREV


def _bash_command_position(source: str, i: int) -> bool:
    """True when a `}` at i stands where a command could start — the only
    position where bash accepts it as a closing brace for a group/function."""
    j = i - 1
    while j >= 0 and source[j] in " \t":
        j -= 1
    if j < 0:
        return True
    return source[j] in _BASH_CMDPOS_PREV


def _bash_func_decl_name(tokens: list) -> Optional[str]:
    """Recover a function declaration name from the recent token window.

    `name ( )` (plain parens — subshell/arith parens emit 'sub' and cannot
    masquerade as a declaration) or `function name`.
    """
    t = tokens[-3:] if len(tokens) >= 3 else tokens[:]
    if len(t) == 3 and t[0][0] == "w" and t[1] == "(" and t[2] == ")":
        return t[0][1]
    if len(t) >= 2 and t[-2][0] == "w" and t[-2][1] == "function" and t[-1][0] == "w":
        return t[-1][1]
    return None


def scan_bash(source: str) -> dict:
    """Lexically context-aware scan of bash source.

    Returns a dict:
      functions — [(name, open_brace_index, close_brace_index)] for every
                  `name() { … }` / `function name { … }` body.
      warnings  — human-readable notes for unterminated constructs.

    Lexical dispatch per the GUP v5.3 invariant:
      * `#` comment (word-start only) — consumed to newline; apostrophes and
        braces inert.
      * '…' — no escapes at all; "…" and `…` — backslash escapes the next
        char; $'…' / $"…" — ANSI-C / locale quoting.
      * ${…} parameter expansion and {a,b} / {1..n} brace expansion —
        self-contained; braces inert.
      * <<, <<- and <<'DELIM' heredocs — body consumed whole (fully inert).
      * $( … ) and $(( … )) substitution — contents follow ordinary rules;
        their parens never impersonate a `name()` declaration.
      * [[ … =~ regex ]] — the unquoted regex body is consumed per
        regex/escape rules: quotes and braces inert, nothing leaks.
      * { cmd; } brace groups — consumed as self-contained groups; only a
        `}` at command position closes one.
      * Ordinary code — a small token window tracks `name ( )` sequences;
        only those open structural function frames.
    """
    functions: List[Tuple[str, int, int]] = []
    warnings: List[str] = []
    n = len(source)
    i = 0
    stack: list = []          # frames: sq/dq/bt/ansi/locale/heredoc/expansion/group/function/dbracket
    substack: List[int] = []  # $() / $(()) nesting depth counters
    tokens: list = []         # recent significant tokens

    def tok(t):
        tokens.append(t)
        del tokens[:-4]

    while i < n:
        ch = source[i]
        top = stack[-1] if stack else None

        # ---- inert frames ----
        if top is not None:
            kind = top[0]
            if kind == "sq":
                if ch == "'":
                    stack.pop()
                i += 1
                continue
            if kind in ("dq", "bt", "ansi", "locale"):
                if ch == "\\":
                    i += 2
                    continue
                closer = {"dq": '"', "bt": "`", "ansi": "'", "locale": '"'}[kind]
                if ch == closer:
                    stack.pop()
                i += 1
                continue
            if kind == "heredoc":
                # Consume lines until the delimiter line (tabs stripped for
                # <<−).  The body is fully inert.
                delim, dash = top[1], top[2]
                p = i
                closed = False
                while p <= n:
                    e2 = source.find("\n", p)
                    line = source[p:] if e2 == -1 else source[p:e2]
                    stripped = line.lstrip("\t") if dash else line
                    if stripped.rstrip() == delim:
                        closed = True
                        p = n if e2 == -1 else e2 + 1
                        break
                    if e2 == -1:
                        break
                    p = e2 + 1
                if not closed:
                    warnings.append(f"unterminated heredoc {delim!r}")
                    p = n
                stack.pop()  # body consumed — the frame is done either way
                i = p
                continue
            if kind == "expansion":
                # ${…} or {a,b}: self-contained; closes at the next `}`
                # regardless of surrounding context (braces inert).
                if ch == "}":
                    stack.pop()
                i += 1
                continue

        # ---- ordinary code (base / group / function / dbracket) ----
        if ch == "#" and _bash_word_start(source, i):
            j = source.find("\n", i)
            i = n if j == -1 else j
            continue

        if ch == "'":
            stack.append(("sq",))
            i += 1
            continue
        if ch == '"':
            stack.append(("dq",))
            i += 1
            continue
        if ch == "`":
            stack.append(("bt",))
            i += 1
            continue

        if ch == "$" and i + 1 < n:
            nxt = source[i + 1]
            if nxt == "'":
                stack.append(("ansi",))
                i += 2
                continue
            if nxt == '"':
                stack.append(("locale",))
                i += 2
                continue
            if nxt == "{":
                stack.append(("expansion",))
                i += 2
                continue
            if nxt == "(":
                k = i + 1
                while k < n and source[k] == "(":
                    k += 1
                substack.append(k - i - 1)
                tok("sub")
                i = k
                continue
            # $name / $1 / $$ / $? / $# / $@ … — one word token.
            j = i + 1
            if j < n and (source[j].isalnum() or source[j] == "_"):
                while j < n and (source[j].isalnum() or source[j] == "_"):
                    j += 1
            else:
                j += 1
            tok(("w", source[i:j]))
            i = j
            continue

        if ch == "[" and i + 1 < n and source[i + 1] == "[" and _bash_word_start(source, i):
            stack.append(("dbracket",))
            tok("op")
            i += 2
            continue
        if (
            ch == "]"
            and i + 1 < n
            and source[i + 1] == "]"
            and top is not None
            and top[0] == "dbracket"
        ):
            stack.pop()
            tok("op")
            i += 2
            continue
        if (
            ch == "="
            and i + 1 < n
            and source[i + 1] == "~"
            and top is not None
            and top[0] == "dbracket"
        ):
            # [[ … =~ regex ]] — consume the unquoted regex body per
            # regex/escape rules; quotes and braces are inert inside it.
            j = i + 2
            while j < n and source[j] in " \t":
                j += 1
            if j < n and source[j] in "'\"":
                # Quoted regex: ordinary quote state handles it (contents
                # inert), so just fall through to the quote handlers.
                i = j
                continue
            while j < n:
                c = source[j]
                if c == "\\" and j + 1 < n:
                    j += 2
                    continue
                if c in " \t\n":
                    break
                if c == "]" and j + 1 < n and source[j + 1] == "]":
                    break
                j += 1
            tok("op")
            i = j
            continue

        if ch == "<" and i + 1 < n and source[i + 1] == "<":
            if i + 2 < n and source[i + 2] == "<":
                i += 3  # herestring — an ordinary operator
                tok("op")
                continue
            # Heredoc: <<, <<- , <<DELIM, <<'DELIM', <<"DELIM".
            j = i + 2
            dash = False
            if j < n and source[j] == "-":
                dash = True
                j += 1
            quote = None
            if j < n and source[j] in "'\"":
                quote = source[j]
                j += 1
            k = j
            while k < n and (source[k].isalnum() or source[k] in "_-"):
                k += 1
            delim = source[j:k]
            if quote and k < n and source[k] == quote:
                k += 1
            if not delim:
                i = k if k > i else i + 2
                tok("op")
                continue
            eol = source.find("\n", k)
            if eol == -1:
                warnings.append(f"heredoc {delim!r} has no body")
                i = n
                continue
            stack.append(("heredoc", delim, dash))
            i = eol + 1
            continue

        if ch == "(":
            if substack:
                substack[-1] += 1
            else:
                tok("(")
            i += 1
            continue
        if ch == ")":
            if substack:
                substack[-1] -= 1
                if substack[-1] == 0:
                    substack.pop()
                    tok("sub")
            else:
                tok(")")
            i += 1
            continue

        if ch == "{":
            if _bash_word_start(source, i):
                name = _bash_func_decl_name(tokens)
                if name is not None:
                    stack.append(("function", name, i))
                    tok("sep")
                    i += 1
                    continue
                nxt = source[i + 1] if i + 1 < n else "\n"
                if nxt in " \t\n":
                    stack.append(("group",))  # { cmd; } compound group
                else:
                    stack.append(("expansion",))  # {a,b} brace expansion
            else:
                stack.append(("expansion",))  # attached expansion, e.g. a{1,2}
            tok("op")
            i += 1
            continue

        if ch == "}":
            if top is not None and top[0] in ("group", "function"):
                if _bash_command_position(source, i):
                    if top[0] == "function":
                        functions.append((top[1], top[2], i))
                    stack.pop()
                    tok("sep")
                    i += 1
                    continue
                # A literal `}` argument (e.g. `echo }`) — inert.
                i += 1
                continue
            # No open frame (or an expansion handled above): inert literal.
            i += 1
            continue

        if ch == "\\":
            i += 2  # escaped char / line continuation
            continue

        if ch in " \t\r\n":
            if ch == "\n":
                tok("sep")
            i += 1
            continue

        if ch in ";|&":
            tok("sep")
            i += 1
            continue

        if ch.isalnum() or ch in "_-":
            j = i
            while j < n and (source[j].isalnum() or source[j] in "_-"):
                j += 1
            tok(("w", source[i:j]))
            i = j
            continue

        tok("op")
        i += 1
        continue

    for frame in stack:
        if frame[0] == "function":
            warnings.append(
                f"function {frame[1]!r} opened at offset {frame[2]} never closed"
            )
        elif frame[0] in ("sq", "dq", "bt", "ansi", "locale"):
            warnings.append(f"unterminated {frame[0]} quote")
        elif frame[0] == "group":
            warnings.append("unterminated brace group")
        elif frame[0] == "dbracket":
            warnings.append("unterminated [[ ]] compound")
    return {"functions": functions, "warnings": warnings}


def extract_bash_units(source: str) -> Dict[str, str]:
    """Units are bash functions, named exactly as declared, qualified by
    nesting.  Spans run from the start of the declaration line to the closing
    brace, recovered from scanner events — so comments, quotes, heredoc
    bodies, parameter expansions and regex literals inside a body can never
    corrupt its boundary."""
    scan = scan_bash(source)
    lines, offsets = _line_offsets(source)
    units: Dict[str, str] = {}
    ordered = sorted(scan["functions"], key=lambda t: t[1])
    open_stack: List[Tuple[str, int, int]] = []
    for name, open_idx, close_idx in ordered:
        while open_stack and open_stack[-1][2] < open_idx:
            open_stack.pop()
        qualified = f"{open_stack[-1][0]}.{name}" if open_stack else name
        line_no = _line_of(offsets, open_idx)
        units.setdefault(qualified, source[offsets[line_no]:close_idx + 1])
        open_stack.append((name, open_idx, close_idx))
    ensure_unique_unit_ids(units, "bash")
    for w in scan["warnings"]:
        print(f"[gup atomizer] warning: {w}", file=sys.stderr)
    return units


# ---------------------------------------------------------------------------
# Manifest + diff
# ---------------------------------------------------------------------------

def build_manifest(units: Dict[str, str]) -> List[dict]:
    return [
        {"unit": name, "hash": sha256_text(content)}
        for name, content in sorted(units.items())
    ]


def extract_units(path: str, language: Optional[str]) -> Dict[str, str]:
    with open(path, "r", encoding="utf-8") as f:
        source = f.read()

    lang = language
    if lang is None:
        if path.endswith(".py"):
            lang = "python"
        elif path.endswith((".js", ".jsx", ".ts", ".tsx")):
            lang = "js"
        elif path.endswith((".sh", ".bash")):
            lang = "bash"
        else:
            # Fall back to the shebang, if any.
            first = source.split("\n", 1)[0]
            if first.startswith("#!"):
                if "bash" in first or first.endswith("sh") or "zsh" in first:
                    lang = "bash"
                elif "python" in first:
                    lang = "python"
                elif "node" in first:
                    lang = "js"
    if lang is None:
        raise ValueError(
            f"Cannot auto-detect language for '{path}'. Pass --language "
            f"explicitly (python|js|bash), or use --manual-units for non-code "
            f"domains (prose, math, schemas, contracts, etc.) since this "
            f"script only parses Python, JS/TS and Bash automatically."
        )

    if lang == "python":
        return extract_python_units(source)
    elif lang == "js":
        return extract_js_units(source)
    elif lang == "bash":
        return extract_bash_units(source)
    else:
        raise ValueError(f"Unsupported language: {lang!r}")


def load_manual_units(path: str) -> Dict[str, str]:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    units: Dict[str, str] = {}
    for entry in data:
        units[entry["name"]] = entry["content"]
    return units


def diff_manifests(
    baseline: Dict[str, str], candidate: Dict[str, str]
) -> List[dict]:
    all_names = sorted(set(baseline) | set(candidate))
    report = []
    for name in all_names:
        b = baseline.get(name)
        c = candidate.get(name)
        if b is not None and c is None:
            report.append({
                "unit": name,
                "verdict": "MISSING",
                "hash": sha256_text(b),
            })
        elif b is None and c is not None:
            report.append({
                "unit": name,
                "verdict": "NEW",
                "hash": sha256_text(c),
            })
        elif sha256_text(b) == sha256_text(c):
            report.append({
                "unit": name,
                "verdict": "UNCHANGED",
                "hash": sha256_text(b),
            })
        else:
            report.append({
                "unit": name,
                "verdict": "CHANGED",
                "baseline_hash": sha256_text(b),
                "candidate_hash": sha256_text(c),
            })
    return report


# ---------------------------------------------------------------------------
# GUP v5.3 selftest — the invariant battery
#
#     Only syntactically active code may modify structural brace depth.
#
# Both examples from the GUP v5.3 mandate appear VERBATIM.  Every case asserts
# either an exact unit inventory (extraction-level) or exact scanner events
# (engine-level).  Any failure exits 1.
# ---------------------------------------------------------------------------

def _selftest_units(name: str, source: str, expected: set, lang: str):
    got = {
        "js": extract_js_units,
        "bash": extract_bash_units,
        "python": extract_python_units,
    }[lang](source)
    return name, set(got), expected


def run_selftest() -> int:
    cases = []

    def check(label, condition):
        cases.append((label, bool(condition)))

    # ---- JS: comments must be structurally neutral ----------------------
    js_comment = (
        "function outer() {\n"
        "  // don't let this apostrophe change lexical state { }\n"
        "  return 1;\n"
        "}\n"
        "function after() { return 2; }\n"
    )
    _, got, exp = _selftest_units(
        "js-comment", js_comment, {"outer", "after"}, "js"
    )
    check("js: apostrophe in line comment stays neutral", got == exp)

    js_block_comment = (
        "function a() {\n"
        "  /* } { } and an apostrophe too — don't */\n"
        "  return 1;\n"
        "}\n"
    )
    _, got, exp = _selftest_units(
        "js-block-comment", js_block_comment, {"a"}, "js"
    )
    check("js: braces in block comment stay neutral", got == exp)

    # ---- JS: quoted strings must be structurally neutral ----------------
    js_string = (
        'function b() {\n'
        '  const s = "}{ {" + \'{\';\n'
        "  return s.length;\n"
        "}\n"
    )
    _, got, exp = _selftest_units("js-string", js_string, {"b"}, "js")
    check("js: braces in string literals stay neutral", got == exp)

    # ---- JS: regex literals — quotes and braces inert -------------------
    js_regex = (
        "function clean(s) {\n"
        "  return s.replace(/['\"{]foo['\"}]/g, 'x');\n"
        "}\n"
    )
    _, got, exp = _selftest_units("js-regex", js_regex, {"clean"}, "js")
    check("js: quotes+braces inside a regex literal stay neutral", got == exp)

    js_regex_class = (
        "function esc(s) {\n"
        "  return s.replace(/[/]/g, '_') + s.replace(/a\\/b/g, '_');\n"
        "}\n"
    )
    _, got, exp = _selftest_units(
        "js-regex-class", js_regex_class, {"esc"}, "js"
    )
    check("js: char-class and escaped-slash regexes stay neutral", got == exp)

    js_division = (
        "function math(a, b, c, d) {\n"
        "  const y = a / b + c / d;\n"
        "  const re = /x/;\n"
        "  return y + re.source.length;\n"
        "}\n"
    )
    _, got, exp = _selftest_units(
        "js-division", js_division, {"math"}, "js"
    )
    check("js: division after identifiers is not a regex", got == exp)

    # ---- JS: template literals — text inert, ${…} active ---------------
    js_template = (
        "function tpl(alpha) {\n"
        "  const t = `literal { } braces ${'x'} and ${ {a: 1}.a } done`;\n"
        "  return t + alpha;\n"
        "}\n"
    )
    _, got, exp = _selftest_units("js-template", js_template, {"tpl"}, "js")
    check("js: template text braces inert, interpolation active", got == exp)

    js_nested_template = (
        "function nested(x) {\n"
        "  return `a${`b${x}c`}d`;\n"
        "}\n"
    )
    _, got, exp = _selftest_units(
        "js-nested-template", js_nested_template, {"nested"}, "js"
    )
    check("js: nested template inside interpolation stays balanced", got == exp)

    # ---- JS: class scope — keywords are never methods -------------------
    js_class = (
        "class Widget\n"
        "{\n"
        "  run() { return this.tick(); }\n"
        "  tick() {\n"
        "    if (this.on) { return 1; }\n"
        "    for (let i = 0; i < 3; i++) { this.step(); }\n"
        "    while (false) { break; }\n"
        "    switch (1) { case 1: return 0; }\n"
        "    return 0;\n"
        "  }\n"
        "}\n"
    )
    _, got, exp = _selftest_units(
        "js-class", js_class, {"Widget", "Widget.run", "Widget.tick"}, "js"
    )
    check(
        "js: class brace on next line + no bogus if/for/while/switch units",
        got == exp,
    )

    # ---- JS: multiline signature ----------------------------------------
    js_multiline = (
        "function declared(\n"
        "  a,\n"
        "  b\n"
        ") {\n"
        "  return a + b;\n"
        "}\n"
    )
    _, got, exp = _selftest_units(
        "js-multiline-sig", js_multiline, {"declared"}, "js"
    )
    check("js: multiline function signature is found", got == exp)

    # ---- JS: engine-level invariant on the user's exact regex -----------
    scan = scan_js("const r = /['\"{]foo['\"}]/;\n")
    check(
        "js engine: /['\"{]foo['\"}]/ produces zero structural braces",
        len(scan["braces"]) == 0 and not scan["warnings"],
    )

    # ---- Bash: the two GUP v5.3 mandate examples VERBATIM ---------------
    bash_comment = (
        "# don't let this apostrophe change lexical state { }\n"
        "probe() {\n"
        "  return 0\n"
        "}\n"
    )
    _, got, exp = _selftest_units(
        "bash-comment-mandate", bash_comment, {"probe"}, "bash"
    )
    check(
        "bash: mandate comment example (verbatim) stays neutral",
        got == exp,
    )

    bash_regex = (
        'check() {\n'
        '  [[ "$x" =~ /[\'"{]foo[\'"}]/ ]]\n'
        "  return 0\n"
        "}\n"
    )
    _, got, exp = _selftest_units(
        "bash-regex-mandate", bash_regex, {"check"}, "bash"
    )
    check(
        "bash: mandate regex example (verbatim) leaks no quote/brace state",
        got == exp,
    )

    # ---- Bash: quoting forms --------------------------------------------
    bash_quotes = (
        "wrap() {\n"
        "  local msg='a \"quoted\" {brace} and an apostrophe'\n"
        '  local other="double \\"escaped\\" {braces}"\n'
        "  local ansi=$'ANSI-C { } \\' quotes'\n"
        "  local loc=$\"locale { } quotes\"\n"
        "  local bt=`backtick { } \\` stuff`\n"
        "  printf '%s' \"$msg$other$ansi$loc$bt\"\n"
        "  return 0\n"
        "}\n"
    )
    _, got, exp = _selftest_units(
        "bash-quotes", bash_quotes, {"wrap"}, "bash"
    )
    check(
        "bash: every quoting form (sq/dq/ansi/locale/backtick) is neutral",
        got == exp,
    )

    # ---- Bash: heredoc body fully inert ---------------------------------
    bash_heredoc = (
        "help_cmd() {\n"
        "  cat <<'HELPEOF'\n"
        "don't { leak } \"state\" `here` # nope\n"
        "  even { nested } braces and 'apostrophes'\n"
        "HELPEOF\n"
        "  return 0\n"
        "}\n"
    )
    _, got, exp = _selftest_units(
        "bash-heredoc", bash_heredoc, {"help_cmd"}, "bash"
    )
    check("bash: quoted-heredoc body is fully inert", got == exp)

    bash_heredoc_dash = (
        "tabbed() {\n"
        "  cat <<-EOF\n"
        "\t} { ' \" body with traps\n"
        "\tEOF\n"
        "  return 0\n"
        "}\n"
    )
    _, got, exp = _selftest_units(
        "bash-heredoc-dash", bash_heredoc_dash, {"tabbed"}, "bash"
    )
    check("bash: <<- heredoc with tab-indented delimiter", got == exp)

    # ---- Bash: expansions, brace groups, literal } ----------------------
    bash_mixed = (
        "run() {\n"
        '  local v="${1:-default}"\n'
        '  printf \'%s\' "$v"\n'
        "  for i in {1..3}; do echo \"$i\"; done\n"
        "  seq 1 10 | { grep -v 5 || true; }\n"
        "  echo }\n"
        "  x=$(( 1 + 2 ))\n"
        "  y=$(printf '%s' \"a\")\n"
        "  return 0\n"
        "}\n"
    )
    _, got, exp = _selftest_units("bash-mixed", bash_mixed, {"run"}, "bash")
    check(
        "bash: ${…}, {1..3}, brace group, literal `echo }`, $((…)), $(…) all neutral",
        got == exp,
    )

    # ---- Bash: ffx-shaped regexes and continued brace groups ------------
    bash_ffx = (
        "valid() {\n"
        '  [[ "$inp" =~ ^[0-9]+(\\.[0-9]+)?$ ]] || return 1\n'
        "  return 0\n"
        "}\n"
        "fps() {\n"
        '  [[ -n "$s" ]] && { printf \'%s\' "$s" || printf \'%s\' "$ADV_FPS"; } \\\n'
        "    && return 0\n"
        "  return 1\n"
        "}\n"
    )
    _, got, exp = _selftest_units(
        "bash-ffx-shapes", bash_ffx, {"valid", "fps"}, "bash"
    )
    check(
        "bash: [[ =~ ]] regexes and backslash-continued brace groups",
        got == exp,
    )

    # ---- Bash: subshell parens never impersonate a declaration ----------
    bash_subshell = (
        'out="$(echo hi)"\n'
        "wrap() {\n"
        '  x=$(printf \'%s\' "a")\n'
        "  y=$(( 3 + 4 ))\n"
        "  return 0\n"
        "}\n"
    )
    _, got, exp = _selftest_units(
        "bash-subshell", bash_subshell, {"wrap"}, "bash"
    )
    check(
        "bash: $(…) / $((…)) never create phantom functions",
        got == exp,
    )

    # ---- Bash: `function name {` alternative declaration form ----------
    bash_function_kw = (
        "function alt {\n"
        "  return 0\n"
        "}\n"
    )
    _, got, exp = _selftest_units(
        "bash-function-kw", bash_function_kw, {"alt"}, "bash"
    )
    check("bash: `function name {` declaration form", got == exp)

    # ---- Python: unchanged path still works -----------------------------
    py_src = (
        "def one():\n"
        "    return 1\n"
        "\n"
        "class C:\n"
        "    def m(self):\n"
        "        return one()\n"
    )
    _, got, exp = _selftest_units(
        "python-sanity", py_src, {"one", "C", "C.m"}, "python"
    )
    check("python: ast extraction unchanged", got == exp)

    # ---- Determinism: identical runs, identical manifests ---------------
    mixed = bash_ffx + js_class + py_src
    m1 = build_manifest(extract_bash_units(bash_ffx))
    m2 = build_manifest(extract_bash_units(bash_ffx))
    check("determinism: repeated extraction is identical", m1 == m2)
    check(
        "determinism: manifest is name-sorted and stable",
        [u["unit"] for u in m1] == sorted(u["unit"] for u in m1),
    )

    failures = [label for label, ok in cases if not ok]
    for label, ok in cases:
        print(f"  [{'PASS' if ok else 'FAIL'}] {label}")
    print(
        f"\n[gup selftest] {len(cases) - len(failures)}/{len(cases)} passed"
        f" — {GUP_PROTOCOL} atomizer invariant"
    )
    if failures:
        print("[gup selftest] FAILURES:", file=sys.stderr)
        for label in failures:
            print(f"  - {label}", file=sys.stderr)
        return 1
    return 0


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            f"Named-unit hashing for the {GUP_PROTOCOL} (golden_unit_hash "
            "{__version__}). Produces MISSING/UNCHANGED/CHANGED/NEW by unit "
            "name, never by line position. The atomizer is lexically "
            "context-aware: comments, quoted strings and regex literals are "
            "structurally neutral. Digest comparison (§3) and the §4 "
            "architectural gate are NOT performed here — the model does "
            "those by reading the flagged CHANGED/NEW units."
        ).replace("{__version__}", __version__)
    )
    parser.add_argument("--baseline", help="Path to baseline source file.")
    parser.add_argument("--candidate", help="Path to candidate source file.")
    parser.add_argument(
        "--language",
        choices=["python", "js", "bash"],
        help="Override auto-detection (extension or shebang).",
    )
    parser.add_argument(
        "--manual-units",
        metavar="FILE",
        help=(
            "JSON file of baseline units for non-code domains: "
            '[{"name": "...", "content": "..."}]'
        ),
    )
    parser.add_argument(
        "--manual-units-candidate",
        metavar="FILE",
        help="JSON file of candidate units, paired with --manual-units.",
    )
    parser.add_argument(
        "--manifest-only",
        action="store_true",
        help="Only emit the manifest for --baseline; skip comparison.",
    )
    parser.add_argument(
        "--selftest",
        action="store_true",
        help=(
            "Run the GUP v5.3 atomizer invariant battery and exit 0/1. "
            "No files are required."
        ),
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"golden_unit_hash {__version__} ({GUP_PROTOCOL})",
    )
    args = parser.parse_args()

    if args.selftest:
        sys.exit(run_selftest())

    # ---- Load baseline ----
    if args.manual_units:
        baseline_units = load_manual_units(args.manual_units)
    elif args.baseline:
        baseline_units = extract_units(args.baseline, args.language)
    else:
        parser.error("Provide --baseline or --manual-units (or --selftest).")
        return  # unreachable; satisfies type checker

    # ---- Manifest-only mode ----
    if args.manifest_only:
        print(json.dumps({"manifest": build_manifest(baseline_units)}, indent=2))
        return

    # ---- Load candidate ----
    if args.manual_units_candidate:
        candidate_units = load_manual_units(args.manual_units_candidate)
    elif args.candidate:
        candidate_units = extract_units(args.candidate, args.language)
    else:
        parser.error(
            "Provide --candidate or --manual-units-candidate, "
            "or pass --manifest-only for a single-file manifest."
        )
        return

    # ---- Diff ----
    diff = diff_manifests(baseline_units, candidate_units)

    result = {
        "gup_version": __version__,
        "protocol": GUP_PROTOCOL,
        "baseline_manifest": build_manifest(baseline_units),
        "candidate_manifest": build_manifest(candidate_units),
        "diff": diff,
        "note": (
            "Verdicts are hash-based only. CHANGED and NEW units still "
            "require the §3 semantic digest comparison and, if class is "
            "'orchestrator' or 'volatile-logic', the §4 architectural gate "
            "— both are judgment calls this script does not make."
        ),
    }
    print(json.dumps(result, indent=2))

    # ---- Stderr signals for CI ----
    missing = [u for u in diff if u["verdict"] == "MISSING"]
    new_units = [u for u in diff if u["verdict"] == "NEW"]
    changed = [u for u in diff if u["verdict"] == "CHANGED"]
    unchanged = [u for u in diff if u["verdict"] == "UNCHANGED"]

    # Summary always goes to stderr so it doesn't corrupt JSON stdout piping.
    print(
        f"\n[GUP {__version__}] Summary: "
        f"{len(unchanged)} UNCHANGED  "
        f"{len(changed)} CHANGED  "
        f"{len(new_units)} NEW  "
        f"{len(missing)} MISSING",
        file=sys.stderr,
    )

    # NEW units: surface for mandatory model review (Gate 2), but not a
    # script-level hard fail — acceptability depends on §4 judgment.
    if new_units:
        names = ", ".join(u["unit"] for u in new_units)
        print(
            f"[REVIEW REQUIRED] NEW units (absent in baseline, present in "
            f"candidate — require §3 digest + §4 Gate 2 review): {names}",
            file=sys.stderr,
        )

    # MISSING units: hard fail, always.
    if missing:
        names = ", ".join(u["unit"] for u in missing)
        print(
            f"[HARD FAIL] MISSING units (present in baseline, absent in "
            f"candidate): {names}",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
