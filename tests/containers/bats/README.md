
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
- [SLES 16.x](https://gitlab.suse.de/qac/qac-openqa-yaml/-/blob/master/containers/latest_host_sle16.yaml)
- [SLES 15-SP4+](https://gitlab.suse.de/qac/qac-openqa-yaml/-/blob/master/containers/updates.yaml)

## Tools

- [susebats](https://github.com/ricardobranco777/susebats)
