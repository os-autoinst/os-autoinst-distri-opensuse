# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test procps installation and verify that its tools work as exepected
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use base 'opensusebasetest';
use testapi;
use utils;
use strict;
use warnings;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    zypper_call('in procps');

    assert_script_run("rpm -q procps");

    validate_script_output("free",    sub { m/total\s+used\s+free.*\nMem:\s+\d+\s+\d+\s+\d+.*(\n.*)+/ });
    validate_script_output("pgrep 1", sub { m/\d+/ });
    validate_script_output("pmap 1",  sub { m/1:\s+(.*systemd|init)/ });
    validate_script_output("pwdx 1",  sub { m/1:\s+\// });
    validate_script_output("vmstat",  sub { m/(procs\s-+memory-+\s-+swap-+\s-+io-+\s-+system-+\s-+cpu-+)\n.*\n(\s+|\d+)+/ });
    validate_script_output("w", sub { m/\d+:\d+:\d+\sup\s+(\d+|:)+(\s\w+|),\s+\d\s\w+,\s+load average:.*\nUSER\s+TTY\s+FROM\s+LOGIN@\s+IDLE\s+JCPU\s+PCPU\s+WHAT(\n.*)+/ });
    validate_script_output("sysctl kernel.random", sub { m/kernel\.random\.\w+\s=\s((\d+|\w+)|-)+/ });
    validate_script_output("ps -p 1",              sub { m/PID\sTTY\s+TIME\sCMD\n\s+1\s\?\s+\d+:\d+:\d+\s(systemd|init)/ });
    validate_script_output("top -b -n 1", sub { m/top - \d+:\d+:\d+ up\s+((\d+:\d+)|(\d+ \w+)|(\d+ \w+,\s+\d+:\d+)),\s+\d+ \w+,\s+load average: \d+.\d+, \d+.\d+, \d+.\d+\nTasks:\s+\d+ total,\s+\d+ running,\s+\d+ sleeping(.*|\n)+/ });
}

1;

