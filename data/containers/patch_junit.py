#!/usr/bin/env python3
"""
This script is used to:
1. Replace <failure> with <xfailure> for expected failures in JUnit XML files,
   adjusting the failure counters so the openQA parser ignores them.
2. Prepend a prefix to the testsuite name when needed.
3. Print a message if an expected failure actually passed.
"""

import xml.etree.ElementTree as ET
import re
import sys
from typing import Dict, List


# Use "(root|user)-(local|remote)" prefix in testsuite based on the filename
PREFIX = re.compile(r"-((?:root|user)(?:-(?:local|remote))?)\.xml$")


def get_xfails(args: List[str]) -> Dict[str, List[str]]:
    """
    Transform list of known failures into a dict keyed by testsuite
    to hold a set of testcases with empty being all tests
    """
    xfails: Dict[str, List[str]] = {}
    for item in args:
        try:
            suitename, name = item.split("::", 1)
            xfails.setdefault(suitename, []).append(name)
        except ValueError:
            xfails[item] = []
    return xfails


def patch_xml(file: str, xfails: Dict[str, List[str]]) -> None:
    """
    Patch XML with dict of expected failures
    """
    tree = ET.parse(file)
    root = tree.getroot()

    prefix = ""
    try:
        prefix = PREFIX.findall(file).pop()
        prefix = f"{prefix}-"
    except IndexError:
        pass

    for testsuite in root.findall("testsuite"):
        # Prepend prefix to the suite name
        suitename = testsuite.get("name")  # type: ignore
        if not suitename:
            continue
        if prefix:
            testsuite.set("name", prefix + suitename)

        failures = int(testsuite.get("failures", "0"))
        adjusted = failures

        for testcase in testsuite.findall("testcase"):
            # Prepend prefix to the classname if it matches the suitename
            classname = testcase.get("classname")  # type: ignore
            if prefix and classname == suitename:
                testcase.set("classname", prefix + classname)

            # We don't do this before because we need to prepend the prefix above
            # and we don't skip on "not failures" because we want to signal if an
            # expected failure passed.
            if suitename not in xfails:
                continue

            casename = testcase.get("name")  # type: ignore
            # Skip if not an expected failure
            if xfails[suitename] and casename not in xfails[suitename]:
                continue

            failure = testcase.find("failure")
            if failure is None:
                if xfails[suitename]:
                    # This test was expected to fail but passed
                    print(prefix + suitename, casename)
                continue

            # Transform <failure> into <xfailure>
            failure.tag = "xfailure"
            adjusted -= 1

        # Update failures counter
        if adjusted != failures:
            testsuite.set("failures", str(adjusted))

    # Also update failures counters in root testsuites, if present
    if root.tag == "testsuites" and "failures" in root.attrib:
        total_failures = sum(
            int(ts.get("failures", "0")) for ts in root.findall("testsuite")
        )
        root.set("failures", str(total_failures))

    tree.write(file, encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        patch_xml(sys.argv[1], get_xfails(sys.argv[2:]))
