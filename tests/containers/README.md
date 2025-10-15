
Overview of upstream tests

In addition to the [BATS](bats/) tests we currently have tests for:

| project | tests |
| --- | --- |
| [docker-buildx](docker_buildx.pm) | https://github.com/docker/cli/tree/master/tests |
| [docker-cli](docker_cli.pm) | https://github.com/docker/cli/tree/master/e2e |
| [docker-compose](docker_compose.pm) | https://github.com/docker/compose/tree/main/pkg/e2e |
| [docker-py](python_runtime.pm) | https://github.com/docker/docker-py/tree/main/tests |
| [moby](docker_runtime.pm) | https://github.com/moby/moby/tree/master/integration |
| [podman-py](python_runtime.pm) | https://github.com/containers/podman-py/tree/main/podman/tests |
| [podman](podman_e2e.pm) | https://github.com/containers/podman/tree/main/test/e2e |

Library code is found in [lib/containers/bats.pm](../../../lib/containers/bats.pm)

The tests rely on some variables:

| variable | description |
| --- | --- |
| `GITHUB_PATCHES` | List of github PR id's containing upstream test patches |
| `OCI_RUNTIME` | OCI runtime to use: `runc` or `crun` |

These are defined in [skip.yaml](../../data/containers/bats/skip.yaml)

## openQA jobs

| Testsuite / Product | openSUSE Tumbleweed | Tumbleweed (aarch64) | SLES 16.0 |
|:---:|:---:|:---:|:---|
| `docker_testsuite`  | [![tw_dl]][tw_d]    | [![twa_dl]][twa_d] | [![logo]][s16_d] |
| `podman_e2e`        | [![tw_pl]][tw_p]    | | |
| `podman_e2e_crun`   | [![tw_pcl]][tw_pc]  | | |

[logo]: bats/logo.svg

[twa_dl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_docker_testsuite
[twa_d]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_docker_testsuite

[tw_dl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_docker_testsuite
[tw_d]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_docker_testsuite

[tw_pl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_e2e
[tw_p]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_e2e

[tw_pcl]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_e2e_crun
[tw_pc]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_e2e_crun

[s16_d]: https://openqa.suse.de/tests/latest?distri=sle&flavor=Online&version=16.0&arch=x86_64&test=docker_testsuite
