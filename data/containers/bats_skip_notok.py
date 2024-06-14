#!/usr/bin/env python3
"""
This script is used to selectively comment "not ok" lines in TAP files so the
openQA TAP parser ignores them
"""

import re
import sys


def flush(file, lines, comment_block=False):
    """
    Flush buffer optionally commenting the block
    """
    if len(lines) == 0:
        return
    if comment_block:
        # We only comment the first line as the rest have "# " in them
        print(f"#{lines[0]}", file=file)
        if len(lines) > 1:
            print("\n".join(lines[1:]), file=file)
    else:
        print("\n".join(lines), file=file)


def comment_not_ok(path, tests):
    """
    Comment "not ok" lines in path for the specified tests
    """
    skipped = re.compile(rf"in test file .*/(?:{'|'.join(tests)})\.bats")
    in_not_ok_block = False
    comment_block = False
    buffer = []

    with open(path, "r", encoding="utf-8") as file:
        lines = file.read().splitlines()

    with open(path, "w", encoding="utf-8") as file:
        for line in lines:
            if line.startswith("not ok"):
                flush(file, buffer, comment_block)
                buffer = [line]
                in_not_ok_block = True
                comment_block = False
            elif line.startswith("ok"):
                flush(file, buffer, comment_block)
                print(line, file=file)
                buffer = []
                in_not_ok_block = False
                comment_block = False
            elif in_not_ok_block:
                buffer.append(line)
                if skipped.search(line):
                    comment_block = True
            else:
                print(line, file=file)
        flush(file, buffer, comment_block)


if __name__ == "__main__":
    if len(sys.argv) > 2:
        comment_not_ok(sys.argv[1], sys.argv[2:])
