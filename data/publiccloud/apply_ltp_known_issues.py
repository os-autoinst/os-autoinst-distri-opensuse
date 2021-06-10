#!/usr/bin/python3
# -*- coding: utf-8 -*-

import sys
import json
import requests
import re


def load_file(filename):
    with open(filename, "r") as f_in:
        return json.load(f_in)


def is_link(link):
    return "://" in link


def load_link(link):
    r = requests.get(link)
    if r.status_code != 200:
        raise ValueError("http status code %d" % (r.status_code))
    return r.json()


def load_json(ref):
    if is_link(ref):
        return load_link(ref)
    return load_file(ref)


def process(results, known_issues, env):
    """
    Apply the known_issues to the given run_ltp result set and the given environment
    result is the json object of the 'ltp_log.json' file
    known_issues is the json_object of the 'ltp_known_issues.json' file
    env - dictionary containing the environment variables to match the known_issues against (e.g. distri, version, arch, ...)
    """
    res = results["results"]

    # product is one of the most used env. variables and needs to be assembled, if not present
    if not "product" in env:
        env["product"] = "%s:%s" % (env["distri"], env["version"])

    # Search for failed tests and mark them as softfailed, if in known_issues
    for test in res:
        status, name = test["status"], test["test_fqn"]
        if status == "fail":
            if is_known_issue(name, known_issues, env):
                sys.stderr.write("softfail: %s\n" % (name))
                test["status"] = "softfail"
    return results


def check_matching_vars(issue, env):
    for var in issue:
        if var == "message":
            continue
        if not var in env:
            return False
        if not re.match(issue[var], env[var]):
            return False
    return True


def is_known_issue(test, known_issues, env):
    # Check in list of known issues if the current issue is given
    for name in known_issues:
        if name != test:
            continue
        # Check every known issue for matching settings
        for known_issue in known_issues[name]:
            # Every var except "message" must match
            if check_matching_vars(known_issue, env):
                return True
    return False


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: %s RESULTS KNOWNISSUES ENV TESTSUITE" % (sys.argv[0]))
        print("       RESULTS      json results file from ltp")
        print(
            "       KNOWNISSUES  file or http link where to fetch the latest known issues from (json)"
        )
        print("       ENV          Environment variables used for matching (json)")
        print("       TESTSUITE    testsuite under test (e.g. syscalls, cve)")
        sys.exit(1)

    # Load results and known_issues from file/link
    results_f, known_issues_f, env_f, testsuite = (
        sys.argv[1],
        sys.argv[2],
        sys.argv[3],
        sys.argv[4],
    )
    results = load_json(results_f)
    known_issues = load_json(known_issues_f)
    env = load_json(env_f)
    # Process known issues
    ret = process(results, known_issues[testsuite], env)

    print(json.dumps(ret))
