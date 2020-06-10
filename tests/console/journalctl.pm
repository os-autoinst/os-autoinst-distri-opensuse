# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
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
use testapi;
use utils;
use version_utils;
use power_action_utils 'power_action';

sub check_journal {
    my ($args, $filename, $fail_message) = @_;
    $fail_message //= "journalctl '$args' is empty";
    assert_script_run("journalctl -q $args > $filename");
    assert_script_run("if [ -s $filename ]; then true; else false; fi", fail_message => "$fail_message");
}

sub check_syslog {
    # rsyslog is not installed on tumbleweed anymore
    return !is_tumbleweed && !is_jeos;
}

sub isPublicCloud {
    return get_var('PUBLIC_CLOUD');
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
    # Enable persistent journal and reboot system
    assert_script_run("sed -i 's/.*Storage=.*/Storage=persistent/' /etc/systemd/journald.conf");
    assert_script_run("sed -i 's/.*Seal=.*/Seal=yes/' /etc/systemd/journald.conf");
    assert_script_run("systemctl restart systemd-journald");
    # Setup FSS keys before reboot
    assert_script_run('journalctl --interval=10s --setup-keys | tee /var/tmp/journalctl-setup-keys.txt');
    assert_script_run('journalctl --rotate');
    assert_script_run("date '+%F %T' > /var/tmp/reboottime");
    assert_script_run("echo 'The batman is going to sleep' | systemd-cat -p info -t batman");
    if (!isPublicCloud) {
        power_action('reboot', textmode => 1);
        $self->wait_boot(bootloader_time => 200);
        select_console 'root-console';
    } else {
        # TODO: Handle reboots on public cloud
        record_info("publiccloud", "Public cloud omits rebooting (temporary workaround)");
    }
    # Check journal state after reboot to trigger bsc#1171858
    record_soft_failure "bsc#1171858" if (script_run('journalctl --verify --verify-key=`cat /var/tmp/journalctl-setup-keys.txt`') != 0);
    # Basic journalctl tests: Export journalctl with various arguments and ensure they are not empty
    check_journal('',                               "journalctl.txt",        "journalctl empty");
    check_journal('--boot=-1',                      "journalctl-1.txt",      "journalctl of previous boot empty") unless isPublicCloud;
    check_journal('-S "`cat /var/tmp/reboottime`"', "journalctl-after.txt",  "journalctl after reboot empty");
    check_journal('-U "`cat /var/tmp/reboottime`"', "journalctl-before.txt", "journalctl before reboot empty");
    check_journal("-k",                             "journalctl-dmesg.txt",  "journalctl dmesg empty");
    assert_script_run('journalctl --identifier=batman --boot=-1| grep "The batman is going to sleep"', fail_message => "Error getting beacon from previous boot") unless isPublicCloud;
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
    record_soft_failure "bsc#1171858" if (script_run('journalctl --verify --verify-key=`cat /var/tmp/journalctl-setup-keys.txt`') != 0);
    assert_script_run('journalctl --rotate');
    record_soft_failure "bsc#1171858" if (script_run('journalctl --verify --verify-key=`cat /var/tmp/journalctl-setup-keys.txt`') != 0);
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
    cleanup();
}

sub post_run_hook {
    cleanup();
}

1;
