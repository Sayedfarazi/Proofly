#!/usr/bin/env python3
import argparse
import os
import re
import struct
import subprocess
import sys
import zlib
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    ".github/workflows/macos.yml",
    "docs/images/slack-original.png", "docs/images/slack-proofread.png", "docs/images/slack-rewrite.png",
    ".gitignore", ".gitattributes", "Package.swift", "README.md", "CHANGELOG.md",
    "LICENSE", "Sources/Proofly/Info.plist", "Sources/Proofly/Proofly.entitlements",
    "Designs/Proofly-AppIcon.png", "Designs/Proofly-MenuBarTemplate.png",
    "Scripts/build-app.sh", "Scripts/build-icons.sh", "Scripts/package.sh",
    "Scripts/test-text-layout.sh", "Scripts/check-public.py",
    "Scripts/setup-git-hooks.sh", ".githooks/pre-commit", ".githooks/pre-push",
}
RULES = [
    ("private home path", r"/(?:Users|home)/[A-Za-z0-9_.-]+"),
    ("Windows home path", r"[A-Za-z]:\\Users\\[A-Za-z0-9_.-]+"),
    ("private key", r"-----BEGIN (?:[A-Z]+ )*PRIVATE KEY-----"),
    ("credential URL", r"[a-z][a-z0-9+.-]*://[^\s/@:]+:[^\s/@]+@"),
    ("access token", r"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{15,}|sk-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|mdb_sa_sk_[A-Za-z0-9]{12,})"),
    ("cloud access key", r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
    ("credential assignment", r"(?i)\b(?:password|passwd|api[_-]?key|client[_-]?secret|access[_-]?token|private[_-]?key)\b\s*[:=]\s*[\"'][^\"'\s]{8,}[\"']"),
    ("private network address", r"\b(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})\b"),
]


def allowed(name):
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts:
        return False
    if name in FILES:
        return True
    return path.suffix == ".swift" and (
        name.startswith("Sources/Proofly/") or name.startswith("Tests/")
    ) and not any(part.startswith(".") for part in path.parts)


def check_png(data):
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return "invalid PNG"
    offset = 8
    ended = False
    while offset < len(data):
        if offset + 12 > len(data):
            return "truncated PNG"
        size = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        end = offset + 12 + size
        if end > len(data):
            return "truncated PNG"
        payload = data[offset + 8:offset + 8 + size]
        crc = struct.unpack(">I", data[offset + 8 + size:end])[0]
        if zlib.crc32(kind + payload) & 0xffffffff != crc:
            return "PNG checksum mismatch"
        if kind not in {b"IHDR", b"PLTE", b"tRNS", b"IDAT", b"IEND"}:
            return "PNG metadata is not allowed"
        offset = end
        if kind == b"IEND":
            ended = True
            break
    return None if ended and offset == len(data) else "invalid PNG ending"


def check_file(name, data, mode="100644"):
    if not allowed(name):
        return [(name, "file is outside the public allowlist")]
    if mode not in {"100644", "100755"}:
        return [(name, "links and submodules are not allowed")]
    if name.endswith(".png"):
        problem = check_png(data)
        return [(name, problem)] if problem else []
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return [(name, "unexpected binary content")]
    return [(name, label) for label, pattern in RULES if re.search(pattern, text)]


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args])


def working_files():
    for base, folders, files in os.walk(ROOT):
        if Path(base) == ROOT:
            folders[:] = [name for name in folders if name not in {".git", ".build", "dist"}]
        for name in folders + files:
            path = Path(base) / name
            relative = path.relative_to(ROOT).as_posix()
            if path.is_symlink():
                yield relative, b"", "120000"
            elif path.is_file():
                yield relative, path.read_bytes(), "100644"


def staged_files():
    for entry in git("ls-files", "--stage", "-z").split(b"\0"):
        if not entry:
            continue
        metadata, name = entry.split(b"\t", 1)
        mode, oid, stage = metadata.decode().split()
        if stage != "0":
            raise ValueError("Resolve merge conflicts before committing.")
        yield name.decode(), git("cat-file", "blob", oid), mode


def history_files():
    seen = set()
    pushed = []
    if not sys.stdin.isatty():
        for line in sys.stdin:
            fields = line.split()
            if len(fields) == 4 and re.fullmatch(r"[0-9a-f]{40,64}", fields[1]) and set(fields[1]) != {"0"}:
                pushed.append(fields[1])
    for commit in git("rev-list", "--all", *pushed).decode().splitlines():
        for entry in git("ls-tree", "-r", "-z", commit).split(b"\0"):
            if not entry:
                continue
            metadata, name = entry.split(b"\t", 1)
            mode, kind, oid = metadata.decode().split()
            key = (name, oid)
            if key in seen:
                continue
            seen.add(key)
            yield name.decode(), git("cat-file", "blob", oid) if kind == "blob" else b"", mode


def main():
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--staged", action="store_true")
    mode.add_argument("--history", action="store_true")
    args = parser.parse_args()
    entries = history_files() if args.history else staged_files() if args.staged else working_files()
    findings = []
    count = 0
    for name, data, filemode in entries:
        count += 1
        findings.extend(check_file(name, data, filemode))
    for name, label in findings:
        print("BLOCKED: " + name + ": " + label, file=sys.stderr)
    if findings:
        return 1
    print("PASS: " + str(count) + " public files checked.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print("Public-file check failed: " + str(error), file=sys.stderr)
        sys.exit(1)
