# Copyright (C) 2015-2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package containers::common;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use registration;
use utils qw(zypper_call systemctl);
use version_utils qw(is_sle is_leap is_microos is_opensuse is_jeos is_public_cloud);
use containers::utils 'can_build_sle_base';

our @EXPORT = qw(install_podman_when_needed install_docker_when_needed allow_selected_insecure_registries clean_container_host
  test_container_runtime test_container_image scc_apply_docker_image_credentials scc_restore_docker_image_credentials);

sub install_podman_when_needed {
    my $host_os = shift;
    my @pkgs    = qw(podman);
    if (script_run("which podman") != 0) {
        if ($host_os eq 'centos') {
            assert_script_run "dnf -y install @pkgs", timeout => 160;
        }
        elsif ($host_os eq 'ubuntu') {
            my $version_id  = script_output('(. /etc/os-release && echo $VERSION_ID)');
            my $ubuntu_repo = "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${version_id}";
            assert_script_run qq(echo "deb $ubuntu_repo/ /" | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list);
            assert_script_run "curl -L $ubuntu_repo/Release.key | apt-key add -";
            assert_script_run "apt-get update",            timeout => 160;
            assert_script_run "apt-get -y install podman", timeout => 220;
        }
        else {
            # We may run openSUSE with DISTRI=sle and opensuse doesn't have SUSEConnect
            add_suseconnect_product('sle-module-containers') if ($host_os =~ 'sles' && is_sle('>=15'));
            push(@pkgs, 'podman-cni-config') if is_jeos();
            push(@pkgs, 'apparmor-parser')   if is_leap("=15.1");    # bsc#1123387
            zypper_call "in @pkgs";
        }
        assert_script_run('podman info');
    }
}

sub install_docker_when_needed {
    my $host_os = shift;

    if (is_microos) {
        # Docker should be pre-installed in MicroOS
        die 'Docker is not pre-installed.' if zypper_call('se -x --provides -i docker');
    }
    else {
        if (script_run("which docker") != 0) {
            if ($host_os eq 'centos') {
                assert_script_run "dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo";
                # if podman installed use flag "--allowerasing" to solve conflicts
                assert_script_run "dnf -y install docker-ce --nobest --allowerasing", timeout => 120;
            }
            elsif ($host_os eq 'ubuntu') {
                my $version_id = script_output('(. /etc/os-release && echo $VERSION_ID)');
                assert_script_run "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -";
                assert_script_run q(add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable");
                assert_script_run "apt-get update", timeout => 160;
                # Make sure you are about to install from the Docker repo instead of the default Ubuntu repo
                assert_script_run "apt-cache policy docker-ce";
                assert_script_run "apt-get -y install docker-ce", timeout => 260;
            }
            else {
                # We may run openSUSE with DISTRI=sle and openSUSE does not have SUSEConnect
                if (can_build_sle_base && script_run("SUSEConnect --status-text | grep Containers") != 0) {
                    is_sle('<15') ? add_suseconnect_product("sle-module-containers", 12) : add_suseconnect_product("sle-module-containers");
                }

                # docker package can be installed
                zypper_call('in docker', timeout => 900);
            }
        }
    }

    # docker daemon can be started
    systemctl('enable docker') if systemctl('is-enabled docker', ignore_failure => 1);
    systemctl('start docker')  if systemctl('is-active docker',  ignore_failure => 1);
    systemctl('status docker', timeout => 120);
    assert_script_run('docker info');
}

sub allow_selected_insecure_registries {
    my %args    = @_;
    my $runtime = $args{runtime};
    die "You must define the runtime!" unless $runtime;

    assert_script_run "echo $runtime ...";
    if ($runtime =~ /docker/) {
        # Allow our internal 'insecure' registry
        assert_script_run("mkdir -p /etc/docker");
        assert_script_run('cat /etc/docker/daemon.json; true');
        assert_script_run(
            'echo "{ \"insecure-registries\" : [\"localhost:5000\", \"registry.suse.de\"] }" > /etc/docker/daemon.json');
        assert_script_run('cat /etc/docker/daemon.json');
        systemctl('restart docker');
    } elsif ($runtime =~ /podman/) {
        assert_script_run "curl " . data_url('containers/registries.conf') . " -o /etc/containers/registries.conf";
        assert_script_run "chmod 644 /etc/containers/registries.conf";
    } else {
        die "You must define the runtime!";
    }
}

sub clean_container_host {
    my %args    = @_;
    my $runtime = $args{runtime};
    die "You must define the runtime!" unless $runtime;
    assert_script_run("$runtime stop \$($runtime ps -q)", 180) if script_output("$runtime ps -q | wc -l") != '0';
    assert_script_run("$runtime system prune -a -f",      180);
}

sub test_container_runtime {
    my $runc = shift;
    die "You must define the runtime!" unless $runc;

    # installation of runtime
    record_info 'Test #1', 'Test: Installation';
    zypper_call("in $runc");

    # create the OCI specification and verify that the template has been created
    record_info 'Test #2', 'Test: OCI Specification';
    assert_script_run("$runc spec");
    assert_script_run('ls -l config.json');
    script_run('cp config.json config.json.backup');

    # Modify the configuration to run the container in background
    assert_script_run("sed -i -e '/\"terminal\":/ s/: .*/: false,/' config.json");
    assert_script_run("sed -i -e 's/\"sh\"/\"echo\", \"Kalimera\"/' config.json");

    # Run (create, start, and delete) the container after it exits
    record_info 'Test #3', 'Test: Use the run command';
    assert_script_run("$runc run test1 | grep Kalimera");

    # Restore the default configuration
    assert_script_run('mv config.json.backup config.json');

    assert_script_run("sed -i -e '/\"terminal\":/ s/: .*/: false,/' config.json");
    assert_script_run("sed -i -e 's/\"sh\"/\"sleep\", \"120\"/' config.json");

    # Container Lifecycle
    record_info 'Test #4', 'Test: Create a container';
    assert_script_run("$runc create test2");
    assert_script_run("$runc state test2 | grep status | grep created");
    record_info 'Test #5', 'Test: List containers';
    assert_script_run("$runc list | grep test2");
    record_info 'Test #6', 'Test: Start a container';
    assert_script_run("$runc start test2");
    assert_script_run("$runc state test2 | grep running");
    record_info 'Test #7', 'Test: Pause a container';
    assert_script_run("$runc pause test2");
    assert_script_run("$runc state test2 | grep paused");
    record_info 'Test #8', 'Test: Resume a container';
    assert_script_run("$runc resume test2");
    assert_script_run("$runc state test2 | grep running");
    record_info 'Test #9', 'Test: Stop a container';
    assert_script_run("$runc kill test2 KILL");
    sleep 30;
    assert_script_run("$runc state test2 | grep stopped");
    record_info 'Test #10', 'Test: Delete a container';
    assert_script_run("$runc delete test2");
    assert_script_run("! $runc state test2");

    # remove the configuration file
    assert_script_run("rm config.json");
}

# Test a given image. Takes the image and container runtime (docker or podman) as arguments
sub test_container_image {
    my %args    = @_;
    my $image   = $args{image};
    my $runtime = $args{runtime};
    my $logfile = "/var/tmp/container_logs";

    die 'Argument $image not provided!'   unless $image;
    die 'Argument $runtime not provided!' unless $runtime;

    # Pull the image if necessary
    if (script_run("$runtime image inspect --format='{{.RepoTags}}' $image | grep '$image'") != 0) {
        assert_script_run("$runtime pull $image", timeout => 300);
        assert_script_run("$runtime image inspect --format='{{.RepoTags}}' $image | grep '$image'");
    }

    my $smoketest = "/bin/uname -r; /bin/echo \"Heartbeat from $image\"";
    assert_script_run("$runtime container create --name 'testing' '$image' /bin/sh -c '$smoketest'");
    assert_script_run("$runtime container start 'testing'");
    assert_script_run("$runtime wait 'testing'", 90);
    assert_script_run("$runtime container logs 'testing' | tee '$logfile'");
    assert_script_run("$runtime container rm 'testing'");
    if (script_run("grep \"`uname -r`\" '$logfile'") != 0) {
        upload_logs("$logfile");
        die "Kernel smoke test failed for $image";
    }
    if (script_run("grep \"Heartbeat from $image\" '$logfile'") != 0) {
        upload_logs("$logfile");
        die "Heartbeat test failed for $image";
    }
}

sub scc_apply_docker_image_credentials {
    my $regcode = get_var 'SCC_DOCKER_IMAGE';
    assert_script_run "cp /etc/zypp/credentials.d/SCCcredentials{,.bak}";
    assert_script_run "echo -ne \"$regcode\" > /etc/zypp/credentials.d/SCCcredentials";
}

sub scc_restore_docker_image_credentials {
    assert_script_run "cp /etc/zypp/credentials.d/SCCcredentials{.bak,}" if (is_sle() && get_var('SCC_DOCKER_IMAGE'));
}

1;
