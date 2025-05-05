
This directory contains [BATS framework](https://github.com/bats-core/bats-core) tests for the following packages:

- [aardvark](https://github.com/containers/aardvark-dns/tree/main/test)
- [buildah](https://github.com/containers/buildah/tree/main/tests)
- [netavark](https://github.com/containers/netavark/tree/main/test)
- [podman](https://github.com/containers/podman/tree/main/test/system)
- [runc](https://github.com/opencontainers/runc/tree/main/tests/integration)
- [skopeo](https://github.com/containers/skopeo/tree/main/systemtest)

Library code is found in [lib/containers/bats.pm](../../../lib/containers/bats.pm)

The tests rely on some variables:

| variable | description |
| --- | --- |
| `BATS_PACKAGE` | `aardvark` `buildah` `netavark` `podman` `runc` `skopeo` |
| `BATS_PATCHES` | List of github PR id's containing upstream test patches |
| `BATS_TESTS` | Run only the specified tests |
| `BATS_URL` | URL to get the tests from. The default depends on the package version |
| `BATS_VERSION` | Version of [bats](https://github.com/bats-core/bats-core) to use |
| `BUILDAH_STORAGE_DRIVER` | Storage driver used for buildah: `vfs` or `overlay` |
| `ENABLE_SELINUX` | Set to `0` to put SELinux in permissive mode |
| `OCI_RUNTIME` | OCI runtime to use: `runc` or `crun` |

NOTES
- `BATS_URL` can be a full URL to the tarball in github, `SUSE#branch` or a tag `v1.2.3`
- `BATS_PATCHES` can contain full URL's like `https://github.com/containers/podman/pull/25918.diff`

### Summary of the `BATS_SKIP` variables

| variable | description | aardvark | buildah | netavark | podman | runc | skopeo |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|
| `BATS_SKIP` | Skip tests on ALL scenarios              |✅|✅|✅|✅|✅|✅|
| `BATS_SKIP_ROOT` | Skip tests for root user            |  |✅|  |  |✅|✅|
| `BATS_SKIP_USER` | Skip tests for rootless             |  |✅|  |  |✅|✅|
| `BATS_SKIP_ROOT_LOCAL` | Skip tests for root / local   |  |  |  |✅|  |  |
| `BATS_SKIP_ROOT_REMOTE` | Skip tests for root / remote |  |  |  |✅|  |  |
| `BATS_SKIP_USER_LOCAL` | Skip tests for user / local   |  |  |  |✅|  |  |
| `BATS_SKIP_USER_REMOTE` | Skip tests for user / remote |  |  |  |✅|  |  |

NOTES
 - The special value `all` may be used to skip all tests.
 - We don't really skip jobs, only ignore their failures.

## Workflow

- To debug SELinux issues you may check the audit log & clone a job with `ENABLE_SELINUX=0`
- To debug runtime issues you may clone a job with `OCI_RUNTIME=crun`.  The default OCI runtime is `runc` on all openSUSE & SUSE products except SLEM 6.0 & 6.1
- To debug buildah issues you may clone a job with `BUILDAH_STORAGE_DRIVER=vfs`
- To debug individual tests you may clone a job with `BATS_TESTS`
- You can also test individual tests from the latest version in the `main` branch with `BATS_URL=main`
- The BATS output is collected in the log files with the `.tap` extension
- The commands are collected in a log file ending with `-commands.txt`

## Warning

- If you want to run `bats` tests manually, do so in a fresh VM, otherwise you risk losing all your volumes, images & containers.
Please add this warning on each bug report you open when adding instructions on how to reproduce an issue.

## openQA schedules

- [Tumbleweed](https://github.com/os-autoinst/opensuse-jobgroups/blob/master/job_groups/opensuse_tumbleweed.yaml)
- [Latest SLE 16](https://gitlab.suse.de/qac/qac-openqa-yaml/-/blob/master/containers/latest_host_sle16.yaml)
- [Latest SLES 15](https://gitlab.suse.de/qac/qac-openqa-yaml/-/blob/master/containers/latest_host.yaml)
- [SLES 15-SP4+](https://gitlab.suse.de/qac/qac-openqa-yaml/-/blob/master/containers/updates.yaml)

NOTES
- As of now, all jobs are `x86_64` only.

## openQA jobs

| Product             | aardvark         | buildah          | netavark         | podman           | runc             | skopeo |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| openSUSE Tumbleweed | [![tw_al]][tw_a] | [![tw_bl]][tw_b] | [![tw_nl]][tw_n] | [![tw_pl]][tw_p] | [![tw_rl]][tw_r] | [![tw_sl]][tw_s] |
| Latest SLES 16      |                  | [![logo]][s16_b] | [![logo]][s16_n] | [![logo]][s16_p] | [![logo]][s16_r] | [![logo]][s16_s] |
| Latest SLES 15      |                  | [![logo]][s15_b] | [![logo]][s15_n] | [![logo]][s15_p] | [![logo]][s15_r] | [![logo]][s15_s] |
| SLES 15 SP7         |                  | [![logo]][sp7_b] | [![logo]][sp7_n] | [![logo]][sp7_p] | [![logo]][sp7_r] | [![logo]][sp7_s] |
| SLES 15 SP6         |                  | [![logo]][sp6_b] | [![logo]][sp6_n] | [![logo]][sp6_p] | [![logo]][sp6_r] | [![logo]][sp6_s] |
| SLES 15 SP5         |                  | [![logo]][sp5_b] | [![logo]][sp5_n] |                  | [![logo]][sp5_r] | [![logo]][sp5_s] |
| SLES 15 SP4         |                  | [![logo]][sp4_b] |                  |                  | [![logo]][sp4_r] | [![logo]][sp4_s] |

[logo]: logo.svg

[tw_al]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_aardvark_testsuite
[tw_a]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_aardvark_testsuite
[tw_bl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_buildah_testsuite
[tw_b]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_buildah_testsuite
[tw_nl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_netavark_testsuite
[tw_n]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_netavark_testsuite
[tw_pl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_testsuite
[tw_p]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_testsuite
[tw_rl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_runc_testsuite
[tw_r]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_runc_testsuite
[tw_sl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_skopeo_testsuite
[tw_s]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_skopeo_testsuite

[s16_b]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=x86_64&test=buildah_testsuite
[s16_n]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=x86_64&test=netavark_testsuite
[s16_p]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=x86_64&test=podman_testsuite
[s16_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=x86_64&test=runc_testsuite
[s16_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=x86_64&test=skopeo_testsuite

[s15_b]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=15-SP7&arch=x86_64&test=buildah_testsuite
[s15_n]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=15-SP7&arch=x86_64&test=netavark_testsuite
[s15_p]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=15-SP7&arch=x86_64&test=podman_testsuite
[s15_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=15-SP7&arch=x86_64&test=runc_testsuite
[s15_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=15-SP7&arch=x86_64&test=skopeo_testsuite

[sp7_b]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=x86_64&test=buildah_testsuite
[sp7_n]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=x86_64&test=netavark_testsuite
[sp7_p]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=x86_64&test=podman_testsuite
[sp7_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=x86_64&test=runc_testsuite
[sp7_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=x86_64&test=skopeo_testsuite

[sp6_b]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=x86_64&test=buildah_testsuite
[sp6_n]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=x86_64&test=netavark_testsuite
[sp6_p]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=x86_64&test=podman_testsuite
[sp6_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=x86_64&test=runc_testsuite
[sp6_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=x86_64&test=skopeo_testsuite

[sp5_b]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP5&arch=x86_64&test=buildah_testsuite
[sp5_n]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP5&arch=x86_64&test=netavark_testsuite
[sp5_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP5&arch=x86_64&test=runc_testsuite
[sp5_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP5&arch=x86_64&test=skopeo_testsuite

[sp4_b]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP4&arch=x86_64&test=buildah_testsuite
[sp4_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP4&arch=x86_64&test=runc_testsuite
[sp4_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP4&arch=x86_64&test=skopeo_testsuite

## Skipped tests

### buildah

| test | reason |
| --- | --- |
| lots of them | https://github.com/containers/buildah/issues/6071 |

### podman

| test | reason |
| --- | --- |
| [080-pause] | https://github.com/opencontainers/runc/pull/4709 |
| [252-quadlet] | unknown |
| [505-networking-pasta] | https://bugs.passt.top/show_bug.cgi?id=49 |

[080-pause]: https://github.com/containers/podman/blob/main/test/system/080-pause.bats
[252-quadlet]: https://github.com/containers/podman/blob/main/test/system/252-quadlet.bats
[505-networking-pasta]: https://github.com/containers/podman/blob/main/test/system/505-networking-pasta.bats

### runc

| test | reason |
| --- | --- |
| [cgroups] | `io.bfq.weight: operation not supported` |
| [checkpoint] | https://github.com/checkpoint-restore/criu/issues/2650 |

[cgroups]: https://github.com/opencontainers/runc/blob/main/tests/integration/cgroups.bats
[checkpoint]: https://github.com/opencontainers/runc/blob/main/tests/integration/checkpoint.bats

## Tools

- [susebats](https://github.com/ricardobranco777/susebats)
