#!/usr/bin/env python3
"""
This script is used to:
1. Replace <failure> with <xfailure> for expected failures in JUnit XML files,
   adjusting the failure counters so the openQA parser ignores them.
2. Prepend a prefix to the testsuite name when needed.
3. Print a message if an expected failure actually passed.
"""

import xml.etree.ElementTree as ET
import os
import re
import sys
from typing import Dict, List


# Use "(root|user)-(local|remote)" prefix in testsuite based on the filename
BATS_PACKAGES = r"(?:aardvark|buildah|conmon|netavark|podman|runc|skopeo|umoci)"
PREFIX = re.compile(
    rf"({BATS_PACKAGES}(?:-(?:crun|runc))?(?:-(?:root|user))?(?:-(?:local|remote))?)\.xml$"
)


def get_xfails(args: List[str]) -> Dict[str, List[str]]:
    """
    Transform list of known failures into a dict keyed by class
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


def patch_xml(file: str, info: str, xfails: Dict[str, List[str]]) -> None:
    """
    Patch XML with dict of expected failures
    """
    try:
        tree = ET.parse(file)
    except ET.ParseError as err:
        sys.exit(f"ERROR: {err}")
    root = tree.getroot()

    prefix = ""
    try:
        prefix = PREFIX.findall(file).pop()
        prefix = f"{prefix}-"
    except IndexError:
        pass

    # str.removesuffix() was added to Python 3.8
    basename = os.path.basename(file)[: -len(".xml")]

    for testsuite in root.findall("testsuite"):
        suitename = testsuite.get("name")  # type: ignore
        if not suitename:
            continue
        # Prevent openQA from deduplicating results for suite names.
        if prefix:
            # BATS uses the test filename as the suite name. There is no
            # namespace, so we prepend the prefix
            testsuite.set("name", prefix + suitename)
        elif testsuite.get("package") is not None:
            # Ginkgo stores the structural test hierarchy in the 'package'
            # attribute, while the suite name is only a label
            testsuite.set("name", basename)
        else:
            # On gotestsum & pytest the suite name is a structured namespace.
            # To keep the hierarchy intact we insert the basename at the top
            testsuite.set("name", f"{basename}::{suitename}")

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
            xfails_key = classname
            if xfails_key not in xfails:
                continue

            casename = testcase.get("name")  # type: ignore
            # Skip if not an expected failure
            if xfails[xfails_key] and casename not in xfails[xfails_key]:
                continue

            failure = testcase.find("failure")
            if failure is None:
                if xfails[xfails_key]:
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
    if root.tag == "testsuites":
        if "failures" in root.attrib:
            total_failures = sum(
                int(ts.get("failures", "0")) for ts in root.findall("testsuite")
            )
            root.set("failures", str(total_failures))

        # Add metadata information like package version, etc
        keys = ["package", "version", "distri", "release", "build", "arch"]
        values = info.split()

        # Set testsuites name attribute
        root.set("name", basename)

        # Create or find <properties> under <testsuites>
        props = root.find("properties")
        if props is None:
            # Insert <properties> as the first child (before <testsuite>)
            props = ET.Element("properties")
            props.tail = "\n\t"
            root.insert(0, props)

        # Add metadata as <property name="..." value="..."/>
        for key, value in zip(keys, values):
            prop = ET.SubElement(props, "property")
            prop.set("name", key)
            prop.set("value", value)

    tree.write(file, encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    if len(sys.argv) > 2:
        patch_xml(sys.argv[1], sys.argv[2], get_xfails(sys.argv[3:]))
