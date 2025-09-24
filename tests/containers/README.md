
Overview of upstream tests

In addition to the [BATS](bats/) tests we currently have tests for:

| project | tests |
| --- | --- |
| [docker-compose](docker_compose.pm) | https://github.com/docker/compose/tree/main/pkg/e2e |
| [docker-py](python_runtime.pm) | https://github.com/docker/docker-py/tree/main/tests |
| [podman-py](python_runtime.pm) | https://github.com/containers/podman-py |

Library code is found in [lib/containers/bats.pm](../../../lib/containers/bats.pm)

The tests rely on some variables:

| variable | description |
| --- | --- |
| `GITHUB_PATCHES` | List of github PR id's containing upstream test patches |
| `OCI_RUNTIME` | OCI runtime to use: `runc` or `crun` |

These are defined in [skip.yaml](../../data/containers/bats/skip.yaml)

## openQA jobs

Note: These jobs are scheduled only for the x86_64 architecture.

| Product / Testsuite   | `docker_testsuite` | `podman_e2e` |
|:---:|:---:|:---:|
| openSUSE Tumbleweed   | [![tw_dtl]][tw_dt] | [![tw_ppl]][tw_pp] |
| SLES 16.0             | [![logo]][s16_dt]  | [![logo]][s16_pp]   |

Notes:
- `docker_testsuite` tests `docker-compose` & `docker-py`
- `podman_e2e` tests `podman-py` & the upcoming e2e tests.

[logo]: bats/logo.svg

[tw_dtl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_docker_testsuite
[tw_dt]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_docker_testsuite

[tw_ppl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_e2e
[tw_pp]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_e2e

[s16_dt]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=x86_64&test=docker_testsuite
[s16_pp]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=x86_64&test=podman_e2e
