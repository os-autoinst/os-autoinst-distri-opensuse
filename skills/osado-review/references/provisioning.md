<!-- SPDX-License-Identifier: FSFAP -->

# SUT provisioning helpers

Use this guidance when a change adds or modifies system-under-test (SUT)
setup, or moves setup code from `tests/` into `lib/`. It is a design
recommendation. Code location alone is not a defect or a mandatory rejection.
Apply the current contribution and area rules first.

## Decide what to extract

Prefer a library helper when a setup operation is reused by real callers, or
when a substantial operation has a clear responsibility that can be reviewed
and tested independently of the scenario. Examples include creating a loop
device, configuring an NFS export, and adding an IPsec policy.

Keep the scenario readable in the test module: select the case and resources,
call setup operations in order, run the workload, check the expected result,
and arrange cleanup. Do not move a complete test flow into a generic
`prepare_sut` helper just to reduce the test module's line count.

| Code in the change | Review direction |
| --- | --- |
| Repeated package installation with product-specific handling | Check whether `lib/package_utils.pm` already supplies the required behavior. |
| A coherent block-device, network, or NFS operation | Consider the corresponding module under `lib/Kernel/` for kernel-area callers. |
| Provider-specific instance setup | Check the existing `lib/publiccloud/` interfaces and their consumers. |
| Scenario-specific device selection, workload order, or expected result | Keep the decision explicit in the test; pass selected values to helpers. |
| A short command used once and already clear | Keep it local unless extraction provides a concrete benefit. |
| Reusable verification logic | It can live in a domain library, but keep its purpose distinct from provisioning and make its assertions explicit. |

Search for existing helpers and callers before proposing a new API. Extend the
module that owns the operation. Use `CONTRIBUTING.md` and `.github/CODEOWNERS`
to identify that area. Do not place a domain-specific helper in `lib/utils.pm`
solely because several tests need it. Do not create a new general provisioning
framework for hypothetical future callers.

## Review the helper contract

- Give the operation a specific name. Prefer separate operations for reading
  state, changing it, and running a workload when callers need them separately.
- Make the required inputs and execution context clear: device, path, peer,
  instance, selected console, and required privileges. Follow the established
  API style of the owning library. Avoid hidden dependencies on a particular
  test object or schedule; do not require passing every framework variable.
- State what success means. A required setup command must not fail silently.
  Helpers can use `assert_script_run` or other asserting APIs to enforce their
  contract. Distinguish setup failures from expected negative test results.
- Make side effects visible, especially reboots, console switches, mounts,
  service changes, and pending transactional updates. Preserve the existing
  activation rules; applying a transaction is not always a substitute for reboot.
- Define who releases resources and restores prior state. Check partial setup
  failures and the caller's failure hooks. Return resource identifiers or state
  when the caller needs them for cleanup. Do not silently transfer cleanup
  ownership during extraction.
- Check repeated calls only where retries or multiple callers make them
  possible. State whether the helper reuses, replaces, or rejects existing
  resources. Do not demand that every destructive provisioning operation be
  safe to repeat without a demonstrated need.
- Keep product-regression assertions visible. If provisioning installs,
  enables, or repairs the component whose default state is under test, it can
  hide the defect. Separate prerequisite setup from modification of the
  behavior the test is intended to verify.

## Review the extraction

For a move without intended behavior changes, compare the original and new
command order, arguments, defaults, return values, exceptions, console context,
and cleanup. Update imports and real callers. Check that no code in `lib/`
must load a scheduled test module to perform the extracted operation.

Use existing unit tests to check meaningful helper behavior, including relevant
failure paths. Select openQA runs that execute the changed callers, following
[Verification](verification.md). Separate unrelated fixes into atomic commits;
do not require a separate commit for every file in one coherent extraction.

When suggesting extraction, identify the code block, target library, proposed
operation and inputs, and concrete benefit. Label it as a design suggestion
unless there is a demonstrated defect or an applicable project rule. A focused
fix need not include a larger cleanup of pre-existing provisioning code.

## Basis and examples

The [kernel helper discussion in PR #26015](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26015#discussion_r3550107365)
asks for small operations that read and set I/O limits, with workload control
left to the caller. The proposed throttling implementation was later removed;
its suggested function names are not existing API requirements.

PR #26347 moved pNFS setup and capture operations into domain libraries after
review. Current examples include `create_loop_backing_file` and
`attach_loop_device` in `lib/Kernel/block_dev.pm`, and `setup_pnfs_client` in
`lib/Kernel/nfs.pm`. These illustrate placement, not a guarantee that every
existing helper meets all of the checks above. See [Review evidence](evidence.md)
for the sample and its limits.
