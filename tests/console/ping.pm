# SUSE's ping tests in openQA
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Very basic ping test.
# Tests pinging site-local IPv6, which had problems on ICMP datagram socket,
# there were also problems with sysctl setup (bsc#1200617).
#
# Maintainer: Petr Vorel <pvorel@suse.cz>

use Mojo::Base 'consoletest';
use testapi;
use version_utils qw(is_jeos is_sle);

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;

    record_info('net.ipv4.ping_group_range', script_output('sysctl net.ipv4.ping_group_range'));
    record_info('aaa_base', script_output('rpm -qi aaa_base'));
    record_info('KERNEL VERSION', script_output('uname -a'));
    record_info('sysctl', script_output('sysctl -V'));
    record_info('procps', script_output('rpm -qi procps'));

    my $kernel_pkg = is_jeos ? 'kernel-default-base' : 'kernel-default';
    record_info('KERNEL DEFAULT PKG', script_output("rpm -qi $kernel_pkg", proceed_on_failure => 1));

    my $ifname = script_output('ip -6 link |grep "^[0-9]:" |grep -v lo: | head -1 | awk "{print \$2}" | sed s/://');
    my $addr = script_output("ip -6 addr show $ifname | grep 'scope link' | head -1 | awk '{ print \$2 }' | cut -d/ -f1");

    my $cmd = "ping6 -c2 $addr%$ifname";
    record_info('ping %');
    assert_script_run($cmd);

    $cmd = "ping6 -c2 $addr -I$ifname";
    record_info('ping -I');
    my $rc = script_run($cmd);

    if ($rc) {
        my $bug;
        $bug = "bsc#1195826 or bsc#1200617" if is_sle('=15-SP4');
        $bug = "bsc#1196840 or bsc#1200617" if is_sle('=15-SP3');
        $bug = "bsc#1199918 or bsc#1200617" if is_sle('=15-SP2');
        $bug = "bsc#1199926" if is_sle('=15-SP1');
        $bug = "bsc#1199927" if is_sle('=15');

        if (defined($bug)) {
            record_soft_failure $bug;
        } else {
            $self->result("fail");
            record_info("Unknown failure, maybe related to: bsc#1200617, bsc#1195826, bsc#1196840, bsc#1199918, bsc#1199926, bsc#1199927");
        }
    }
}

sub test_flags {
    return {fatal => 0};
}

1;
