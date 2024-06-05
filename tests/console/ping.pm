# SUSE's ping tests in openQA
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Very basic ping tests.
#
# Tests pinging as user:
# * various basic tests
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
    my $ping_group_range;
    my $capability;

    select_serial_terminal;
    $ping_group_range = script_output('sysctl net.ipv4.ping_group_range');

    zypper_call('in iputils libcap-progs sudo');
    $capability = script_output('getcap $(which ping)', proceed_on_failure => 1);

    record_info('KERNEL VERSION', script_output('uname -a'));
    record_info('net.ipv4.ping_group_range', $ping_group_range);
    record_info('ping', script_output('ping -V'));

    my $kernel_pkg = is_jeos ? 'kernel-default-base' : 'kernel-default';
    foreach my $pkg ($kernel_pkg, 'aaa_base', 'iputils', 'permissions', 'procps', 'systemd') {
        record_info($pkg, script_output("rpm -qi $pkg", proceed_on_failure => 1));
    }

    record_info('getcap', $capability);

    my $ifname = script_output('ip link | grep -v lo: | awk "/^[0-9]/ {print \$2}" | sed s/:// | head -1');
    my $ipv4 = script_output("ip -4 addr show $ifname | awk '/inet.*brd/ { print \$2 }' | head -1 | cut -d/ -f1");
    my $ipv6 = script_output("ip -6 addr show $ifname | awk '/scope link/ { print \$2 }' | head -1 | cut -d/ -f1");
    my $route = script_output("ip route show default | awk '/default/ {print \$3}' | head -1");

    # test as non-root user
    my $sudo = "sudo -u $testapi::username";
    record_info('id non-root', script_output("$sudo id", proceed_on_failure => 1));

    # basic tests
    my @tests = (
        'ping localhost',
        'ping6 ::1',
        "ping -w5 $route",
        "ping -W2 $route",
        "ping -i2 $route",
        "ping -s56 -D -v $route",
        "ping6 $ipv6%$ifname",
    );

    # -4 and -6 support and merged ping6 command into ping was added in s20150815
    # https://github.com/iputils/iputils/commit/ebad35fee3de851b809c7b72ccc654a72b6af61d
    if (script_run('ping -V | grep -q -E "ping.*iputils.(s20150815|s20[12][6-9]|20)"') == 0) {
        push @tests, 'ping -4 localhost';
        push @tests, 'ping -6 ::1';
        push @tests, 'ping ::1';
        push @tests, "ping $ipv6%$ifname",;
    } else {
        record_info('Skipped', 'skipped tests for iputils < s20150815', result => 'softfail');
    }

    # '.' (dot) as decimal separator for -i was forced since s20200821
    # https://github.com/iputils/iputils/commit/d865d4c468965bbff1b9d6b912eee44ade52967d
    # https://github.com/iputils/iputils/commit/1530bc9719c6bf4d01dd20b26e904995903d82d8
    if (script_run('ping -V | grep -q -E "ping.*iputils.(s20200821|20)"') == 0) {
        push @tests, "ping -i0.1 $route";
    } else {
        record_info('Skipped', 'skipped tests for iputils < s20200821', result => 'softfail');
    }

    for my $cmd (@tests) {
        record_info($cmd);
        assert_script_run("time $sudo $cmd -c2");
    }

    # IPv6 -I bug reproducibility
    my $cmd = "ping6 -c2 $ipv6 -I$ifname -v";
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
            record_info("Fail", "Unknown failure on $cmd, maybe related to: bsc#1200617, bsc#1195826, bsc#1196840, bsc#1199918, bsc#1199926, bsc#1199927",
                result => 'fail');
            $self->result("fail");
        }
    }

    if ($capability && $ping_group_range !~ m/^net.ipv4.ping_group_range\s*=\s*1\s*0/) {
        my $msg = "capability '$capability' is not needed when ICMP socket allowed for non-root user: '$ping_group_range'";
        if (is_sle('=15-SP3')) {
            record_info('Unneeded capability', "bsc#1196840#c29: $msg", result => 'softfail');
        } else {
            record_info('Unneeded capability', $msg, result => 'fail');
            $self->result("fail");
        }
    }
}

sub test_flags {
    return {fatal => 0};
}

1;
