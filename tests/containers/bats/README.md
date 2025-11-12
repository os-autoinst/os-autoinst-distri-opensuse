
This directory contains [BATS framework](https://github.com/bats-core/bats-core) tests for the following packages:

| package | tests |
| --- | --- |
| [aardvark-dns](aardvark.pm) | https://github.com/containers/aardvark-dns/tree/main/test |
| [buildah](buildah.pm) | https://github.com/containers/buildah/tree/main/tests |
| [conmon](conmon.pm) | https://github.com/containers/conmon/tree/main/test |
| [netavark](netavark.pm) | https://github.com/containers/netavark/tree/main/test |
| [podman](podman.pm) | https://github.com/containers/podman/tree/main/test/system |
| [runc](runc.pm) | https://github.com/opencontainers/runc/tree/main/tests/integration |
| [skopeo](skopeo.pm) | https://github.com/containers/skopeo/tree/main/systemtest |
| [umoci](umoci.pm) | https://github.com/opencontainers/umoci/tree/main/test |

Note: For buildah we also run the [conformance tests](https://github.com/containers/buildah/blob/main/tests/conformance/README.md)

Library code is found in [lib/containers/bats.pm](../../../lib/containers/bats.pm)

The tests rely on some variables:

| variable | description |
| --- | --- |
| `BATS_PACKAGE` | `aardvark-dns` `buildah` `conmon` `netavark` `podman` `runc` `skopeo` `umoci` |
| `BATS_VERSION` | Version of [bats](https://github.com/bats-core/bats-core) to use |
| `GITHUB_PATCHES` | List of github PR id's containing upstream test patches |
| `GITHUB_REPO` | Repo & branch in the form `[<GITHUB_ORG>]#<BRANCH>` |
| `OCI_RUNTIME` | OCI runtime to use: `runc` or `crun` |
| `RUN_TESTS` | Run only the specified tests |
| `SELINUX_ENFORCE` | Set to `0` to put SELinux in permissive mode |
| `TEST_PACKAGES` | List of optional package URL's |
| `TEST_REPOS` | List of optional test repositories |

NOTES
- `GITHUB_REPO` can be `SUSE#branch` or a tag `v1.2.3`
- `GITHUB_PATCHES` can contain full URL's like `https://github.com/containers/podman/pull/25918.patch`
- `TEST_PACKAGES` may be used to test candidate kernels (KOTD, PTF, etc) and other packages.
- `TEST_REPOS` may be used to test candidate packages outside the usual maintenance workflow.

`GITHUB_PATCHES` are in [patches.yaml](../../../data/containers/patches.yaml)

## Workflow

- To debug SELinux issues you may check the audit log & clone a job with `ENABLE_SELINUX=0`
- To debug individual tests you may clone a job with `RUN_TESTS`
- You can also test individual tests from the latest version in the `main` branch with `BATS_URL=main`
- The BATS output is collected in the log files with the `.tap.txt` extension
- The commands are collected in a log file ending with `-commands.txt`

## Adding patches to `GITHUB_PATCHES`

Note: We add the [patches](../../../data/containers/patches) to our tree to avoid hitting secondary rate-limits at Github.

1. Identify the commit that fixes the issue.
1. Identify the PR ID associated with the commit with `gh pr list --search $COMMIT_SHA --state merged`
1. Download with `wget https://github.com/containers/$PACKAGE/pull/$ID.patch` (`runc` is under `opencontainers`)
1. Add the ID to `GITHUB_PATCHES` sorted numerically as we assume lower numbered are merged earlier.
1. Add verification runs with the above setting to the PR.
1. Adjust YAML schedule.

## Warning

- If you want to run container `bats` tests manually, do so in a fresh VM, otherwise you risk losing all your volumes, images & containers.
Please add this warning on each bug report you open when adding instructions on how to reproduce an issue.

## openQA schedules

- [Tumbleweed](https://github.com/os-autoinst/opensuse-jobgroups/blob/master/job_groups/opensuse_tumbleweed.yaml)
- [Tumbleweed aarch64](https://github.com/os-autoinst/opensuse-jobgroups/blob/master/job_groups/opensuse_tumbleweed_aarch64.yaml)
- [Tumbleweed ppc64le](https://github.com/os-autoinst/opensuse-jobgroups/blob/master/job_groups/opensuse_tumbleweed_powerpc.yaml)
- [SLES 16.0](https://gitlab.suse.de/qac/qac-openqa-yaml/-/blob/master/containers/latest_host_sle16.yaml)
- [SLES 15-SP4+](https://gitlab.suse.de/qac/qac-openqa-yaml/-/blob/master/containers/updates.yaml)

## openQA jobs

With runc as `OCI_RUNTIME`

| Product / Package     | aardvark-dns       | buildah          | conmon             | netavark           | podman             | runc               | skopeo             | umoci |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| openSUSE Tumbleweed   | [![tw_al]][tw_a]   | [![tw_bl]][tw_b] | [![tw_cl]][tw_c]   | [![tw_nl]][tw_n]   | [![tw_pl]][tw_p]   | [![tw_rl]][tw_r]   | [![tw_sl]][tw_s]   | [![tw_ul]][tw_u] |
| openSUSE TW (aarch64) | [![twa_al]][twa_a] |                  |                    | [![twa_nl]][twa_n] | [![twa_pl]][twa_p] | [![twa_rl]][twa_r] | [![twa_sl]][twa_s] | |
| openSUSE TW (ppc64le) | [![twp_al]][twp_a] |                  |                    | [![twp_nl]][twp_n] | [![twp_pl]][twp_p] | [![twp_rl]][twp_r] | [![twp_sl]][twp_s] | |
| SLES 16.0             | [![logo]][s16_a]   | [![logo]][s16_b] | [![logo]][s16_c]   | [![logo]][s16_n]   | [![logo]][s16_p]   | [![logo]][s16_r]   | [![logo]][s16_s]   | |
| SLES 16.0 (aarch64)   | [![logo]][s16a_a]  |                  |                    | [![logo]][s16a_n]  | [![logo]][s16a_p]  | [![logo]][s16a_r]  | [![logo]][s16a_s]  | |
| SLES 16.0 (ppc64le)   | [![logo]][s16p_a]  |                  |                    | [![logo]][s16p_n]  | [![logo]][s16p_p]  | [![logo]][s16p_r]  | [![logo]][s16p_s]  | |
| SLES 16.0 (s390x)     | [![logo]][s16s_a]  |                  |                    | [![logo]][s16s_n]  | [![logo]][s16s_p]  | [![logo]][s16s_r]  | [![logo]][s16s_s]  | |
| SLES 15 SP7           | [![logo]][sp7_a]   | [![logo]][sp7_b] |                    | [![logo]][sp7_n]   | [![logo]][sp7_p]   | [![logo]][sp7_r]   | [![logo]][sp7_s]   | |
| SLES 15 SP7 (aarch64) | [![logo]][sp7a_a]  |                  |                    | [![logo]][sp7a_n]  | [![logo]][sp7a_p]  | [![logo]][sp7a_r]  | [![logo]][sp7a_s]  | |
| SLES 15 SP7 (s390x)   |                    |                  |                    |                    |                    | [![logo]][sp7s_r]  | [![logo]][sp7s_s]  | |
| SLES 15 SP6           | [![logo]][sp6_a]   | [![logo]][sp6_b] |                    | [![logo]][sp6_n]   | [![logo]][sp6_p]   | [![logo]][sp6_r]   | [![logo]][sp6_s]   | |
| SLES 15 SP6 (aarch64) | [![logo]][sp6a_a]  |                  |                    | [![logo]][sp6a_n]  | [![logo]][sp6a_p]  | [![logo]][sp6a_r]  | [![logo]][sp6a_s]  | |
| SLES 15 SP6 (s390x)   |                    |                  |                    |                    |                    | [![logo]][sp6s_r]  | [![logo]][sp6s_s]  | |
| SLES 15 SP5           |                    | [![logo]][sp5_b] |                    |                    |                    | [![logo]][sp5_r]   | [![logo]][sp5_s]   | |
| SLES 15 SP5 (aarch64) |                    |                  |                    |                    |                    | [![logo]][sp5a_r]  | [![logo]][sp5a_s]  | |
| SLES 15 SP5 (s390x)   |                    |                  |                    |                    |                    | [![logo]][sp5s_r]  | [![logo]][sp5s_s]  | |
| SLES 15 SP4           |                    | [![logo]][sp4_b] |                    |                    |                    | [![logo]][sp4_r]   | [![logo]][sp4_s]   | |
| SLES 15 SP4 (aarch64) |                    |                  |                    |                    |                    | [![logo]][sp4a_r]  | [![logo]][sp4a_s]  | |
| SLES 15 SP4 (s390x)   |                    |                  |                    |                    |                    | [![logo]][sp4s_r]  | [![logo]][sp4s_s]  | |

openSUSE Tumbleweed with crun as `OCI_RUNTIME`

| Architecture / Package | buildah | podman |
|:---:|:---:|:---:|
| aarch64 |                    | [![twa_plc]][twa_pc] |
| ppc64le |                    | [![twp_plc]][twp_pc] |
| x86_64  | [![tw_blc]][tw_bc] | [![tw_plc]][tw_pc]   |

[logo]: logo.svg

[tw_blc]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_buildah_testsuite_crun
[tw_bc]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_buildah_testsuite_crun
[tw_plc]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_testsuite_crun
[tw_pc]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_testsuite_crun
[twa_plc]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_podman_testsuite_crun
[twa_pc]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_podman_testsuite_crun
[twp_plc]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_podman_testsuite_crun
[twp_pc]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_podman_testsuite_crun

[tw_al]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_aardvark_testsuite
[tw_a]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_aardvark_testsuite
[tw_bl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_buildah_testsuite
[tw_b]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_buildah_testsuite
[tw_cl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_conmon_testsuite
[tw_c]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_conmon_testsuite
[tw_nl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_netavark_testsuite
[tw_n]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_netavark_testsuite
[tw_pl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_testsuite
[tw_p]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_testsuite
[tw_rl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_runc_testsuite
[tw_r]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_runc_testsuite
[tw_sl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_skopeo_testsuite
[tw_s]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_skopeo_testsuite
[tw_ul]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_umoci_testsuite
[tw_u]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_umoci_testsuite

[twa_al]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_aardvark_testsuite
[twa_a]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_aardvark_testsuite
[twa_nl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_netavark_testsuite
[twa_n]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_netavark_testsuite
[twa_pl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_podman_testsuite
[twa_p]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_podman_testsuite
[twa_rl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_runc_testsuite
[twa_r]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_runc_testsuite
[twa_sl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_skopeo_testsuite
[twa_s]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_skopeo_testsuite

[twp_al]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_aardvark_testsuite
[twp_a]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_aardvark_testsuite
[twp_nl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_netavark_testsuite
[twp_n]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_netavark_testsuite
[twp_pl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_podman_testsuite
[twp_p]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_podman_testsuite
[twp_rl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_runc_testsuite
[twp_r]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_runc_testsuite
[twp_sl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_skopeo_testsuite
[twp_s]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_skopeo_testsuite

[s16_a]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=x86_64&test=aardvark_testsuite
[s16_b]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=x86_64&test=buildah_testsuite
[s16_c]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=x86_64&test=conmon_testsuite
[s16_n]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=x86_64&test=netavark_testsuite
[s16_p]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=x86_64&test=podman_testsuite
[s16_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=x86_64&test=runc_testsuite
[s16_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=x86_64&test=skopeo_testsuite

[s16a_a]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=aarch64&test=aardvark_testsuite
[s16a_n]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=aarch64&test=netavark_testsuite
[s16a_p]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=aarch64&test=podman_testsuite
[s16a_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=aarch64&test=runc_testsuite
[s16a_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=aarch64&test=skopeo_testsuite

[s16p_a]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=ppc64le&test=aardvark_testsuite
[s16p_n]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=ppc64le&test=netavark_testsuite
[s16p_p]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=ppc64le&test=podman_testsuite
[s16p_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=ppc64le&test=runc_testsuite
[s16p_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=ppc64le&test=skopeo_testsuite

[s16s_a]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=s390x&test=aardvark_testsuite
[s16s_n]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=s390x&test=netavark_testsuite
[s16s_p]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=s390x&test=podman_testsuite
[s16s_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=s390x&test=runc_testsuite
[s16s_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=s390x&test=skopeo_testsuite

[sp7_a]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=x86_64&test=aardvark_testsuite
[sp7_b]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=x86_64&test=buildah_testsuite
[sp7_n]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=x86_64&test=netavark_testsuite
[sp7_p]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=x86_64&test=podman_testsuite
[sp7_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=x86_64&test=runc_testsuite
[sp7_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=x86_64&test=skopeo_testsuite

[sp7a_a]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=aarch64&test=aardvark_testsuite
[sp7a_n]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=aarch64&test=netavark_testsuite
[sp7a_p]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=aarch64&test=podman_testsuite
[sp7a_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=aarch64&test=runc_testsuite
[sp7a_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=aarch64&test=skopeo_testsuite

[sp7s_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=s390x&test=runc_testsuite
[sp7s_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP7&arch=s390x&test=skopeo_testsuite

[sp6_a]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=x86_64&test=aardvark_testsuite
[sp6_b]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=x86_64&test=buildah_testsuite
[sp6_n]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=x86_64&test=netavark_testsuite
[sp6_p]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=x86_64&test=podman_testsuite
[sp6_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=x86_64&test=runc_testsuite
[sp6_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=x86_64&test=skopeo_testsuite

[sp6a_a]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=aarch64&test=aardvark_testsuite
[sp6a_n]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=aarch64&test=netavark_testsuite
[sp6a_p]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=aarch64&test=podman_testsuite
[sp6a_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=aarch64&test=runc_testsuite
[sp6a_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=aarch64&test=skopeo_testsuite

[sp6s_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=s390x&test=runc_testsuite
[sp6s_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP6&arch=s390x&test=skopeo_testsuite

[sp5_b]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP5&arch=x86_64&test=buildah_testsuite
[sp5_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP5&arch=x86_64&test=runc_testsuite
[sp5_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP5&arch=x86_64&test=skopeo_testsuite

[sp5a_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP5&arch=aarch64&test=runc_testsuite
[sp5a_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP5&arch=aarch64&test=skopeo_testsuite

[sp5s_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP5&arch=s390x&test=runc_testsuite
[sp5s_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP5&arch=s390x&test=skopeo_testsuite

[sp4_b]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP4&arch=x86_64&test=buildah_testsuite
[sp4_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP4&arch=x86_64&test=runc_testsuite
[sp4_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP4&arch=x86_64&test=skopeo_testsuite

[sp4a_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP4&arch=aarch64&test=runc_testsuite
[sp4a_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP4&arch=aarch64&test=skopeo_testsuite

[sp4s_r]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP4&arch=ppc44le&test=runc_testsuite
[sp4s_s]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Server-DVD-Updates&version=15-SP4&arch=ppc44le&test=skopeo_testsuite

## Tools

- [susebats](https://github.com/ricardobranco777/susebats)
