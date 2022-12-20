# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: procps
# Summary: Test procps installation and verify that its tools work as expected
# - Install procps
# - Run free and check
# - Run pgrep 1 and check
# - Run pmap 1 and check
# - Run pwdx 1 and check
# - Run vmstat and check
# - Run w and check
# - Run sysctl kernel.random and check
# - Run ps -p 1 and check
# - Run top -b -n 1 and check
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use strict;
use warnings;

sub run {
    select_serial_terminal;

    zypper_call('in procps');

    assert_script_run("rpm -q procps");

    validate_script_output("free", sub { m/total\s+used\s+free.*\nMem:\s+\d+\s+\d+\s+\d+.*(\n.*)+/ });
    validate_script_output("pgrep 1", sub { m/\d+/ });
    validate_script_output("pmap 1", sub { m/1:\s+(.*systemd|init)/ });
    validate_script_output("pwdx 1", sub { m/1:\s+\// });
    validate_script_output("vmstat",
        qr/(procs\s-+memory-+\s-+swap-+\s-+io-+\s-+system-+\s-+cpu-+).*(\s+|\d+)+/s);
    validate_script_output("w",
        qr/\d+:\d+:\d+\sup\s+(\d+|:)+(\s\w+|),\s+\d\s\w+,\s+load average:.*USER\s+TTY\s+FROM\s+LOGIN@\s+IDLE\s+JCPU\s+PCPU\s+WHAT.*\w+/s);
    validate_script_output("sysctl kernel.random", sub { m/kernel\.random\.\w+\s=\s((\d+|\w+)|-)+/ });
    validate_script_output("ps -p 1",
        qr/PID\sTTY\s+TIME\sCMD\s+1\s\?\s+\d+:\d+:\d+\s(systemd|init)/);
    validate_script_output("top -b -n 1",
qr/top - \d+:\d+:\d+ up\s+((\d+:\d+)|(\d+ \w+)|(\d+ \w+,\s+\d+:\d+)),\s+\d+ \w+,\s+load average: \d+.\d+, \d+.\d+, \d+.\d+\s+Tasks:\s+\d+\s+total,\s+\d+\s+running,\s+\d+\s+sleeping.*top/s);
}

1;

