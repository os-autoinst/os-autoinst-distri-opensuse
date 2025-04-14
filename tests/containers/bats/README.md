
This directory contains [BATS framework](https://github.com/bats-core/bats-core) tests for the following packages:

| package | upstream location |
| --- | --- |
| [buildah](bats/buildah.pm)	| https://github.com/containers/buildah/tree/main/tests |
| [netavark](bats/netavark.pm) | https://github.com/containers/netavark/tree/main/test |
| [podman](bats/podman.pm) | https://github.com/containers/podman/tree/main/test/system |
| [runc](bats/runc.pm) | https://github.com/opencontainers/runc/tree/main/tests/integration |
| [skopeo](bats/skopeo.pm) | https://github.com/containers/skopeo/tree/main/systemtest |

Notes:
  - The above directories contain tests in each `.bats` file.
  - Buried in [git history](https://github.com/os-autoinst/os-autoinst-distri-opensuse/commit/0aa21f2cee97a91f35a675199c5d1b125a6e88ff) is the test for [aardvark-dns](https://github.com/containers/aardvark-dns/tree/main/test), disabled due to incomplete network configuration of openQA workers.
  - Library code is found in [lib/containers/bats.pm](../../../lib/containers/bats.pm)

The tests rely on some variables:

| variable | description |
| --- | --- |
| `BATS_PACKAGE` | `buildah` `netavark` `podman` `runc` `skopeo` |
| `BATS_VERSION` | Version of [bats](https://github.com/bats-core/bats-core) to use |
| `ENABLE_SELINUX` | Set to `0` to put SELinux in permissive mode |
| `OCI_RUNTIME` | OCI runtime to use: `runc` or `crun` |

## buildah

| variable | description |
| --- | --- |
| `BUILDAH_STORAGE_DRIVER` | Storage driver used for buildah: `vfs` or `overlay` |
| `BATS_URL` | URL to get the tests from |
| `BATS_TESTS` | Run only the specified tests, otherwise: |
| `BATS_SKIP` | Skip subtests on ALL scenarios below: |
| `BATS_SKIP_ROOT` | Skip subtests for root user |
| `BATS_SKIP_USER` | Skip subtests for non-root user |

## netavark

| variable | description |
| --- | --- |
| `BATS_URL` | URL to get the tests from |
| `BATS_TESTS` | Run only the specified tests, otherwise: |
| `BATS_SKIP` | Skip tests on ALL scenarios |

## podman

| variable | description |
| --- | --- |
| `BATS_URL` | URL to get the tests from |
| `BATS_TESTS` | Run only the specified tests, otherwise: |
| `BATS_SKIP` | Skip subtests on ALL scenarios below: |
| `BATS_SKIP_ROOT_LOCAL` | Skip subtests for root / local |
| `BATS_SKIP_ROOT_REMOTE` | Skip subtests root / remote |
| `BATS_SKIP_USER_LOCAL` | Skip subtests for rootless / local |
| `BATS_SKIP_USER_REMOTE` | Skip subtests for rootless / remote |

## runc

| variable | description |
| --- | --- |
| `BATS_URL` | URL to get the tests from |
| `BATS_TESTS` | Run only the specified tests, otherwise: |
| `BATS_SKIP` | Skip subtests on ALL scenarios below: |
| `BATS_SKIP_ROOT` | Skip subtests for root user |
| `BATS_SKIP_USER` | Skip subtests for non-root user |

## skopeo

| variable | description |
| --- | --- |
| `BATS_URL` | URL to get the tests from |
| `BATS_TESTS` | Run only the specified tests, otherwise: |
| `BATS_SKIP` | Skip subtests on ALL scenarios below: |
| `BATS_SKIP_ROOT` | Skip subtests for root user |
| `BATS_SKIP_USER` | Skip subtests for non-root |

NOTES
 - The special value `all` may be used to skip all tests.
 - The special value `none` should be used to avoid skipping any subtests.

## Summary of variables

| variable | buildah | netavark | podman | runc | skopeo |
|---|:---:|:---:|:---:|:---:|:---:|
| `BATS_URL` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `BATS_TESTS` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `BATS_SKIP` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `BATS_SKIP_ROOT` | ✅ | | | ✅ | ✅ |
| `BATS_SKIP_USER` | ✅ | | | ✅ | ✅ |
| `BATS_SKIP_ROOT_LOCAL` | | | ✅ | | |
| `BATS_SKIP_ROOT_REMOTE` | | | ✅ | | |
| `BATS_SKIP_USER_LOCAL` | | | ✅ | | |
| `BATS_SKIP_USER_REMOTE` | | | ✅ | | |

## openQA schedules

- [Tumbleweed](https://github.com/os-autoinst/opensuse-jobgroups/blob/master/job_groups/opensuse_tumbleweed.yaml)
- [Latest SLE 16](https://gitlab.suse.de/qac/qac-openqa-yaml/-/blob/master/containers/latest_host_sle16.yaml)
- [Latest SLES 15](https://gitlab.suse.de/qac/qac-openqa-yaml/-/blob/master/containers/latest_host.yaml)
- [SLES 15-SP3+](https://gitlab.suse.de/qac/qac-openqa-yaml/-/blob/master/containers/updates.yaml)

## Workflow

- To debug SELinux issues you may check the audit log & clone a job with `ENABLE_SELINUX=0`
- To debug runtime issues you may clone a job with `OCI_RUNTIME=crun`.  The default OCI runtime is `runc` on all openSUSE & SUSE products except SLEM 6.0 & 6.1

## Tools

- [susebats](https://github.com/ricardobranco777/susebats)
