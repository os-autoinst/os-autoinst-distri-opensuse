# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Configure and run a warewulf4 controller
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase hpc::utils), -signatures;
use testapi;
use serial_terminal qw(select_serial_terminal);
use lockapi;
use mmapi;
use utils;
use Utils::Logging 'export_logs';
use hpc::formatter;
use isotovideo;
use mm_tests;
use Utils::Logging 'save_and_upload_log';
use POSIX 'strftime';

our $file = 'tmpresults.xml';

sub run ($self) {
    select_serial_terminal();
    configure_static_network('10.0.2.1/24');

    my $user_virtio_fixed = isotovideo::get_version() >= 35;
    my $prompt = $user_virtio_fixed ? $testapi::username . '@' . get_required_var('HOSTNAME') . ':~> ' : undef;

    ensure_ca_certificates_suse_installed();
    mutex_create 'ww4_ready';
    my $rt = zypper_call("in warewulf4");
    test_case('Installation', 'ww4', $rt);

    assert_script_run("wget --quiet " . data_url("hpc/net/ifcfg-eth1") . " -O /etc/sysconfig/network/ifcfg-eth1");
    assert_script_run(qq{sed -ri 's/^DHCPD_INTERFACE.*\$/DHCPD_INTERFACE="eth1"/g' /etc/sysconfig/dhcpd});
    systemctl 'restart wicked';
    assert_script_run(qq{sed -ri 's/^ipaddr:.*\$/ipaddr: 192.168.10.100/g' /etc/warewulf/warewulf.conf});
    assert_script_run(qq{sed -ri 's/^network:.*\$/network: 192.168.10.0/g' /etc/warewulf/warewulf.conf});
    assert_script_run(qq{sed -ri 's/^  range start:.*\$/  range start: 192.168.10.111/g' /etc/warewulf/warewulf.conf});
    assert_script_run(qq{sed -ri 's/^  range end:.*\$/  range end: 192.168.10.115/g' /etc/warewulf/warewulf.conf});
    $rt = (systemctl 'enable --now warewulfd') ? 1 : 0;
    test_case('systemd', 'ww4', $rt);
    record_info "warewulf.conf", script_output("cat /etc/warewulf/warewulf.conf");
    record_info "defaults.conf", script_output("cat /etc/warewulf/defaults.conf");

    $rt = (assert_script_run "wwctl container import docker://registry.suse.de/suse/containers/sle-micro/5.3/containers/suse/sle-micro-rancher/5.3:latest sle-micro-5.3 --setdefault", timeout => 320) ? 1 : 0;
    test_case('Container pull', 'ww4', $rt);
    $rt = (assert_script_run "wwctl profile set -y -C sle-micro-5.3") ? 1 : 0;
    test_case('Profile', 'ww4', $rt);
    assert_script_run "wwctl profile set -y default --netname default --netmask 255.255.255.0 --gateway 192.168.10.100";
    assert_script_run "wwctl profile list -a";
    $rt = (assert_script_run "wwctl node add compute10 --netdev eth0 -I 192.168.10.111 --discoverable=true") ? 1 : 0;
    test_case('Nodes', 'first node added successfully', $rt);
    $rt = (assert_script_run "wwctl node add compute11 --netdev eth0 -I 192.168.10.112 --discoverable=true") ? 1 : 0;
    test_case('Nodes', 'second node added successfully', $rt);

    my $compute_nodes = script_output "wwctl node list -a";
    record_info "nodes in conf", "$compute_nodes";

    # I think running the configuration after the profile and the nodes are set
    # provides complete results of the scripts.
    $rt = (assert_script_run "echo yes | wwctl -v configure --all") ? 1 : 0;
    test_case('Service configuration', 'ww4', $rt);
    barrier_wait('WWCTL_READY');
    record_info 'WWCTL_READY', strftime("\%H:\%M:\%S", localtime);
    mutex_unlock 'ww4_ready';

    barrier_wait('WWCTL_DONE');
    record_info 'WWCTL_DONE', strftime("\%H:\%M:\%S", localtime);
    my @compute_nodes = _get_compute_node_hostnames();
    foreach my $node (@compute_nodes) {
        script_run("ssh -o StrictHostKeyChecking=accept-new $node ip a | tee /tmp/script_out");
        $rt = (assert_script_run "grep -E 'inet 192\.168\.10\.11[1-5]' /tmp/script_out", fail_message => 'IP address likely is not set or is not in the defined IP range!!') ? 1 : 0;
        test_case("Check IP on $node", 'Compute Validate IP', $rt);
        $rt = validate_script_output("ssh -o StrictHostKeyChecking=accept-new $node cat /etc/os-release", sub { m/NAME.+SLE Micro/ });
        test_case("Check OS on $node", 'Compute Validate OS', $rt);
    }
    barrier_wait('WWCTL_COMPUTE_DONE');
    record_info 'WWCTL_COMPUTE_DONE', strftime("\%H:\%M:\%S", localtime);
}

sub _get_compute_node_hostnames() {
    my $computes = script_output "wwctl node list -i | awk 'NR>2 {print \$1}'";
    return split "\n", $computes;
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_run_hook ($self) {
    record_info "post_run", "hook started";
    pars_results('HPC warewulf4 controller tests', $file, @all_tests_results);
    parse_extra_log('XUnit', $file);
    $self->upload_service_log('warewulfd');
    save_and_upload_log('cat /etc/hosts', "/tmp/hostfile");
    save_and_upload_log('ip a', "/tmp/controller_network");
    save_and_upload_log('wwctl overlay list -a', "/tmp/wwctl_overlay");
    save_and_upload_log('cat /etc/warewulf/warewulf.conf', '/tmp/warewulf.conf');
    $self->SUPER::post_run_hook();
}
sub post_fail_hook ($self) {
    $self->destroy_test_barriers();
    export_logs();
}

1;

=head1 Info

=head2 External Documentation

  https://gitlab.suse.de/HPC/warewulf-doc/-/blob/main/quickstart-sle.rst

=head2 Test Setup

  Controller needs two network interfaces. One public and one private. To accomplish
  this the controller takes a job variable as C<NICVLAN=0,1>.
  As such the qemu will bind two link to the VM (eth0 and eth1).
  From previous steps we disable firewall so we do not need to take any action
  there. Otherwise would have to add services on it.

  =begin bash
    # assert_script_run "firewall-cmd --permanent --add-service warewulf";
    # assert_script_run "firewall-cmd --permanent --add-service nfs";
    # assert_script_run "firewall-cmd --permanent --add-service tftp";
    # assert_script_run "firewall-cmd --reload";
  =end bash

  The second interface is configured by the F<data/hpc/net/ifcfg-eth1>

  We also need to assign the internal interface on F</etc/sysconfig/dhcpd>
  and use the internal network on the F</etc/warewulf/warewulf.conf>

  Once the controller is setup up with nodes added, we can boot the
  compute nodes and check if the get configured based on the warewulf4
  configuration. Node should get IP which is in the range we defined.
  We need to say to qemu to boot from network (aka -boot n). To do so,
  `PXEBOOT` should be set and unset HDD_1. Because OpenQA starts all the
  machines, we can not trigger the compute nodes after the controller is
  ready to provision. Thus, compute nodes needs to wait somehow for some
  time and reboot constantly until the actual see a PXE connection to
  start the installation process.
  Compute nodes use F<hpc/tests/ww4_compute.pm>.

=head2 Test Case

  Test is successful once the controller is setup, compute nodes are able to
  install the container from PXE and controller is able to connect remotely
  into them.
=cut
