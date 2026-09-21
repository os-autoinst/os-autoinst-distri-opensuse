<!-- SPDX-License-Identifier: FSFAP -->

# Runtime behavior

Use these questions where the diff changes the corresponding behavior.
Confirm each finding against the actual implementation and callers.

## Test result and command failures

- Does a failed command produce a test failure when success is required?
  Inspect the selected API: `script_run`, `assert_script_run`,
  `script_output`, or `validate_script_output`. Check the wrapper before
  assuming it ignores or throws on a nonzero exit status.
- Can a pipeline hide an earlier command failure? For example,
  `producer | tail ... || fallback` normally tests the status of `tail`.
  Check the shell and its options before proposing `pipefail` or `PIPESTATUS`.
- Are expected negative results distinguished from setup errors, timeouts,
  missing result files, and test collection failures?
- Is diagnostic output being mistaken for a verdict? Normal stderr can contain
  warnings. An ordinary `record_info` message does not assert success or failure;
  inspect its result arguments before making that claim.

## Waiting and retries

- What observable state ends the wait? Use the synchronization rules in
  `CONTRIBUTING.md`. Do not turn an accepted sleep in an old PR into permission
  for a new fixed delay.
- Which timeout bounds the command, termination grace, outer harness, and
  complete retry loop? Check defaults and the values passed by changed callers.
  Calculate a concrete failing case before reporting a timeout defect.
- Should an exception propagate or be retried? Read the implementation and
  tests. Do not add an exception handler merely because a helper retries
  nonzero exit codes.
- Does the probe establish the required readiness? An open TCP port, successful
  SSH login, and a completed system boot are different conditions. Check order
  and caller requirements before combining or removing probes.

## Product and execution context

- Does the condition describe the system that runs the command? In virtual
  machine tests, host settings do not necessarily describe the guest. Inspect
  guest version data and OS release helpers before parsing a guest name.
- Are feature expectations explicit for the affected products? A missing
  component must not silently skip the test if its presence is under test.
  Restrict workarounds to the affected case and apply the current soft-failure
  reference rules. Do not copy historical version expressions unchanged.
- Can a dependency failure enter an unrelated language or provider branch?
  Trace false conditions as well as successful setup.
- Does a command format depend on the installed tool version rather than the
  distribution label? Check version parsing and comparison behavior on the
  oldest relevant package build. Do not silently select an old command format
  when a required version probe fails.
- Does a console change preserve the shell or graphical session required by
  the next module? Check reset order, changed TTYs, and concurrent sessions.
  Two console names can be necessary even if they use the same device.
- Does a shared helper change affect consumers in other areas? Search callers
  of `lib/utils.pm`, public cloud helpers, and other shared interfaces. Area
  ownership does not limit the set of affected callers.

## Cleanup and scope

- Are created networks, containers, mounts, guests, and background processes
  cleaned up after failure as well as success? Check `post_fail_hook`,
  `post_run_hook`, base classes, and any caller cleanup.
- Can cleanup run after partial initialization or a skip? Guard resources by
  their actual lifetime. Do not assume every skipped test created no resources.
- If a module changes `always_rollback`, determine which state it must restore.
  Do not silently disable required isolation because a backend lacks snapshots.
  Check whether explicit cleanup is sufficient or the scenario needs a backend
  with rollback support.
- On transactional systems, are installation changes active before the next
  command uses them? Check package helpers, apply/reboot behavior, and writable
  paths. Do not infer filesystem properties from an old PR's default layout.
- Does cleanup preserve useful failure evidence and avoid masking the original
  error? Verify the failure behavior of cleanup commands.
- Does a new helper have one clear responsibility and a real caller? Prefer
  existing APIs when their behavior fits. Do not require a new abstraction for
  every repeated line or expand a focused fix into a broad refactor.

See [Review evidence](evidence.md) for the PR discussions behind these checks.
