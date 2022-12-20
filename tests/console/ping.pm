# SUSE's ping tests in openQA
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Very basic ping tests.

# Tests pinging as user:
# * localhost (sanity checks for both RAW sockets used on older SLES/openSUSE
#   and newer ICMP datagram socket)
# * site-local IPv6, which had problems on ICMP datagram socket,
#   there were also problems with sysctl setup (bsc#1200617).
#
# Maintainer: Petr Vorel <pvorel@suse.cz>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use version_utils qw(is_jeos is_sle);

sub run {
    my ($self) = @_;

    select_serial_terminal;
    zypper_call('in iputils libcap-progs sudo');

    record_info('KERNEL VERSION', script_output('uname -a'));
    record_info('net.ipv4.ping_group_range', script_output('sysctl net.ipv4.ping_group_range'));
    record_info('ping', script_output('ping -V'));

    my $kernel_pkg = is_jeos ? 'kernel-default-base' : 'kernel-default';
    foreach my $pkg ($kernel_pkg, 'aaa_base', 'iputils', 'permissions', 'procps', 'systemd') {
        record_info($pkg, script_output("rpm -qi $pkg", proceed_on_failure => 1));
    }

    record_info('getcap', script_output('getcap $(which ping)', proceed_on_failure => 1));

    my $ifname = script_output('ip -6 link |grep "^[0-9]:" |grep -v lo: | head -1 | awk "{print \$2}" | sed s/://');
    my $addr = script_output("ip -6 addr show $ifname | grep 'scope link' | head -1 | awk '{ print \$2 }' | cut -d/ -f1");

    # test as non-root user
    my $sudo = 'sudo -u \#1000';
    record_info('id non-root', script_output("$sudo id", proceed_on_failure => 1));

    foreach my $cmd ("ping localhost", "ping6 ::1", "ping6 $addr%$ifname") {
        record_info($cmd);
        assert_script_run("$sudo $cmd -c2");
    }

    my $cmd = "ping6 -c2 $addr -I$ifname -v";
    my $rc = script_run("$sudo $cmd -c2");
    if ($rc) {
        my $bug;
        $bug = "bsc#1195826 or bsc#1200617" if is_sle('=15-SP4');
        $bug = "bsc#1196840 or bsc#1200617" if is_sle('=15-SP3');
        $bug = "bsc#1199918 or bsc#1200617" if is_sle('=15-SP2');
        $bug = "bsc#1199926" if is_sle('=15-SP1');
        $bug = "bsc#1199927" if is_sle('=15');

        if (defined($bug)) {
            record_info('Softfail', $bug, result => 'softfail');
        } else {
            record_info("Unknown failure on $cmd, maybe related to: bsc#1200617, bsc#1195826, bsc#1196840, bsc#1199918, bsc#1199926, bsc#1199927",
                result => 'fail');
            $self->result("fail");
        }
    }
}

sub test_flags {
    return {fatal => 0};
}

1;
