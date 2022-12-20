# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: sysstat
# Summary: test sysstat basic functionalities
# - Install sysstat
# - Start/stop/restart sysstat service
# - Test pidstat and validate output
# - Test iostat and validate output
# - Test mpstat and validate output
# - Test sar (-u, -n DEV, -b, -B, -H, -s options) and validate output
# Maintainer: QE-Core <qe-core@suse.de>

use base 'consoletest';
use utils qw(zypper_call systemctl);
use Utils::Architectures;
use version_utils qw(is_sle is_leap is_opensuse);
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use version;

sub run {
    select_serial_terminal;
    zypper_call 'in sysstat';
    script_run 'rm -rf /var/log/sa/sa*';
    systemctl 'start sysstat.service';
    systemctl 'stop sysstat.service';
    systemctl 'restart sysstat.service';
    #disable color output
    assert_script_run 'export S_COLORS=never';

    #compare todays date with todays generated file.
    if (is_sle('>=12-SP2') || is_opensuse) {
        assert_script_run "test -e /var/log/sa/sa`date +'%Y%m%d'`";
    } else {
        assert_script_run "test -e /var/log/sa/sa`date +'%d'`";
    }

    #Populate /var/log/sa/`date +'%Y%m%d'`, that data will be used on the next tests
    if (is_arm) {
        assert_script_run '/usr/lib/sa/sa1 5 5';
    } else {
        assert_script_run '/usr/lib64/sa/sa1 5 5';
    }

    #Set 24h clock(removes AM/PM extra column), extract a pid number, confirm its an integer
    validate_script_output "LC_TIME='C' pidstat  |awk '{print \$3}' |head |tail -n 1", sub { /^\d+$/ };

    #run 5 pidstat iterations, we confirm success counting the UID column spawns
    validate_script_output "pidstat 2 5 |grep  UID |wc -l", sub { /6/ };

    #run 5 iostat device iterations, we confirm success counting the Devices column spawns
    validate_script_output "iostat 2 5 |grep Device |wc -l", sub { /5/ };

    #mpstat 5 mpstat device iterations, we confirm success counting the summary 'all' column spawns
    validate_script_output "mpstat -P ALL 2 5 |grep all |wc -l", sub { /6/ };

    #header integrity checks:
    if (is_sle('>=12-SP2') || is_opensuse) {
        validate_script_output "sar -r", sub { /kbmemfree   kbavail kbmemused  %memused kbbuffers  kbcached  kbcommit   %commit  kbactive   kbinact   kbdirty/ };
        validate_script_output "pidstat", sub { /UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command/ };
    } else {
        validate_script_output "sar -r", sub { /kbmemfree kbmemused  %memused kbbuffers  kbcached  kbcommit   %commit  kbactive   kbinact   kbdirty/ };
        validate_script_output "pidstat", sub { /UID       PID    %usr %system  %guest    %CPU   CPU  Command/ };
    }

    validate_script_output "iostat", sub { /avg-cpu:  %user   %nice %system %iowait  %steal   %idle/ };
    validate_script_output "mpstat", sub { /CPU    %usr   %nice    %sys %iowait    %irq   %soft  %steal  %guest  %gnice   %idle/ };
    validate_script_output "sar -u", sub { /CPU     %user     %nice   %system   %iowait    %steal     %idle/ };
    validate_script_output "sar -n DEV", sub { /IFACE   rxpck\/s   txpck\/s    rxkB\/s    txkB\/s   rxcmp\/s   txcmp\/s  rxmcst\/s   %ifutil/ };
    #from version 12.1.2 iostat supports discard I/O statistics.
    if (version->parse(script_output('rpm --qf "%{VERSION}\n" -q sysstat')) >= version->parse('12.1.2')) {
        validate_script_output "sar -b", sub { /tps      rtps      wtps      dtps   bread\/s   bwrtn\/s   bdscd\/s/ };
    } else {
        validate_script_output "sar -b", sub { /tps      rtps      wtps   bread\/s   bwrtn\/s/ };
    }
    validate_script_output "sar -B", sub { /pgpgin\/s pgpgout\/s   fault\/s  majflt\/s  pgfree\/s pgscank\/s pgscand\/s pgsteal\/s    %vmeff/ };
    validate_script_output "sar -H", sub { /kbhugfree kbhugused  %hugused/ };
    validate_script_output "sar -S", sub { /kbswpfree kbswpused  %swpused  kbswpcad   %swpcad/ };

    assert_script_run 'unset S_COLORS';

    # teardown
    systemctl 'stop sysstat.service';
}

1;
