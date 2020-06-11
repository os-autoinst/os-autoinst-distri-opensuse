# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: This is just bunch of random commands overviewing the public cloud instance
# We just register the system, install random package, see the system and network configuration
# This test module will fail at the end to prove that the test run will continue without rollback
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base 'consoletest';
use registration;
use warnings;
use testapi;
use strict;
use utils;

sub run {
    my ($self, $args) = @_;
    select_console 'root-console';

    script_run("hostname -f");
    assert_script_run("uname -a");

    assert_script_run("cat /etc/os-release");

    assert_script_run("ps aux | nl");

    assert_script_run("ip a s");
    assert_script_run("ip -6 a s");
    assert_script_run("ip r s");
    assert_script_run("ip -6 r s");

    assert_script_run("cat /etc/hosts");
    assert_script_run("cat /etc/resolv.conf");

    if (script_run("zypper -n in traceroute bzip2") == 8) {
        record_soft_failure('bsc#1165915');
        assert_script_run('update-ca-certificates');
        zypper_call("in traceroute bzip2");
    }
    assert_script_run("traceroute -I gate.suse.cz", 90);

    assert_script_run("rpm -qa > /tmp/rpm.list.txt");
    upload_logs('/tmp/rpm.list.txt');
    upload_logs('/var/log/zypper.log');

    assert_script_run("SUSEConnect --status-text");
    zypper_call("lr");
}

1;

