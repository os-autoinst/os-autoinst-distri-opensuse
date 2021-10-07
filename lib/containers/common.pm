# Copyright 2015-2021 SUSE LLC
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
use utils qw(zypper_call systemctl file_content_replace script_retry);
use version_utils qw(is_sle is_leap is_microos is_sle_micro is_opensuse is_jeos is_public_cloud get_os_release check_version);
use containers::utils qw(can_build_sle_base registry_url);

our @EXPORT = qw(is_unreleased_sle install_podman_when_needed install_docker_when_needed
  test_container_runtime test_container_image scc_apply_docker_image_credentials
  scc_restore_docker_image_credentials install_buildah_when_needed test_rpm_db_backend activate_containers_module);


sub is_unreleased_sle {
    # If "SCC_URL" is set, it means we are in not-released SLE host and it points to proxy SCC url
    return (get_var('SCC_URL', '') =~ /proxy/);
}

sub activate_containers_module {
    my ($running_version, $sp, $host_distri) = get_os_release;
    my $suseconnect = script_output('SUSEConnect --status-text', timeout => 240);
    if ($suseconnect !~ m/Containers/) {
        $running_version eq '12' ? add_suseconnect_product("sle-module-containers", 12) : add_suseconnect_product("sle-module-containers");
        $suseconnect = script_output('SUSEConnect --status-text', timeout => 240);
    }
    record_info('SUSEConnect', $suseconnect);
}


sub install_podman_when_needed {
    my $host_os = shift;
    my @pkgs    = qw(podman);
    if (script_run("which podman") != 0) {
        if ($host_os eq 'centos') {
            assert_script_run "dnf -y install @pkgs", timeout => 160;
        } elsif ($host_os eq 'ubuntu') {
            my $version_id  = script_output('(. /etc/os-release && echo $VERSION_ID)');
            my $ubuntu_repo = "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${version_id}";
            assert_script_run qq(echo "deb $ubuntu_repo/ /" | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list);
            assert_script_run "curl -L $ubuntu_repo/Release.key | apt-key add -";
            assert_script_run "apt-get update",            timeout => 300;
            assert_script_run "apt-get -y install podman", timeout => 300;
        } else {
            # We may run openSUSE with DISTRI=sle and opensuse doesn't have SUSEConnect
            activate_containers_module if $host_os =~ 'sles';
            push(@pkgs, 'podman-cni-config') if is_jeos();
            push(@pkgs, 'apparmor-parser')   if is_leap("=15.1");    # bsc#1123387
            zypper_call "in @pkgs";
        }
    }
    assert_script_run('podman info');
}

sub install_docker_when_needed {
    my $host_os = shift;

    if (is_microos || is_sle_micro) {
        # Docker should be pre-installed in MicroOS
        die 'Docker is not pre-installed.' if zypper_call('se -x --provides -i docker');
    } else {
        if (script_run("which docker") != 0) {
            if ($host_os eq 'centos') {
                assert_script_run "dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo";
                # if podman installed use flag "--allowerasing" to solve conflicts
                assert_script_run "dnf -y install docker-ce --nobest --allowerasing", timeout => 120;
            } elsif ($host_os eq 'ubuntu') {
                my $version_id = script_output('(. /etc/os-release && echo $VERSION_ID)');
                assert_script_run "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -";
                assert_script_run q(add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable");
                assert_script_run "apt-get update", timeout => 160;
                # Make sure you are about to install from the Docker repo instead of the default Ubuntu repo
                assert_script_run "apt-cache policy docker-ce";
                assert_script_run "apt-get -y install docker-ce", timeout => 260;
            } else {
                # We may run openSUSE with DISTRI=sle and openSUSE does not have SUSEConnect
                activate_containers_module if $host_os =~ 'sles';

                # docker package can be installed
                zypper_call('in docker', timeout => 900);
            }
        }
    }

    # docker daemon can be started
    systemctl('enable docker');
    systemctl('is-enabled docker');
    # docker start, but taking bsc#1187479 into account. Please remove softfailure handling, once bsc#1187479 is solved.
    if (systemctl('start docker', ignore_failure => 1) != 0) {
        # Check for docker start timeout, bsc#1187479
        if (script_run('journalctl -e | grep "timeout waiting for containerd to start"') == 0) {
            # Retry one more time
            record_soft_failure("bsc#1187479");
            sleep(120);    # give background services time to complete to prevent another failure
            systemctl('start docker');
        } else {
            die "docker start failed";
        }
    }
    systemctl('is-active docker');
    systemctl('status docker', timeout => 120);
    assert_script_run('docker info');
}

sub install_buildah_when_needed {
    my $host_os = shift;
    my @pkgs    = qw(buildah);
    if (script_run("which buildah") != 0) {
        # We may run openSUSE with DISTRI=sle and opensuse doesn't have SUSEConnect
        activate_containers_module if $host_os =~ 'sles';
        zypper_call "in @pkgs";
        record_info('buildah', script_output('buildah info'));
    }
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

    # Images from docker.io registry are listed without the 'docker.io/library/'
    # Images from custom registry are listed with the '$registry/library/'
    $image =~ s/^docker\.io\/library\///;

    my $smoketest = qq[/bin/sh -c '/bin/uname -r; /bin/echo "Heartbeat from $image"; ps'];

    $runtime->pull($image, timeout => 420);
    $runtime->check_image_in_host($image);
    $runtime->create_container(image => $image, name => 'testing', cmd => $smoketest);
    return if $runtime->runtime eq 'buildah';
    $runtime->start_container('testing');
    $runtime->halt_container('testing');
    $runtime->get_container_logs('testing', $logfile);
    $runtime->remove_container('testing');
    if (script_run("grep \"`uname -r`\" '$logfile'") != 0) {
        upload_logs("$logfile");
        die "Kernel smoke test failed for $image";
    }
    if (script_run("grep \"Heartbeat from $image\" '$logfile'") != 0) {
        upload_logs("$logfile");
        die "Heartbeat test failed for $image";
    }
    assert_script_run "rm -f $logfile";
}

sub scc_apply_docker_image_credentials {
    my $regcode = get_var 'SCC_DOCKER_IMAGE';
    assert_script_run "cp /etc/zypp/credentials.d/SCCcredentials{,.bak}";
    assert_script_run "echo -ne \"$regcode\" > /etc/zypp/credentials.d/SCCcredentials";
}

sub scc_restore_docker_image_credentials {
    assert_script_run "cp /etc/zypp/credentials.d/SCCcredentials{.bak,}" if (is_sle() && get_var('SCC_DOCKER_IMAGE'));
}

sub test_rpm_db_backend {
    my %args    = @_;
    my $image   = $args{image};
    my $runtime = $args{runtime};

    die 'Argument $image not provided!'   unless $image;
    die 'Argument $runtime not provided!' unless $runtime;

    my ($running_version, $sp, $host_distri) = get_os_release("$runtime->{runtime} run $image");
    # TW and SLE 15-SP3+ uses rpm-ndb in the image
    if ($host_distri eq 'opensuse-tumbleweed' || ($host_distri eq 'sles' && check_version('>=15-SP3', "$running_version-SP$sp", qr/\d{2}(?:-sp\d)?/))) {
        validate_script_output "$runtime->{runtime} run $image rpm --eval %_db_backend", sub { m/ndb/ };
    }
}

1;
