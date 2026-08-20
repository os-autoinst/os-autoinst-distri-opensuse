# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2013-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: docker/podman engine
# Summary: Test docker/podman installation and extended usage
# - docker/podman package can be installed
# - firewall is configured correctly
# - docker daemon can be started (if docker runtime)
# - images can be pulled from the Docker Hub
# - local images can be listed (with and without tag)
# - containers can be run and created
# - containers state can be saved to an image
# - network is working inside of the containers
# - containers can be stopped
# - containers can be deleted
# - images can be deleted
# - build a docker image
# - attach a volume
# - expose a port
# - test networking outside of host
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils;
use containers::common;
use containers::utils;
use containers::container_images;

sub basic_container_tests {
    my %args = @_;
    my $runtime = $args{runtime};
    die "Undefined container runtime" unless $runtime;
    my $image = get_var("CONTAINER_IMAGE_TO_TEST", "registry.opensuse.org/opensuse/tumbleweed:latest");

    # Test pulling and display of images
    script_retry("$runtime image pull $image", timeout => 600, retry => 3, delay => 120);
    validate_script_output("$runtime image ls", qr/tumbleweed/);

    ## Create test container
    assert_script_run("$runtime create --name basic_test_container $image sleep infinity");
    validate_script_output("$runtime container ls --all", qr/basic_test_container/);

    ## Test start/stop/pause
    assert_script_run("$runtime container start basic_test_container");
    validate_script_output("$runtime ps", qr/basic_test_container/);
    validate_script_output("$runtime container inspect --format='{{.State.Running}}' basic_test_container", qr/true/);
    assert_script_run("$runtime pause basic_test_container");
    # docker and podman differ here - in docker paused containers are still in State.Running = true, in podman not
    if ($runtime eq 'docker') {
        validate_script_output("$runtime ps", sub { $_ =~ m/.*(Paused).*basic_test_container.*/ });
        validate_script_output("$runtime container inspect --format='{{.State.Running}}' basic_test_container", qr/true/);
    } else {
        validate_script_output("$runtime ps", sub { $_ !~ m/basic_test_container/ });
        validate_script_output("$runtime container inspect --format='{{.State.Running}}' basic_test_container", qr/false/);
    }
    assert_script_run("$runtime unpause basic_test_container");
    validate_script_output("$runtime ps", qr/basic_test_container/);
    validate_script_output("$runtime container inspect --format='{{.State.Running}}' basic_test_container", qr/true/);
    assert_script_run("$runtime stop basic_test_container");
    # We need to retry to avoid
    # https://bugzilla.suse.com/show_bug.cgi?id=1212825 Race condition in docker/podman stop
    validate_script_output_retry("$runtime ps", sub { $_ !~ m/basic_test_container/ }, retry => 3, delay => 60);
    validate_script_output("$runtime container inspect --format='{{.State.Running}}' basic_test_container", qr/false/);
    assert_script_run("$runtime container start basic_test_container");
    validate_script_output("$runtime ps", qr/basic_test_container/);
    validate_script_output("$runtime container inspect --format='{{.State.Running}}' basic_test_container", qr/true/);
    assert_script_run("$runtime container restart basic_test_container");
    validate_script_output("$runtime ps", qr/basic_test_container/);
    validate_script_output("$runtime container inspect --format='{{.State.Running}}' basic_test_container", qr/true/);

    ## Test logs
    assert_script_run("$runtime run -d --name logs_test $image echo 'log test canary string'");
    # retry because it could be that the log is not yet collected after the previous command completes
    validate_script_output_retry("$runtime logs logs_test", qr/log test canary string/, retry => 3, delay => 60);
    assert_script_run("$runtime container stop logs_test");
    assert_script_run("$runtime container rm logs_test");

    ## Test exec and image creation
    assert_script_run("$runtime container exec basic_test_container touch /canary");
    assert_script_run("$runtime container commit basic_test_container example.com/tw-commit_test");
    validate_script_output("$runtime image ls --all", qr?example.com/tw-commit_test?);
    assert_script_run("$runtime run --rm example.com/tw-commit_test stat /canary", fail_message => "canary file not present in generated container");
    assert_script_run("$runtime image rm example.com/tw-commit_test");

    ## Test connectivity inside the container
    script_retry("$runtime container exec basic_test_container curl -sfIL http://conncheck.opensuse.org", retry => 3, delay => 60, fail_message => "cannot reach conncheck.opensuse.org");

    ## Test `--init` option, i.e. the container process won't be PID 1 (to avoid zombie processes)
    # Ensure PID 1 has either the $runtime-init (e.g. podman-init) OR /init (e.g. `/dev/init) suffix
    validate_script_output("$runtime run --rm --init $image ps --no-headers -xo 'pid args'", sub { $_ =~ m/\s*1 .*(${runtime}-|\/)init .*/ });
    # Ensure the `ps` command is not running as PID 1. either
    validate_script_output("$runtime run --rm --init $image ps --no-headers -xo 'pid args'", sub { $_ =~ m/[02-9][0-9]* .*ps.*/ });

    ## Test prune
    assert_script_run("$runtime container commit basic_test_container example.com/prune-test");
    validate_script_output("$runtime image ls --all", qr?example.com/prune-test?);
    assert_script_run("$runtime image prune -af");
    validate_script_output("$runtime ps", sub { $_ !~ m?example.com/prune-test? });
    validate_script_output("$runtime image ls", qr/tumbleweed/, fail_message => "Tumbleweed image removed, despite being in use");
    assert_script_run("$runtime system prune -f");
    validate_script_output("$runtime image ls", qr/tumbleweed/, fail_message => "Tumbleweed image removed, despite being in use");
    assert_script_run("! $runtime rmi $image");    # should not be possible because image is in use

    ## Removing containers
    assert_script_run("$runtime container stop basic_test_container");
    assert_script_run("$runtime container rm basic_test_container");
    validate_script_output("$runtime container ls --all", sub { $_ !~ m/basic_test_container/ });

    # Check for https://bugzilla.suse.com/show_bug.cgi?id=1241216
    my $oci_runtime = get_var("OCI_RUNTIME");
    if (!$oci_runtime) {
        my $template = ($runtime eq "podman") ? "{{ .Host.OCIRuntime.Name }}" : "{{ .DefaultRuntime }}";
        $oci_runtime = script_output("$runtime info -f '$template'");
        # ATM only SLEM 6.0 & SLEM 6.1 use crun for podman
        if ($oci_runtime ne "runc") {
            if ($runtime eq "podman" && is_sle_micro('>=6.0') && is_sle_micro('<=6.1')) {
                record_soft_failure("bsc#1241216 - podman 5.2 uses crun instead of runc");
            } else {
                die "Unexpected OCI runtime: $oci_runtime";
            }
        }
    }
    record_info "OCI runtime", script_output("$oci_runtime --version", proceed_on_failure => 1);

    ## Note: Leave the tumbleweed container to save some bandwidth. It is used in other test modules as well.
}

my $macvlan_netname = 'macvlan_test';
my $macvlan_dev;

sub cleanup_macvlan {
    my %args = @_;
    my $runtime = $args{runtime};
    script_run("$runtime rm -f busybox_1");
    script_run("$runtime rm -f busybox_2");
    return unless defined $macvlan_dev;
    record_info "Clean up macvlan test";
    script_run("$runtime network rm $macvlan_netname");
    script_run("ip link delete dev $macvlan_dev");
    undef $macvlan_dev;
}


sub check_network_macvlan {
    my %args = @_;
    my $runtime = $args{runtime};
    my $image = "registry.opensuse.org/opensuse/busybox";
    my $ip1 = "192.168.60.10";
    my $ip2 = "192.168.60.11";

    record_info "Start macvlan test";

    record_info "Check for kernel module 8021q required for macvlan test";
    if (is_jeos && is_sle('=16.1') && script_run('modprobe 8021q') != 0) {
        record_soft_failure("bsc#1274833 - kernel module 8021q is not available");
        return;
    }

    assert_script_run("modinfo macvlan", fail_message => "required macvlan module not present");

    my $nic = script_output(q(ip -4 route show default | awk '{print $5}'; exit));
    $macvlan_dev = "$nic.666";
    script_retry("$runtime image pull $image", timeout => 600, retry => 3, delay => 120);

    # Create new VLAN sub nic for isolation
    assert_script_run("ip link add link $nic name $macvlan_dev type vlan id 666");
    assert_script_run("ip link set $macvlan_dev up");

    # Create macvlan network
    assert_script_run("$runtime network create -d macvlan -o parent=$macvlan_dev --subnet=192.168.60.0/24 --gateway=192.168.60.254 $macvlan_netname");
    validate_script_output("$runtime network ls", qr/$macvlan_netname/);
    record_info("macvlan network", script_output("$runtime network inspect $macvlan_netname"));

    # Create containers with macvlan network
    assert_script_run("$runtime run -d --network $macvlan_netname --ip $ip1 --name busybox_1 $image sleep infinity");
    assert_script_run("$runtime run -d --network $macvlan_netname --ip $ip2 --name busybox_2 $image sleep infinity");

    # Check if container realy use macvlan network
    validate_script_output("$runtime container inspect busybox_1", qr/$macvlan_netname/);
    validate_script_output("$runtime container inspect busybox_2", qr/$macvlan_netname/);
    validate_script_output("$runtime exec busybox_1 ip a", qr/$ip1/);
    validate_script_output("$runtime exec busybox_2 ip a", qr/$ip2/);

    # Containers using the macvlan network can reach each other
    assert_script_run("$runtime exec busybox_1 ping -c3 $ip2");
    assert_script_run("$runtime exec busybox_2 ping -c3 $ip1");

    # Containers using the macvlan network should not be able to reach 1.1.1.1
    assert_script_run("! $runtime exec busybox_1 ping -c2 1.1.1.1", fail_message => "container reached the internet, macvlan is not isolated");

    # Clean up
    cleanup_macvlan(runtime => $runtime);
}

my $ipvlan_netname = 'ipvlan_test';
my $ipvlan_dev;

sub cleanup_ipvlan {
    my %args = @_;
    my $runtime = $args{runtime};
    script_run("$runtime rm -f busybox_1");
    script_run("$runtime rm -f busybox_2");
    return unless defined $ipvlan_dev;
    record_info "Clean up ipvlan test";
    script_run("$runtime network rm $ipvlan_netname");
    script_run("ip link delete dev $ipvlan_dev");
    undef $ipvlan_dev;
}

sub check_network_ipvlan {
    my %args = @_;
    my $runtime = $args{runtime};
    my $image = "registry.opensuse.org/opensuse/busybox";
    my $ip1 = "192.168.61.10";
    my $ip2 = "192.168.61.11";

    record_info "Start ipvlan test";

    record_info "Check for kernel module 8021q required for ipvlan test";
    if (is_jeos && is_sle('=16.1') && script_run('modprobe 8021q') != 0) {
        record_soft_failure("bsc#1274833 - kernel module 8021q is not available");
        return;
    }

    record_info "Check for kernel module ipvlan required for ipvlan test";
    if (is_jeos && script_run('modprobe ipvlan') != 0) {
        record_info("Skip ipvlan", "kernel module ipvlan is not available in is_jeos requirement under review");
        return;
    }

    assert_script_run("modinfo ipvlan", fail_message => "required ipvlan module not present");

    my $nic = script_output(q(ip -4 route show default | awk '{print $5}'; exit));
    $ipvlan_dev = "$nic.667";
    script_retry("$runtime image pull $image", timeout => 600, retry => 3, delay => 120);

    # Create new VLAN sub nic for isolation
    assert_script_run("ip link add link $nic name $ipvlan_dev type vlan id 667");
    assert_script_run("ip link set $ipvlan_dev up");

    # Create ipvlan network
    assert_script_run("$runtime network create -d ipvlan -o parent=$ipvlan_dev -o mode=l2 --subnet=192.168.61.0/24 --gateway=192.168.61.254 $ipvlan_netname");
    validate_script_output("$runtime network ls", qr/$ipvlan_netname/);
    validate_script_output("$runtime network inspect -f '{{.Driver}}' $ipvlan_netname", qr/ipvlan/);
    record_info("ipvlan network", script_output("$runtime network inspect $ipvlan_netname"));

    # Create containers with ipvlan network
    assert_script_run("$runtime run -d --network $ipvlan_netname --ip $ip1 --name busybox_1 $image sleep infinity");
    assert_script_run("$runtime run -d --network $ipvlan_netname --ip $ip2 --name busybox_2 $image sleep infinity");

    # Check if container realy use ipvlan network
    validate_script_output("$runtime container inspect busybox_1", qr/$ipvlan_netname/);
    validate_script_output("$runtime container inspect busybox_2", qr/$ipvlan_netname/);
    validate_script_output("$runtime exec busybox_1 ip a", qr/$ip1/);
    validate_script_output("$runtime exec busybox_2 ip a", qr/$ip2/);

    # Check if ipvlan interfaces share the MAC address of host
    my $parent_mac = script_output("cat /sys/class/net/$ipvlan_dev/address");
    validate_script_output("$runtime exec busybox_1 ip link show eth0", qr/$parent_mac/i);
    validate_script_output("$runtime exec busybox_2 ip link show eth0", qr/$parent_mac/i);

    # Containers using the ipvlan network can reach each other
    assert_script_run("$runtime exec busybox_1 ping -c3 $ip2");
    assert_script_run("$runtime exec busybox_2 ping -c3 $ip1");

    # Containers using the ipvlan network should not be able to reach 1.1.1.1
    assert_script_run("! $runtime exec busybox_1 ping -c2 1.1.1.1", fail_message => "container reached the internet, ipvlan is not isolated");

    # Clean up
    cleanup_ipvlan(runtime => $runtime);
}

sub run {
    my ($self, $args) = @_;
    die('You must define a engine') unless ($args->{runtime});
    $self->{runtime} = $args->{runtime};
    select_serial_terminal;

    my $dir = "/root/DockerTest";

    if (get_var('CONTAINERS_CGROUP_VERSION')) {
        switch_cgroup_version($self, get_var('CONTAINERS_CGROUP_VERSION'));
    }

    my $engine = $self->containers_factory($self->{runtime});

    # Test the connectivity of Docker containers
    check_containers_connectivity($engine);

    basic_container_tests(runtime => $self->{runtime});

    # Kernel module 8021q is needed to test macvlan and ipvlan and must be available on Tumbleweed and 16.1
    if (is_tumbleweed || is_sle(">=16.1")) {
        check_network_macvlan(runtime => $self->{runtime});
        check_network_ipvlan(runtime => $self->{runtime});
    }

    # Build an image from Dockerfile and run it
    my $base = (is_opensuse ? 'registry.opensuse.org/opensuse/bci/python:latest' : 'registry.suse.com/bci/python:latest');
    build_and_run_image(runtime => $engine, dockerfile => 'Dockerfile.python3', base => $base);

    # Once more test the basic functionality
    runtime_smoke_tests(runtime => $engine);

    # Clean the container host
    $engine->cleanup_system_host();
}

sub post_fail_hook {
    my ($self) = @_;
    cleanup_macvlan(runtime => $self->{runtime});
    cleanup_ipvlan(runtime => $self->{runtime});
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;

