<!-- SPDX-License-Identifier: FSFAP -->

# Verification

## Match evidence to the change

Use the PR verification links, `.github/checklist.yml`, and the actual changed
callers to select relevant cases. For a verification run, check the tested
revision, job settings, scheduled modules, and step logs when accessible.
A passing job is useful only if it reaches the changed code. Record unavailable
logs or missing revision information as a verification limit.

For shared code, inspect affected products, backends, architectures, and team
consumers. The checklist requests both QE-C and QE-SAP runs for changes to
`lib/publiccloud/`. Follow the Tumbleweed rule and its exceptions in
`CONTRIBUTING.md`. Do not demand every possible matrix combination for a local
change; identify the distinct behavior that needs verification.

If a change replaces a capture or verification tool, check that the replacement
retains the required capability, such as a protocol decoder. A smaller tool is
not a valid replacement if it cannot produce the evidence the test requires.

When replacing a test, map the old assertions and setup to the new test for
each affected consumer. Extra cases do not prove that existing coverage is
preserved. For example, a sudo test that modifies user configuration does not
prove that a cloud image's default user configuration works unchanged.

For version-dependent commands, verify the distinct command paths, not just
different product labels. An updated package on an old product can hide a
compatibility problem in its original package. Keep the tested module result
separate from failures in unrelated job steps and from infrastructure failures
that prevent the test from running.

## Unit tests

- For changed library behavior, look for relevant tests in `t/`. Check important
  failures, default values, and changed parameter behavior as well as success.
- Check observable behavior: returned values, raised exceptions, command
  arguments, and state changes. Do not require tests to reproduce private
  implementation details or ordinary diagnostic message wording.
- Test diagnostic output when that output is itself part of the contract.
  A reviewer's objection to one logging assertion is not a ban on logging tests.
- Mock time and external operations where needed. A retry unit test should not
  spend real seconds waiting or require a cloud deployment to check local logic.
- Ensure mocks can expose the regression. A mock that always succeeds does not
  verify an error path. Do not request trivial tests solely to increase count.

## Schedules and variables

Read `declarative-schedule-doc.md` for YAML schedule changes and `variables.md`
for changed settings. Trace imports, conditional branches, defaults, module
order, and setup dependencies. Check renamed module references and whether
new coverage is actually scheduled. Inspect `main.pm`, `products/`, and
`lib/main_*.pm` when they control the changed path.

Check related job-group changes when they are available. A module or profile
can merge before its production schedule changes; record that dependency.
Keep setup before the assertion it supports. A status message alone does not
prove the underlying behavior, such as disabled remote access.

Keep variable descriptions in `variables.md` where applicable. A code comment
should explain a decision, not duplicate a long setting description. For
installation UI changes, follow `ui-framework-documentation.md` as directed
by the repository README.

## Choose checks from the current checkout

Inspect the `Makefile`, tools, and CI configuration before selecting commands.
Examples in this checkout include:

| Change | Relevant check |
| --- | --- |
| A library with an existing unit test | `prove -l -Ios-autoinst/ t/<relevant-test>.t` |
| YAML schedules | `make test-yaml-valid` and `make test-modules-in-yaml-schedule` |
| Broad changes with dependencies installed | The relevant `make test` target from CI |
| Formatting | Inspect `make tidy-check` and its prerequisites before running it |

Some targets select files against `origin/master` or only the working tree.
Check that they include the requested diff. A command that checked no relevant
files is not evidence. Some targets also write files or prepare dependencies;
do not use them blindly during a review. Report missing dependencies instead
of claiming that the checks passed.

Local checks do not replace openQA verification. Review existing run evidence
and state which additional run would resolve a gap. Launch jobs only when the
user has authorized that work. Inspect CI results for the reviewed revision;
an approval or an earlier successful run does not establish the current result.

See [Review evidence](evidence.md) for the PR discussions behind these checks.
