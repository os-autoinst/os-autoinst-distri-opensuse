# Copyright 2015-2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
# Maintainer: qac team <qa-c@suse.de>

package containers::common;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use registration;
use version_utils;
use utils qw(zypper_call systemctl file_content_replace script_retry script_output_retry);
use containers::utils qw(registry_url container_ip container_route);
use transactional qw(trup_call check_reboot_changes process_reboot);
use bootloader_setup 'add_grub_cmdline_settings';
use serial_terminal 'select_serial_terminal';
use power_action_utils 'power_action';
use Mojo::JSON;
use version_utils qw(is_sle);
use Utils::Architectures qw(is_aarch64);

our @EXPORT = qw(is_unreleased_sle install_podman_when_needed install_docker_when_needed install_containerd_when_needed
  test_container_runtime test_container_image
  install_buildah_when_needed activate_containers_module check_containers_connectivity
  switch_cgroup_version install_packages);

sub is_unreleased_sle {
    # If "SCC_URL" is set, it means we are in not-released SLE host and it points to proxy SCC url
    return (get_var('SCC_URL', '') =~ /proxy/);
}

sub activate_containers_module {
    my $registered = 0;
    my $json = Mojo::JSON::decode_json(script_output_retry('SUSEConnect -s', timeout => 240, retry => 3, delay => 60));
    foreach (@$json) {
        if ($_->{identifier} =~ 'sle-module-containers' && $_->{status} =~ '^Registered') {
            $registered = 1;
            last;
        }
    }
    add_suseconnect_product('sle-module-containers') unless (($registered) || check_var('SCC_REGISTER', 'skip'));
    record_info('SUSEConnect', script_output_retry('SUSEConnect --status-text', timeout => 240, retry => 3, delay => 60));
}

sub install_oci_runtime {
    my $runtime = shift;

    my $oci_runtime = get_var("OCI_RUNTIME");
    return if (!$oci_runtime);

    my $template = ($runtime eq "podman") ? "{{ .Host.OCIRuntime.Name }}" : "{{ .DefaultRuntime }}";
    my $use_runtime = script_output("$runtime info -f '$template'");

    if ($oci_runtime ne $use_runtime) {
        record_info("OCI runtime", "$use_runtime -> $oci_runtime");
        zypper_call "in $oci_runtime" if (script_run("which $oci_runtime") != 0);
        if ($runtime eq "podman") {
            script_run "mkdir /etc/containers/containers.conf.d";
            assert_script_run "echo -e '[engine]\nruntime=\"$oci_runtime\"' >> /etc/containers/containers.conf.d/engine.conf";
        } else {
            assert_script_run "sed -i 's%^{%&\"default-runtime\":\"$oci_runtime\",\"runtimes\":{\"$oci_runtime\":{\"path\":\"/usr/bin/$oci_runtime\"}},%' /etc/docker/daemon.json";
            systemctl('restart docker', timeout => 180);
        }
        $use_runtime = script_output("$runtime info -f '$template'");
        die "Could not change OCI runtime to $oci_runtime" if ($oci_runtime ne $use_runtime);
    }
}

sub install_podman_when_needed {
    my ($running_version, $sp, $host_os) = get_os_release;
    my @pkgs = qw(podman);
    if (script_run("which podman") != 0) {
        if ($host_os =~ /centos|rhel/) {
            script_retry "dnf -y install @pkgs --nobest --allowerasing", timeout => 300;
        } elsif ($host_os eq 'ubuntu') {
            script_retry("apt-get -y install @pkgs", timeout => 300);
        } else {
            # We may run openSUSE with DISTRI=sle and opensuse doesn't have SUSEConnect
            activate_containers_module if ($host_os =~ 'sle' && $running_version =~ "15");
            zypper_call "in @pkgs";
            install_oci_runtime("podman");
        }
    }
    record_info('podman', script_output('podman info'));
    # In Tumbleweed podman containers can't access external network in some cases, e.g. when testing
    # docker and podman in the same job. We would need to tweak firewalld with some extra configuration.
    # It's just easier to stop it as we already have a test with podman+firewall
    systemctl("stop firewalld") if ($host_os =~ 'tumbleweed');
}

sub install_docker_multiplatform {
    my ($running_version, $sp, $host_os) = get_os_release;
    if ($host_os eq 'centos') {
        assert_script_run "dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo";
        # if podman installed use flag "--allowerasing" to solve conflicts
        assert_script_run "dnf -y install docker-ce --nobest --allowerasing", timeout => 300;
        return;
    }
    if ($host_os eq 'ubuntu') {
        # Make sure you are about to install from the Docker repo instead of the default Ubuntu repo
        assert_script_run "apt-cache policy docker-ce";
        script_retry("apt-get -y install docker-ce", timeout => 300);
        return;
    }

    my $pkg_name = check_var("CONTAINERS_DOCKER_FLAVOUR", "stable") ? "docker-stable" : "docker";
    if (is_transactional || $host_os =~ /micro/i) {
        select_serial_terminal;
        trup_call("pkg install $pkg_name");
        check_reboot_changes;
        return;
    }

    my $ltss_needed = 0;
    if ($host_os =~ 'sle') {
        # We may run openSUSE with DISTRI=sle and openSUSE does not have SUSEConnect
        activate_containers_module if ($running_version =~ "15");

        # Temporarly enable LTSS product on LTSS systems where it is not present
        if (get_var('SCC_REGCODE_LTSS') && script_run('test -f /etc/products.d/SLES-LTSS.prod') != 0 && !main_common::is_updates_tests) {
            add_suseconnect_product('SLES-LTSS', undef, undef, '-r ' . get_var('SCC_REGCODE_LTSS'), 150);
            $ltss_needed = 1;
        }
    }

    # docker package can be installed
    zypper_call("in $pkg_name", timeout => 300);

    # Restart firewalld if enabled before. Ensure docker can properly interact (boo#1196801)
    if (script_run('systemctl is-active firewalld') == 0) {
        systemctl 'try-restart firewalld';
    }

    remove_suseconnect_product('SLES-LTSS') if $ltss_needed && !main_common::is_updates_tests;
}

sub install_docker_when_needed {
    my ($running_version, $sp, $host_os) = get_os_release;
    record_info("get_os_release", "'$running_version', '$sp', '$host_os'");
    if (script_run("which docker") != 0) {
        install_docker_multiplatform;
    }

    # Disable docker's own rate-limit in the service file (3 restarts in 60s)
    # Our tests might restart the docker service more frequently than that
    assert_script_run 'mkdir -p /etc/systemd/system/docker.service.d';
    assert_script_run 'echo -e "[Service]\nStartLimitInterval=0s\n" > /etc/systemd/system/docker.service.d/limits.conf';

    # docker daemon can be started
    systemctl('enable docker');
    systemctl('is-enabled docker');
    systemctl('start docker', timeout => 180);
    systemctl('is-active docker');
    systemctl('status docker', timeout => 120);
    install_oci_runtime("docker") if ($host_os =~ /sle|opensuse|micro/);
    record_info('docker', script_output('docker info'));
    my $warnings = script_output("docker info -f '{{ range .Warnings }}{{ println . }}{{ end }}'");
    record_info("WARNINGS daemon", $warnings) if $warnings;
    $warnings = script_output("docker info -f '{{ range .ClientInfo.Warnings }}{{ println . }}{{ end }}'");
    record_info("WARNINGS client", $warnings) if $warnings;
    record_info('version', script_output('docker version'));
}

sub install_buildah_when_needed {
    my ($running_version, $sp, $host_os) = get_os_release;
    if (script_run("which buildah") != 0) {
        if ($host_os eq 'centos') {
            assert_script_run "dnf -y update", timeout => 900;
            assert_script_run "dnf -y install buildah", timeout => 300;
        } elsif ($host_os eq 'ubuntu') {
            script_retry("apt-get update", timeout => 900);
            script_retry("apt-get -y install buildah", timeout => 300);
        } elsif ($host_os eq 'rhel') {
            script_retry('dnf update -y', timeout => 300);
            script_retry('dnf install -y buildah', timeout => 300);
        } else {
            activate_containers_module if ($host_os =~ 'sle' && $running_version =~ "12|15");
            zypper_call('in buildah', timeout => 300);
        }
    }
    assert_script_run "! buildah info | grep Failed";
    record_info('buildah', script_output('buildah info'));
}

sub install_containerd_when_needed {
    my $registry = registry_url();
    my @packages = qw(containerd);
    push(@packages, 'cni-plugins') if (is_sle("<15-SP7") || is_leap("<15.7"));
    push(@packages, 'pattern:apparmor') if is_sle('=15-SP3');
    zypper_call('in ' . join(" ", @packages), timeout => 300);
    assert_script_run "curl " . data_url('containers/containerd.toml') . " -o /etc/containerd/config.toml";
    file_content_replace("/etc/containerd/config.toml", REGISTRY => $registry);
    assert_script_run('cat /etc/containerd/config.toml');
    systemctl('start containerd.service');
    record_info('containerd', script_output('containerd -h'));
}

# Test a given image. Takes the image and container runtime (docker or podman) as arguments
sub test_container_image {
    my %args = @_;
    my $image = $args{image};
    my $runtime = $args{runtime};
    my $logfile = "/var/tmp/container_logs.txt";

    die 'Argument $image not provided!' unless $image;
    die 'Argument $runtime not provided!' unless $runtime;

    # Images from docker.io registry are listed without the 'docker.io/library/'
    # Images from custom registry are listed with the '$registry/library/'
    $image =~ s/^docker\.io\/library\///;

    my $smoketest = qq[/bin/sh -c '/bin/uname -r; /bin/echo "Heartbeat from $image"'];

    $runtime->pull($image, timeout => 420);
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

sub check_containers_connectivity {
    my $runtime = shift;
    record_info "connectivity", "Checking that containers can connect to the host, to each other and outside of the host";
    my $container_name = 'sut_container';
    my $image = "registry.opensuse.org/opensuse/busybox:latest";

    script_retry "$runtime pull $image", timeout => 300, retry => 3, delay => 120;
    assert_script_run "$runtime run -id --rm --name $container_name -p 1234:1234 $image sleep infinity";
    my $container_ip = container_ip $container_name, $runtime;

    my $_4 = is_sle("<15") ? "" : "-4";

    # Connectivity to host check
    my $container_route = container_route($container_name, $runtime);
    assert_script_run "ping $_4 -c3 " . $container_route;
    assert_script_run "$runtime run --rm --cap-add=CAP_NET_RAW $image ping -4 -c3 " . $container_route;

    # Cross-container connectivity check
    assert_script_run "ping $_4 -c3 " . $container_ip;
    assert_script_run "$runtime run --rm  --cap-add=CAP_NET_RAW $image ping -4 -c3 " . $container_ip;

    # Outside IP connectivity check
    script_retry "ping $_4 -c3 8.8.8.8", retry => 3, delay => 120;
    script_retry "$runtime run --rm --cap-add=CAP_NET_RAW $image ping -4 -c3 8.8.8.8", retry => 3, delay => 120;

    # Outside IP+DNS connectivity check
    script_retry "ping $_4 -c3 google.com", retry => 3, delay => 120;
    script_retry "$runtime run --rm --cap-add=CAP_NET_RAW $image ping -4 -c3 google.com", retry => 3, delay => 120;

    # Kill the container running on background
    assert_script_run "$runtime kill $container_name";
}

sub switch_cgroup_version {
    my ($self, $version) = @_;

    my $setting = ($version == 1) ? 0 : 1;

    my $rc = script_run("ls /sys/fs/cgroup/cgroup.controllers");
    return if ($version == 2 && $rc == 0 || $version == 1 && $rc != 0);

    record_info "cgroup v$version", "Switching to cgroup v$version";
    if (is_transactional) {
        add_grub_cmdline_settings("systemd.unified_cgroup_hierarchy=$setting", update_grub => 0);
        assert_script_run('transactional-update grub.cfg');
        process_reboot(trigger => 1);
    } else {
        add_grub_cmdline_settings("systemd.unified_cgroup_hierarchy=$setting", update_grub => 1);
        power_action('reboot', textmode => 1);
        $self->wait_boot(bootloader_time => 360);
    }
    select_serial_terminal;

    validate_script_output("cat /proc/cmdline", sub { m/systemd\.unified_cgroup_hierarchy=$setting/ });
}

sub install_packages {
    my @pkgs = @_;
    # skip if already installed:
    unless (script_run("rpm -q @pkgs") == 0) {
        if (is_transactional) {
            trup_call("pkg install @pkgs");
            check_reboot_changes;
        } else {
            zypper_call("in @pkgs");
        }
    }
}

1;
