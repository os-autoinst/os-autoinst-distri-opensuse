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

use Mojo::Base 'consoletest';
use utils 'systemctl';
use Utils::Architectures;
use package_utils 'install_package';
use version_utils qw(is_sle is_leap is_opensuse);
use testapi;
use serial_terminal 'select_serial_terminal';
use version;

sub run {
    select_serial_terminal;
    install_package('sysstat', trup_reboot => 1);
    script_run 'rm -rf /var/log/sa/sa*';
    systemctl 'start sysstat.service';
    systemctl 'stop sysstat.service';
    systemctl 'restart sysstat.service';
    #disable color output
    assert_script_run 'export S_COLORS=never';

    # Capture the current day before running sa1 to avoid a midnight date-rollover race:
    # sa1 takes ~25s; if it straddles UTC midnight the samples land in yesterday's file
    # while subsequent bare 'sar' calls would open the empty new-day file and find no data.
    my $sa_file;
    if (is_sle('>=12-SP2') || is_opensuse) {
        $sa_file = 'sa' . script_output("date +'%Y%m%d'", proceed_on_failure => 0);
    } else {
        $sa_file = 'sa' . script_output("date +'%d'", proceed_on_failure => 0);
    }

    #compare todays date with todays generated file.
    assert_script_run "test -e /var/log/sa/$sa_file";

    #Populate /var/log/sa/$sa_file, that data will be used on the next tests
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

    #mpstat 5 mpstat device iterations, we confirm success couting the summary 'all' column spawns
    validate_script_output "mpstat -P ALL 2 5 |grep all |wc -l", sub { /6/ };

    #header integrity checks:
    if (is_sle('>=12-SP2') || is_opensuse) {
        validate_script_output "sar -r -f /var/log/sa/$sa_file", sub { /kbmemfree   kbavail kbmemused  %memused kbbuffers  kbcached  kbcommit   %commit  kbactive   kbinact   kbdirty/ };
        validate_script_output "pidstat", sub { /UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command/ };
    } else {
        validate_script_output "sar -r -f /var/log/sa/$sa_file", sub { /kbmemfree kbmemused  %memused kbbuffers  kbcached  kbcommit   %commit  kbactive   kbinact   kbdirty/ };
        validate_script_output "pidstat", sub { /UID       PID    %usr %system  %guest    %CPU   CPU  Command/ };
    }

    validate_script_output "iostat", sub { /avg-cpu:  %user   %nice %system %iowait  %steal   %idle/ };
    validate_script_output "mpstat", sub { /CPU    %usr   %nice    %sys %iowait    %irq   %soft  %steal  %guest  %gnice   %idle/ };
    validate_script_output "sar -u -f /var/log/sa/$sa_file", sub { /CPU     %user     %nice   %system   %iowait    %steal     %idle/ };
    validate_script_output "sar -n DEV -f /var/log/sa/$sa_file", sub { /IFACE   rxpck\/s   txpck\/s    rxkB\/s    txkB\/s   rxcmp\/s   txcmp\/s  rxmcst\/s   %ifutil/ };
    #from version 12.1.2 iostat supports discard I/O statistics.
    if (version->parse(script_output('rpm --qf "%{VERSION}\n" -q sysstat')) >= version->parse('12.1.2')) {
        validate_script_output "sar -b -f /var/log/sa/$sa_file", sub { /tps      rtps      wtps      dtps   bread\/s   bwrtn\/s   bdscd\/s/ };
    } else {
        validate_script_output "sar -b -f /var/log/sa/$sa_file", sub { /tps      rtps      wtps   bread\/s   bwrtn\/s/ };
    }
    if (version->parse(script_output('rpm --qf "%{VERSION}\n" -q sysstat')) >= version->parse('12.7.5')) {
        validate_script_output "sar -B -f /var/log/sa/$sa_file", sub { /pgpgin\/s pgpgout\/s   fault\/s  majflt\/s  pgfree\/s pgscank\/s pgscand\/s pgsteal\/s  pgprom\/s   pgdem\/s/ };
    } else {
        validate_script_output "sar -B -f /var/log/sa/$sa_file", sub { /pgpgin\/s pgpgout\/s   fault\/s  majflt\/s  pgfree\/s pgscank\/s pgscand\/s pgsteal\/s    %vmeff/ };
    }
    validate_script_output "sar -H -f /var/log/sa/$sa_file", sub { /kbhugfree kbhugused  %hugused/ };
    validate_script_output "sar -S -f /var/log/sa/$sa_file", sub { /kbswpfree kbswpused  %swpused  kbswpcad   %swpcad/ };

    assert_script_run 'unset S_COLORS';

    # teardown
    systemctl 'stop sysstat.service';
}

1;
