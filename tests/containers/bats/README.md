
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
  - The scheduling is done in [lib/main_containers.pm](../../../lib/main_containers.pm)

The tests rely on some variables:

| variable | description |
| --- | --- |
| `ENABLE_SELINUX` | Set to `0` to put SELinux in permissive mode |
| `OCI_RUNTIME` | OCI runtime to use: `runc` or `crun` |

## buildah

| variable | description |
| --- | --- |
| `BUILDAH_STORAGE_DRIVER` | Storage driver used for buildah: `vfs` or `overlay` |
| `BUILDAH_BATS_URL` | URL to get the tests from |
| `BUILDAH_BATS_TESTS` | Run only the specified tests, otherwise: |
| `BUILDAH_BATS_SKIP` | Skip subtests on ALL scenarios below: |
| `BUILDAH_BATS_SKIP_ROOT` | Skip subtests for root user |
| `BUILDAH_BATS_SKIP_USER` | Skip subtests for non-root user |

## netavark

| variable | description |
| --- | --- |
| `NETAVARK_BATS_URL` | URL to get the tests from |
| `NETAVARK_BATS_TESTS` | Run only the specified tests, otherwise: |
| `NETAVARK_BATS_SKIP` | Skip tests on ALL scenarios |

## podman

| variable | description |
| --- | --- |
| `PODMAN_BATS_URL` | URL to get the tests from |
| `PODMAN_BATS_TESTS` | Run only the specified tests, otherwise: |
| `PODMAN_BATS_SKIP` | Skip subtests on ALL scenarios below: |
| `PODMAN_BATS_SKIP_ROOT_LOCAL` | Skip subtests for root / local |
| `PODMAN_BATS_SKIP_ROOT_REMOTE` | Skip subtests root / remote |
| `PODMAN_BATS_SKIP_USER_LOCAL` | Skip subtests for rootless / local |
| `PODMAN_BATS_SKIP_USER_REMOTE` | Skip subtests for rootless / remote |

## runc

| variable | description |
| --- | --- |
| `RUNC_BATS_URL` | URL to get the tests from |
| `RUNC_BATS_TESTS` | Run only the specified tests, otherwise: |
| `RUNC_BATS_SKIP` | Skip subtests on ALL scenarios below: |
| `RUNC_BATS_SKIP_ROOT` | Skip subtests for root user |
| `RUNC_BATS_SKIP_USER` | Skip subtests for non-root user |

## skopeo

| variable | description |
| --- | --- |
| `SKOPEO_BATS_URL` | URL to get the tests from |
| `SKOPEO_BATS_TESTS` | Run only the specified tests, otherwise: |
| `SKOPEO_BATS_SKIP` | Skip subtests on ALL scenarios below: |
| `SKOPEO_BATS_SKIP_ROOT` | Skip subtests for root user |
| `SKOPEO_BATS_SKIP_USER` | Skip subtests for non-root |

NOTES
 - The special value `all` may be used to skip all tests.
 - The special value `none` should be used to avoid skipping any subtests.

## openQA schedules

- [Tumbleweed](https://github.com/os-autoinst/opensuse-jobgroups/blob/master/job_groups/opensuse_tumbleweed.yaml)
- [Latest SLE 16](https://gitlab.suse.de/qac/qac-openqa-yaml/-/blob/master/containers/latest_host_sle16.yaml)
- [Latest SLES 15](https://gitlab.suse.de/qac/qac-openqa-yaml/-/blob/master/containers/latest_host.yaml)
- [SLES 15-SP3+](https://gitlab.suse.de/qac/qac-openqa-yaml/-/blob/master/containers/updates.yaml)

## openQA jobs

| product | packages |
| --- | ---|
| opensuse Tumbleweed	| [runc skopeo netavark](https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_bats_testsuite) |
| | [buildah](https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_buildah_testsuite) |
| | [podman](https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_testsuite) |
| Latest SLE 16 | [runc skopeo netavark](https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=x86_64&test=bats_testsuite) |
| | [buildah](https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=x86_64&test=buildah_testsuite) |
| | [podman](https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=x86_64&test=podman_testsuite) |
| Latest SLE 15 | [runc skopeo netavark](https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=15-SP7&arch=x86_64&test=bats_testsuite) |
| |	[buildah](https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=15-SP7&arch=x86_64&test=buildah_testsuite) |
| |	[podman](https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=15-SP7&arch=x86_64&test=podman_testsuite) |
| SLE 15-SP7 | [runc skopeo netavark](https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=x86_64&test=bats_testsuite) |
| | [buildah](https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=x86_64&test=buildah_testsuite) |
| | [podman](https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=x86_64&test=podman_testsuite) |
| SLE 15-SP6 | [runc skopeo netavark](https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=x86_64&test=bats_testsuite) |
| | [buildah](https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=x86_64&test=buildah_testsuite)
| | [podman](https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=x86_64&test=podman_testsuite)
| SLE 15-SP5 | [runc skopeo netavark](https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP5&arch=x86_64&test=bats_testsuite) |
| | [buildah](https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP5&arch=x86_64&test=buildah_testsuite)
| SLE 15-SP4 | [runc skopeo netavark](https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP4&arch=x86_64&test=bats_testsuite) |
| | [buildah](https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP4&arch=x86_64&test=buildah_testsuite) |
| SLE 15-SP3 | [runc skopeo netavark](https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP3&arch=x86_64&test=bats_testsuite) |

## Workflow

- To debug possible SELinux issues you may check the audit log & clone a job with `ENABLE_SELINUX=0`

## Tools

- [susebats](https://github.com/ricardobranco777/susebats)
