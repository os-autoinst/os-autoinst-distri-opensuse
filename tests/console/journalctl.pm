# SUSE's openQA tests
#
# Copyright © 2018-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test basic journalctl functionality
# - assert bsc#1063066 is not present (Verify "man -P cat journalctl" for broken man page format)
# - setup persistent journal
# - setup FSS, rotate log, verify, reboot and verify again (See bsc#1171858)
# - check if log entry from previous boots are present
# - check if log filtering by time works
# - check if journalctl kernel messages are present (non-empty output)
# - check if redirect to serial port is working
# - check if redirect to syslog is working (if applicable)
# - check if journalctl vacuum functions are working
# - verify FSS log again
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>
#             Sergio Lindo Mansilla <slindomansilla@suse.com>
# Tags: bsc#1063066 bsc#1171858

use base "consoletest";
use strict;
use warnings;
use Date::Parse;
use testapi;
use utils;
use version_utils;
use power_action_utils 'power_action';

sub check_journal {
    my ($args, $filename) = @_;
    assert_script_run("journalctl -q $args > $filename");
    return script_run("if [ -s $filename ]; then true; else false; fi");
}

sub skip_fss_check {
    # FSS check is not supported by SLE. Disable this check for SLES
    return is_sle;
}

sub check_syslog {
    # rsyslog is not installed on tumbleweed anymore
    return !is_tumbleweed && !is_jeos;
}

sub verify_journal {
    # Run journalctl --verify and on failure check for 'File corruption detected'
    # if that happens, run it again after waiting some time and softfailure to https://bugzilla.suse.com/show_bug.cgi?id=1178193
    my $cmd = "journalctl --verify";
    $cmd = 'journalctl --verify --verify-key=`cat /var/tmp/journalctl-setup-keys.txt`' unless skip_fss_check;

    return if (script_run("$cmd 2>&1 | tee errs") == 0);
    # Check for https://bugzilla.suse.com/show_bug.cgi?id=1171858, corruption bug when FSS is enabled
    if (!skip_fss_check && script_run("grep 'tag/entry realtime timestamp out of synchronization' errs") == 0) {
        record_soft_failure "bsc#1171858";
        # Check for https://bugzilla.suse.com/show_bug.cgi?id=1178193, a race condition for `journalctl --verify`
    } elsif (script_run("grep 'File corruption detected' errs") == 0) {
        record_soft_failure("bsc#1178193 - Journal corruption race condition");
        record_soft_failure("bsc#1178193") if (script_retry("$cmd", retry => 6, delay => 10, timeout => 10, die => 0) != 0);
    } else {
        assert_script_run("mv errs journalctl-verify-err.txt");
        upload_logs('journalctl-verify-err.txt');
        die "journalctl --verify failed";
    }
}

sub reboot {
    my ($self) = @_;
    power_action('reboot', textmode => 1);
    $self->wait_boot(bootloader_time => 300);
    select_console 'root-console';
}

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    zypper_call 'in socat';
    # Test for bsc#1063066
    if (script_run('command -v man') == 0) {
        my $output = script_output('man -P cat journalctl');
        record_soft_failure('bsc#1063066 - broken manpage') if ($output =~ m/\s+\.SH /);
    }
    # Enable persistent journal
    assert_script_run("sed -i 's/.*Storage=.*/Storage=persistent/' /etc/systemd/journald.conf");
    assert_script_run("sed -i 's/.*Seal=.*/Seal=yes/' /etc/systemd/journald.conf") unless skip_fss_check;
    assert_script_run("systemctl restart systemd-journald");
    assert_script_run("journalctl -e | grep -i 'Flush Journal to Persistent Storage'");
    # Setup FSS keys before reboot
    assert_script_run('journalctl --interval=10s --setup-keys | tee /var/tmp/journalctl-setup-keys.txt && journalctl --rotate') unless skip_fss_check;
    assert_script_run("date '+%F %T' | tee /var/tmp/reboottime");
    assert_script_run("echo 'The batman is going to sleep' | systemd-cat -p info -t batman");
    # Reboot system - public cloud does not handle reboot well atm
    if (!is_public_cloud) {
        reboot($self);
    } else {
        # TODO: Handle reboots on public cloud
        record_info("publiccloud", "Public cloud omits rebooting (temporary workaround)");
    }
    # Check journal state after reboot to trigger bsc#1171858
    record_soft_failure "bsc#1171858" if (!skip_fss_check && script_run('journalctl --verify --verify-key=`cat /var/tmp/journalctl-setup-keys.txt`') != 0);
    # Basic journalctl tests: Export journalctl with various arguments and ensure they are not empty
    script_run('echo -e "Reboot time:  `cat /var/tmp/reboottime`\nCurrent time: `date -u \'+%F %T\'`"');
    die "journalctl empty" if check_journal('', "journalctl.txt");
    die "journalctl of previous boot empty" if !is_public_cloud && check_journal('--boot=-1', "journalctl-1.txt");
    # Note: Detailled error message is "Specifying boot ID or boot offset has no effect, no persistent journal was found."
    die "no persistent journal was found" if script_run("journalctl --boot=-1 | grep 'no persistent journal was found'") == 0;
    die "journalctl after reboot empty"   if check_journal('-S "`cat /var/tmp/reboottime`"', "journalctl-after.txt");
    if (check_journal('-U "`cat /var/tmp/reboottime`"', "journalctl-before.txt")) {
        # Check for bsc1173856, i.e. the first date in the journal is newer than the last date
        my $awk    = '{print($1 " " $2 " " $3);}';
        my $f_time = script_output("journalctl -q | head -n 1 | awk '$awk'", proceed_on_failure => 1);
        my $l_time = script_output("journalctl -q | tail -n 1 | awk '$awk'", proceed_on_failure => 1);
        if (str2time($f_time) > str2time($l_time)) {
            record_soft_failure "bsc#1173856";
        } else {
            die "journalctl before reboot empty";
        }
    }
    die "journalctl dmesg empty" if check_journal("-k", "journalctl-dmesg.txt");
    assert_script_run('journalctl --identifier=batman --boot=-1| grep "The batman is going to sleep"', fail_message => "Error getting beacon from previous boot") unless is_public_cloud;
    # Create virtual serial console for journal redirecting
    script_run('socat pty,raw,echo=0,link=/dev/ttyS100 pty,raw,echo=0,link=/dev/ttyS101 & true');
    assert_script_run('jobs | grep socat', fail_message => "socat is not running");
    # Redirect journal to virtual serial console and syslog
    assert_script_run('mkdir -p /etc/systemd/journald.conf.d/');
    assert_script_run('echo -e "[Journal]\nForwardToConsole=yes\nTTYPath=/dev/ttyS100\nMaxLevelConsole=info" > /etc/systemd/journald.conf.d/fw-ttyS100.conf');
    assert_script_run('echo -e "ForwardToSyslog=yes" >> /etc/systemd/journald.conf.d/fw-ttyS100.conf') if check_syslog;
    assert_script_run('systemctl restart systemd-journald.service');
    script_run('cat /dev/ttyS101 > /var/tmp/journal_serial.out & true');
    assert_script_run('echo "journal redirect output started (grep for: aeru4Poh eiDeik5l)" | systemd-cat -p info -t redirect');
    # Write messages and check for them
    assert_script_run('echo "We need to call batman" | systemd-cat -p info -t batman');
    assert_script_run('echo "We NEED to call the batman NOW" | systemd-cat -p err -t batman');
    assert_script_run("echo 'CALL THE BATMAN NOW!1!! AARRGGH!!' | systemd-cat -p emerg -t batman");
    assert_script_run('journalctl --sync');
    assert_script_run('journalctl --flush');
    assert_script_run('journalctl --identifier=batman | grep "We need to call batman"');
    assert_script_run('journalctl --identifier=batman | grep "We NEED to call the batman NOW"');
    assert_script_run('journalctl -p 3 --identifier=batman | grep "We NEED to call the batman NOW"');
    die "journalctl -p 3 selection criterion failed" if (script_run('journalctl -p 3 --identifier=batman | grep "We need to call batman"') == 0);
    die "journalctl -p 0 selection criterion failed (non emerg entries shown)" if (script_run('journalctl -p 0 --identifier=batman | grep -v "CALL THE BATMAN NOW" | grep "batman"') == 0);
    assert_script_run('journalctl -p 0 --identifier=batman | grep "CALL THE BATMAN NOW"', fail_message => "journalctl -p 0 selection criterion failed (emerg entry not shown)");
    # Stop redirecting to serial console and syslog
    assert_script_run('rm /etc/systemd/journald.conf.d/fw-ttyS100.conf');
    assert_script_run('systemctl restart systemd-journald.service');
    # Terminate background jobs (for serial console)
    script_run("kill %2");
    script_run("kill %1");
    assert_script_run('cat /var/tmp/journal_serial.out | grep "aeru4Poh eiDeik5l"', fail_message => "Forward to serial failed");
    assert_script_run('cat /var/log/messages | grep "aeru4Poh eiDeik5l"',           fail_message => "Forward to syslog failed") if check_syslog;
    script_run('journalctl -q > /var/tmp/journalctl.txt');
    upload_logs('/var/tmp/journalctl.txt');
    # Additional journalctl commands/use cases
    assert_script_run('journalctl --vacuum-size=100M');
    assert_script_run('journalctl --vacuum-time=1years');
    # Rotate once more and verify the journal afterwards
    verify_journal();
    assert_script_run('journalctl --rotate');
    verify_journal();
}

sub cleanup {
    script_run('rm -f /var/tmp/journalctl.txt');
    script_run('rm -f /var/tmp/journalctl-setup-keys.txt');
    script_run('rm -f /var/tmp/journal_serial.out');
    script_run('rm -f /var/tmp/reboottime');
}

sub post_fail_hook {
    script_run('journalctl -x > /var/tmp/journalctl.txt');
    upload_logs('/var/tmp/journalctl.txt');
    upload_logs('/etc/systemd/journald.conf');
    cleanup();
}

sub post_run_hook {
    cleanup();
}

1;
