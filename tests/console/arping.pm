# SUSE's arping tests in openQA
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Very basic arping tests.
# Maintainer: Petr Vorel <pvorel@suse.cz>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use version_utils qw(is_sle);

sub run {
    my ($self) = @_;

    select_serial_terminal;

    if (script_run("arping -V") != 0) {
        zypper_call('in iputils');
    }

    record_info('arping', script_output('arping -V'));

    my $ifname = script_output('ip link | grep -v lo: | awk "/^[0-9]/ {print \$2}" | sed s/:// | head -1');
    my $ip = script_output("ip -4 addr show $ifname | awk '/inet.*brd/ { print \$2 }' | head -1 | cut -d/ -f1");
    my $route = script_output("ip route show default | awk '/default/ {print \$3}' | head -1");

    my @tests = (
        "-I $ifname -A -c1 $ip",
        "-I $ifname -U -c1 $ip",
        "-c2 $route",
        "-c2 -f $route",
        "-c2 -w5 $route",
        "-c1 -q $route",
        "-b -c1 $route",
    );

    # -i was added in s20190324
    # https://github.com/iputils/iputils/commit/97926373401e4e794fa90f87b42c6cac9c35daf7
    if (script_run('arping -V | grep -q -E "arping.*iputils.(s20190324|20)"') == 0) {
        push @tests, "-c1 -i2 $route";
    } else {
        record_info('Skipped', 'skipped tests for iputils < s20190324', result => 'softfail');
    }

    for my $cmd (@tests) {
        record_info($cmd);
        assert_script_run("time arping $cmd");
    }

    my $cmd = "arping -w2 $route";
    record_info($cmd);
    my $rc = script_run($cmd);
    if ($rc) {
        my $bug;
        $bug = "bsc#1225963" if is_sle('=15-SP4');
        if (defined($bug)) {
            record_info('Softfail', $bug, result => 'softfail');
        } else {
            record_info("Fail", "Unknown failure on $cmd, maybe related to: bsc#1225963",
                result => 'fail');
            $self->result("fail");
        }
    }
}

sub test_flags {
    return {fatal => 0};
}
1;
