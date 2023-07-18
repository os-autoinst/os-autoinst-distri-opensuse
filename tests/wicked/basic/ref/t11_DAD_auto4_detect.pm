# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked wicked-service
# Summary: Check DAD (duplicate address detection) within auto4
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use List::Util qw(uniq);
use testapi;

sub pre_run_hook {
    my ($self) = @_;
    $self->do_barrier_create('setup');
    $self->do_barrier_create('ifup');
    $self->do_barrier_create('verify');
    $self->SUPER::pre_run_hook;
}

sub run {
    my ($self, $ctx) = @_;
    my $scapy = $self->get_container("scapy");

    assert_script_run(sprintf(q(ip addr add dev '%s' '169.254.0.1/16'), $ctx->iface()));
    assert_script_run(sprintf(q(ip link set dev '%s' up), $ctx->iface()));

    $self->get_from_data("wicked/arp-tool.py", "/root/arp-tool.py");

    my $podman_cmd = $self->container_runtime . " run --net host --privileged -v /root/:/host '$scapy' /usr/bin/python3 /host/arp-tool.py defend " . $ctx->iface() . " 169.254.0.0/16 --count 2";
    $podman_cmd .= " --robustness 3" if $self->need_network_tweaks();
    my $podman_pid = background_script_run($podman_cmd . ' >& /tmp/arp_tool.log');
    $self->add_post_log_file('/tmp/arp_tool.log');

    sleep 30 if $self->need_network_tweaks();
    $self->do_barrier('setup');
    $self->do_barrier('ifup');

    $self->wait_for_background_process($podman_pid, timeout => 300);
    my $output = script_output("cat /tmp/arp_tool.log");
    my @ips = uniq($output =~ /SND:.*psrc=(\d+\.\d+\.\d+\.\d+)/gm);
    die("Didn't found two claimed IP's") unless @ips == 2;
    for my $ip (@ips) {
        assert_script_run("! ping -c 1 $ip");
    }
    $self->do_barrier('verify');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
