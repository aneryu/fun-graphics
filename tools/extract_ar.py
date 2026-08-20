#!/usr/bin/env python3
"""Extract every ar member to a uniquely named .o, including duplicate basenames."""
from __future__ import annotations

import os
import sys


def extract(archive: str, dest: str) -> int:
    os.makedirs(dest, exist_ok=True)
    with open(archive, "rb") as fh:
        magic = fh.read(8)
        if magic != b"!<arch>\n":
            raise SystemExit(f"fun-graphics: not an ar archive: {archive}")
        long_names = b""
        count = 0
        while True:
            header = fh.read(60)
            if not header:
                break
            if header == b"\n":
                continue
            if len(header) < 60:
                break
            raw_name = header[0:16]
            size = int(header[48:58].decode("ascii", "replace").strip() or "0")
            data = fh.read(size)
            if size % 2 == 1:
                fh.read(1)
            name = raw_name.decode("ascii", "replace").rstrip(" ")
            if name == "//":
                long_names = data
                continue
            if name.startswith("#1/"):
                nlen = int(name[3:] or "0")
                name = data[:nlen].decode("ascii", "replace").rstrip("\0")
                data = data[nlen:]
            elif name.startswith("/") and name[1:].strip().isdigit():
                offset = int(name[1:])
                end = long_names.find(b"\n", offset)
                if end < 0:
                    end = len(long_names)
                name = long_names[offset:end].decode("ascii", "replace").rstrip("/ \n")
            if name in ("", "/", "__.SYMDEF", "__.SYMDEF SORTED"):
                continue
            if not data:
                continue
            out = os.path.join(dest, f"{count:04d}.o")
            with open(out, "wb") as out_fh:
                out_fh.write(data)
            count += 1
        return count


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(f"usage: {sys.argv[0]} <archive.a> <dest-dir>")
    n = extract(sys.argv[1], sys.argv[2])
    print(n)


if __name__ == "__main__":
    main()
