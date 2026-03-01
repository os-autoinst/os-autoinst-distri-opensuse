
Overview of upstream tests

In addition to the [BATS](bats/) tests we currently have tests for:

| project | tests |
| --- | --- |
| [containerd](containerd.pm) | https://github.com/docker/cli/tree/main/integration |
| [docker-buildx](docker_buildx.pm) | https://github.com/docker/cli/tree/master/tests |
| [docker-cli](docker_cli.pm) | https://github.com/docker/cli/tree/master/e2e |
| [docker-compose](docker_compose.pm) | https://github.com/docker/compose/tree/main/pkg/e2e |
| [docker-py](python_docker.pm) | https://github.com/docker/docker-py/tree/main/tests |
| [moby](docker_engine.pm) | https://github.com/moby/moby/tree/master/integration |
| [podman-py](python_docker.pm) | https://github.com/containers/podman-py/tree/main/podman/tests |
| [podman](podman_e2e.pm) | https://github.com/containers/podman/tree/main/test/e2e |

Library code is found in [lib/containers/bats.pm](../../../lib/containers/bats.pm)

The tests rely on some variables:

| variable | description |
| --- | --- |
| `DEBUG` | Enable all kinds of debugging facilities |
| `DOCKER_EXPERIMENTAL` | Enable experimental features in Docker |
| `DOCKER_MIN_API_VERSION` | Docker minimum API version |
| `DOCKER_SELINUX` | Enable SELinux in Docker daemon |
| `DOCKER_TLS` | Enable TLS in Docker as documented [here](https://docs.docker.com/engine/security/protect-access/) |
| `GITHUB_PATCHES` | List of github PR id's containing upstream test patches |
| `OCI_RUNTIME` | OCI runtime to use: `runc` or `crun` |
| `ROOTLESS` | Enable rootless tests |

## openQA jobs

We also run these tests on:
- [SLES 15-SP4+](https://openqa.suse.de/group_overview/417)
- [SLES 16.0](https://openqa.suse.de/group_overview/678)
- [SLES 16.x](https://openqa.suse.de/group_overview/630)

openSUSE Tumbleweed:

| Testsuite | aarch64 | ppc64le | x86_64 |
|:---:|:---:|:---:|:---:|
| aardvark | [![aardvark_aarch64_logo]][aardvark_aarch64] | [![aardvark_ppc64le_logo]][aardvark_ppc64le] | [![aardvark_x86_64_logo]][aardvark_x86_64] |
| buildah | [![buildah_aarch64_logo]][buildah_aarch64] | [![buildah_ppc64le_logo]][buildah_ppc64le] | [![buildah_x86_64_logo]][buildah_x86_64] |
| buildah + crun | [![buildah_crun_aarch64_logo]][buildah_crun_aarch64] | [![buildah_crun_ppc64le_logo]][buildah_crun_ppc64le] | [![buildah_crun_x86_64_logo]][buildah_crun_x86_64] |
| conmon | [![conmon_aarch64_logo]][conmon_aarch64] |  | [![conmon_x86_64_logo]][conmon_x86_64] |
| containerd | [![containerd_aarch64_logo]][containerd_aarch64] | [![containerd_ppc64le_logo]][containerd_ppc64le] | [![containerd_x86_64_logo]][containerd_x86_64] |
| docker | [![docker_aarch64_logo]][docker_aarch64] | [![docker_ppc64le_logo]][docker_ppc64le] | [![docker_x86_64_logo]][docker_x86_64] |
| docker rootless | [![docker_rootless_aarch64_logo]][docker_rootless_aarch64] | [![docker_rootless_ppc64le_logo]][docker_rootless_ppc64le] | [![docker_rootless_x86_64_logo]][docker_rootless_x86_64] |
| netavark | [![netavark_aarch64_logo]][netavark_aarch64] | [![netavark_ppc64le_logo]][netavark_ppc64le] | [![netavark_x86_64_logo]][netavark_x86_64] |
| podman | [![podman_aarch64_logo]][podman_aarch64] | [![podman_ppc64le_logo]][podman_ppc64le] | [![podman_x86_64_logo]][podman_x86_64] |
| podman + crun | [![podman_crun_aarch64_logo]][podman_crun_aarch64] | [![podman_crun_ppc64le_logo]][podman_crun_ppc64le] | [![podman_crun_x86_64_logo]][podman_crun_x86_64] |
| podman e2e |  |  | [![podman_e2e_x86_64_logo]][podman_e2e_x86_64] |
| podman e2e + crun |  |  | [![podman_e2e_crun_x86_64_logo]][podman_e2e_crun_x86_64] |
| podman rootless e2e |  |  | [![podman_rootless_e2e_x86_64_logo]][podman_rootless_e2e_x86_64] |
| podman rootless e2e + crun |  |  | [![podman_rootless_e2e_crun_x86_64_logo]][podman_rootless_e2e_crun_x86_64] |
| runc | [![runc_aarch64_logo]][runc_aarch64] | [![runc_ppc64le_logo]][runc_ppc64le] | [![runc_x86_64_logo]][runc_x86_64] |
| skopeo | [![skopeo_aarch64_logo]][skopeo_aarch64] | [![skopeo_ppc64le_logo]][skopeo_ppc64le] | [![skopeo_x86_64_logo]][skopeo_x86_64] |
| umoci |  |  | [![umoci_x86_64_logo]][umoci_x86_64] |

[aardvark_aarch64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_aardvark_testsuite
[aardvark_aarch64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_aardvark_testsuite

[aardvark_ppc64le_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_aardvark_testsuite
[aardvark_ppc64le]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_aardvark_testsuite

[aardvark_x86_64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_aardvark_testsuite
[aardvark_x86_64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_aardvark_testsuite

[buildah_aarch64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_buildah_testsuite
[buildah_aarch64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_buildah_testsuite

[buildah_ppc64le_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_buildah_testsuite
[buildah_ppc64le]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_buildah_testsuite

[buildah_x86_64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_buildah_testsuite
[buildah_x86_64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_buildah_testsuite

[buildah_crun_aarch64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_buildah_testsuite_crun
[buildah_crun_aarch64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_buildah_testsuite_crun

[buildah_crun_ppc64le_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_buildah_testsuite_crun
[buildah_crun_ppc64le]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_buildah_testsuite_crun

[buildah_crun_x86_64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_buildah_testsuite_crun
[buildah_crun_x86_64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_buildah_testsuite_crun

[conmon_aarch64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_conmon_testsuite
[conmon_aarch64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_conmon_testsuite

[conmon_x86_64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_conmon_testsuite
[conmon_x86_64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_conmon_testsuite

[containerd_aarch64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_containerd_testsuite
[containerd_aarch64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_containerd_testsuite

[containerd_ppc64le_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_containerd_testsuite
[containerd_ppc64le]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_containerd_testsuite

[containerd_x86_64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_containerd_testsuite
[containerd_x86_64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_containerd_testsuite

[docker_aarch64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_docker_testsuite
[docker_aarch64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_docker_testsuite

[docker_ppc64le_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_docker_testsuite
[docker_ppc64le]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_docker_testsuite

[docker_x86_64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_docker_testsuite
[docker_x86_64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_docker_testsuite

[docker_rootless_aarch64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_docker_rootless_testsuite
[docker_rootless_aarch64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_docker_rootless_testsuite

[docker_rootless_ppc64le_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_docker_rootless_testsuite
[docker_rootless_ppc64le]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_docker_rootless_testsuite

[docker_rootless_x86_64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_docker_rootless_testsuite
[docker_rootless_x86_64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_docker_rootless_testsuite

[netavark_aarch64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_netavark_testsuite
[netavark_aarch64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_netavark_testsuite

[netavark_ppc64le_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_netavark_testsuite
[netavark_ppc64le]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_netavark_testsuite

[netavark_x86_64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_netavark_testsuite
[netavark_x86_64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_netavark_testsuite

[podman_aarch64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_podman_testsuite
[podman_aarch64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_podman_testsuite

[podman_ppc64le_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_podman_testsuite
[podman_ppc64le]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_podman_testsuite

[podman_x86_64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_testsuite
[podman_x86_64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_testsuite

[podman_crun_aarch64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_podman_testsuite_crun
[podman_crun_aarch64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_podman_testsuite_crun

[podman_crun_ppc64le_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_podman_testsuite_crun
[podman_crun_ppc64le]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_podman_testsuite_crun

[podman_crun_x86_64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_testsuite_crun
[podman_crun_x86_64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_testsuite_crun

[podman_e2e_x86_64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_e2e
[podman_e2e_x86_64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_e2e

[podman_e2e_crun_x86_64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_e2e_crun
[podman_e2e_crun_x86_64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_e2e_crun

[podman_rootless_e2e_x86_64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_rootless_e2e
[podman_rootless_e2e_x86_64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_rootless_e2e

[podman_rootless_e2e_crun_x86_64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_rootless_e2e_crun
[podman_rootless_e2e_crun_x86_64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_podman_rootless_e2e_crun

[runc_aarch64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_runc_testsuite
[runc_aarch64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_runc_testsuite

[runc_ppc64le_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_runc_testsuite
[runc_ppc64le]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_runc_testsuite

[runc_x86_64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_runc_testsuite
[runc_x86_64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_runc_testsuite

[skopeo_aarch64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_skopeo_testsuite
[skopeo_aarch64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=aarch64&test=container_host_skopeo_testsuite

[skopeo_ppc64le_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_skopeo_testsuite
[skopeo_ppc64le]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=ppc64le&test=container_host_skopeo_testsuite

[skopeo_x86_64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_skopeo_testsuite
[skopeo_x86_64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_skopeo_testsuite

[umoci_x86_64_logo]: https://openqa.opensuse.org/tests/latest/badge?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_umoci_testsuite
[umoci_x86_64]: https://openqa.opensuse.org/tests/latest?distri=opensuse&flavor=DVD&version=Tumbleweed&arch=x86_64&test=container_host_umoci_testsuite

