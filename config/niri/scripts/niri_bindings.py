#!/usr/bin/env python3
"""Build the searchable menu from niri's ordered KDL includes (not a directory scan).

Reads KDL v1 structure without third-party Python packages. Only top-level binds
are menu entries; e.g. recent-windows.binds is a separate, contextual keymap.
Bindings without a string title still replace earlier bindings before filtering.
"""

import argparse
import ctypes
import json
import os
from pathlib import Path
import re
import sys
from dataclasses import dataclass, field


@dataclass
class Token:
    kind: str
    value: str


@dataclass
class Node:
    name: str
    args: list = field(default_factory=list)
    props: dict = field(default_factory=dict)
    children: list = field(default_factory=list)


def tokens(text):
    """Keep node boundaries, but ignore comments without looking inside strings."""
    pos = 0
    while pos < len(text):
        char = text[pos]
        if text.startswith("//", pos):
            end = text.find("\n", pos)
            pos = len(text) if end < 0 else end
        elif text.startswith("/*", pos):
            pos += 2
            depth = 1
            while depth:
                if pos == len(text):
                    raise ValueError("unterminated block comment")
                if text.startswith("/*", pos):
                    depth += 1
                    pos += 2
                elif text.startswith("*/", pos):
                    depth -= 1
                    pos += 2
                else:
                    pos += 1
        elif text.startswith("/-", pos):
            yield Token("/-", "/-")
            pos += 2
        elif char == "\\":
            match = re.match(r"\\[^\S\r\n]*(?://[^\n]*)?\r?\n", text[pos:])
            if not match:
                raise ValueError("unsupported line continuation")
            pos += match.end()
        elif char == "\n" or char in "{};=()":
            yield Token(char, char)
            pos += 1
        elif char.isspace() or char == "\ufeff":
            pos += 1
        elif match := re.match(r'r(#{0,})"', text[pos:]):
            start = pos + match.end()
            ending = '"' + match[1]
            end = text.find(ending, start)
            if end < 0:
                raise ValueError("unterminated raw string")
            yield Token("string", text[start:end])
            pos = end + len(ending)
        elif char == '"':
            match = re.match(r'"(?:\\.|[^"\\])*"', text[pos:], re.DOTALL)
            if not match:
                raise ValueError("unterminated string")
            # KDL v1 Unicode escapes use braces, unlike JSON's fixed-width form.
            quoted = re.sub(
                r"\\(?:u\{([0-9a-fA-F]+)\}|.)",
                lambda m: json.dumps(chr(int(m[1], 16)))[1:-1] if m[1] else m[0],
                match[0],
            )
            yield Token("string", json.loads(quoted, strict=False))
            pos += match.end()
        else:
            start = pos
            while pos < len(text):
                if text[pos].isspace() or text[pos] in '{};=()"\\':
                    break
                if any(text.startswith(mark, pos) for mark in ("//", "/*", "/-")):
                    break
                pos += 1
            if pos == start:
                raise ValueError(f"unexpected character at offset {pos}")
            yield Token("word", text[start:pos])
    yield Token("eof", "")


class Parser:
    def __init__(self, text):
        self.stream = iter(tokens(text))
        self.current = next(self.stream)

    def take(self, kind=None):
        token = self.current
        if kind is not None and token.kind != kind:
            raise ValueError(f"expected {kind!r}, got {token.value!r}")
        if token.kind != "eof":
            self.current = next(self.stream)
        return token

    def scalar(self):
        if self.current.kind == "(":
            self.take("(")
            self.take()
            self.take(")")
        if self.current.kind not in ("word", "string"):
            raise ValueError(f"expected a KDL value, got {self.current.value!r}")
        return self.take()

    def nodes(self, end="eof"):
        result = []
        while self.current.kind != end:
            if self.current.kind in ("\n", ";"):
                self.take()
                continue
            if self.current.kind == "eof":
                raise ValueError("unclosed child block")
            disabled = self.current.kind == "/-"
            if disabled:
                self.take()
            node = self.node()
            if not disabled:
                result.append(node)
        return result

    def node(self):
        node = Node(self.scalar().value)
        while self.current.kind not in ("\n", ";", "}", "eof"):
            disabled = self.current.kind == "/-"
            if disabled:
                self.take()
            if self.current.kind == "{":
                self.take("{")
                children = self.nodes("}")
                self.take("}")
                if not disabled:
                    node.children = children
                    break
                continue
            value = self.scalar()
            if self.current.kind == "=":
                self.take("=")
                prop = self.scalar()
                if not disabled:
                    node.props[value.value] = prop
            elif not disabled:
                node.args.append(value)
        return node


class KeyNormalizer:
    """Match niri 26.04's key equality, including XKB keysym aliases.

    Mod is intentionally distinct from Super, just as in niri's config merging.
    libxkbcommon is already a runtime dependency of niri.
    """

    ALIASES = {
        "control": "ctrl",
        "win": "super",
        "mod5": "iso_level3_shift",
        "mod3": "iso_level5_shift",
    }

    def __init__(self):
        self.xkb = ctypes.CDLL("libxkbcommon.so.0")
        self.lookup = self.xkb.xkb_keysym_from_name
        self.lookup.argtypes = [ctypes.c_char_p, ctypes.c_int]
        self.lookup.restype = ctypes.c_uint32

    def __call__(self, key):
        *modifiers, trigger = key.split("+")
        modifiers = frozenset(
            self.ALIASES.get(m.strip().lower(), m.strip().lower()) for m in modifiers
        )
        symbol = self.lookup(trigger.encode(), 1)  # XKB_KEYSYM_CASE_INSENSITIVE
        if trigger.lower() == "xf86screensaver":
            symbol = self.lookup(trigger.encode(), 0) or self.lookup(
                b"XF86ScreenSaver", 0
            )
        return modifiers, symbol or trigger.lower()


def menu_rows(config):
    bindings = {}
    normalize = KeyNormalizer()

    def visit(path, stack=()):
        identity = path.resolve()
        if identity in stack or len(stack) >= 64:
            raise ValueError(f"recursive/too-deep include: {path}")
        try:
            nodes = Parser(path.read_text(encoding="utf-8")).nodes()
        except ValueError as error:
            raise ValueError(f"{path}: {error}") from error
        for node in nodes:
            if node.name == "include":
                if len(node.args) != 1:
                    raise ValueError(f"{path}: include needs one path")
                child = Path(node.args[0].value).expanduser()
                if not child.is_absolute():
                    child = path.parent / child
                optional = (
                    node.props.get("optional", Token("word", "false")).value == "true"
                )
                try:
                    visit(child, (*stack, identity))
                except FileNotFoundError as error:
                    # Only the optional file itself may be absent, not its required includes.
                    if not optional or Path(error.filename) != child:
                        raise
            elif node.name == "binds":
                for bind in node.children:
                    key = normalize(bind.name)
                    bindings.pop(key, None)
                    bindings[key] = bind

    visit(Path(config).expanduser().absolute())
    for bind in bindings.values():
        title = bind.props.get("hotkey-overlay-title")
        if title is not None and title.kind == "string" and title.value:
            # A description is display data, never shell source or extra menu rows.
            yield bind.name, " ".join(title.value.split())


def main():
    default = os.environ.get("NIRI_CONFIG") or str(
        Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
        / "niri/config.kdl"
    )
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", nargs="?", default=default)
    args = parser.parse_args()
    try:
        # Fully read/merge before printing: errors must not produce a partial menu.
        rows = list(menu_rows(args.config))
    except (OSError, ValueError) as error:
        print(f"niri-binds: {error}", file=sys.stderr)
        return 1
    for key, title in rows:
        print(f"{key}\t{title}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
