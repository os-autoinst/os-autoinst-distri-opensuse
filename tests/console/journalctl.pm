# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: systemd
# Summary: Test basic journalctl functionality
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
#             Martin Loviska <martin.loviska@suse.com>
# Tags: bsc#1063066 bsc#1171858

use Mojo::Base qw(consoletest);
use Date::Parse qw(str2time);
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call script_retry systemctl);
use version_utils qw(is_opensuse is_tumbleweed is_sle is_public_cloud is_leap is_jeos);
use Utils::Backends qw(is_hyperv);
use Utils::Architectures;
use power_action_utils qw(power_action);
use publiccloud::instances;
use constant {
    PERSISTENT_LOG_DIR => '/var/log/journal',
    DROPIN_DIR => '/etc/systemd/journald.conf.d',
    SYSLOG => '/var/log/messages',
    SEALING_DELAY => 10
};

# Tumbleweed uses a persistent journal, Leap 15.3+ (except 15.3 AArch64 JeOS) inherits SLE's default
sub has_default_persistent_journal {
    return is_tumbleweed || (is_leap('=15.3') && check_var('FLAVOR', 'JeOS-for-AArch64'));
}

# If the daemon is stopped uncleanly, or if the files are found to be corrupted, they are renamed using the ".journal~" suffix
sub corrupted_logfiles {
    return script_output('find /var/log/journal/ -iname "*.journal~" -type f -print0') ne "";
}

sub is_journal_empty {
    my ($args, $filename) = @_;
    assert_script_run("journalctl -q $args > $filename");
    return (script_run("[ -s $filename ]") != 0);
}

sub verify_journal {
    my $fss_key = shift;
    # Run journalctl --verify and on failure check for 'File corruption detected'
    # if that happens, run it again after waiting some time and softfailure to https://bugzilla.suse.com/show_bug.cgi?id=1178193
    my $cmd = 'journalctl --verify';
    $cmd .= " --verify-key=$fss_key" if defined($fss_key);

    assert_script_run('journalctl --flush');    # ensure data is written to persistent log
    return if (script_run("$cmd 2>&1 | tee errs") == 0);
    # Check for https://bugzilla.suse.com/show_bug.cgi?id=1171858, corruption bug when FSS is enabled
    if (defined($fss_key) && (script_run("grep 'tag/entry realtime timestamp out of synchronization' errs") == 0)) {
        # upstream issue
        # https://github.com/systemd/systemd/issues/17833
        record_soft_failure 'bsc#1171858 - journal corruption: "tag/entry realtime timestamp out of synchronization"';
    } elsif (defined($fss_key) && (script_run("grep -E 'No sealing yet,.*of entries not sealed.' errs") == 0)) {
        die "Sealing is not working!\n";
        # Check for https://bugzilla.suse.com/show_bug.cgi?id=1178193, a race condition for `journalctl --verify`
    } elsif (script_run("grep 'File corruption detected' errs") == 0) {
        record_soft_failure("bsc#1178193 - Journal corruption race condition");
    } elsif (corrupted_logfiles) {
        die "The daemon is stopped not in a clean way, or corrupted files have been detected\n";
    } else {
        assert_script_run("mv errs journalctl-verify-err.txt");
        upload_logs('journalctl-verify-err.txt');
        die "journalctl --verify failed";
    }
}

sub reboot {
    my ($self) = @_;

    if (is_public_cloud) {
        # Reboot on publiccloud needs to happen via their dedicated reboot routine
        my $instance = publiccloud::instances::get_instance();
        $instance->softreboot();
    } else {
        power_action('reboot', textmode => 1);
        $self->wait_boot(bootloader_time => 300);
        select_serial_terminal;
    }
}

sub get_current_boot_id {
    my $boot_list = shift;
    push @{$boot_list}, script_output('sed "s/-//g" /proc/sys/kernel/random/boot_id');
}

sub write_test_log_entries {
    my $entries = shift;
    foreach (keys(%{$entries})) {
        assert_script_run("systemd-cat --priority=$_ --identifier=batman echo $entries->{$_}");
    }
}

sub assert_test_log_entries {
    my ($entries, $boots) = @_;
    foreach my $bootid (@{$boots}) {
        foreach (keys(%{$entries})) {
            script_retry("journalctl --boot=$bootid --identifier=batman --priority=$_ --output=short | grep $entries->{$_}",
                retry => 5, delay => 2);
            script_retry("grep $entries->{$_} ${\ SYSLOG }", retry => 5, delay => 2, die => 0) if !has_default_persistent_journal;
        }
    }
}

sub rotatelogs_and_verify {
    my @existing_rotations = split('\n', script_output('find /var/log/journal/ -regex ".*system\@.*" -o -regex ".*user-.*"'));
    my $systemd_journal_birth = script_output 'stat -c %W /var/log/journal/$(cat /etc/machine-id)/system.journal';
    my @errors;
    assert_script_run('journalctl --rotate');
    ($systemd_journal_birth >= script_output('stat -c %W /var/log/journal/$(cat /etc/machine-id)/system.journal')) &&
      push @errors, 'New system.journal file has not been created!';
    (@existing_rotations >= script_output('find /var/log/journal/ -regex ".*system\@.*" -o -regex ".*user-.*" |wc -l')) &&
      push @errors, 'Logs have not been rotated!';

    foreach my $emsg (@errors) {
        if (($emsg eq 'New system.journal file has not been created!') && (is_leap('<15.3') || is_sle('<15-sp3'))) {
            record_soft_failure 'bsc#1183721 - brtime of file is empty';
        } else {
            die join('\n', @errors);
        }
    }
}

sub run {
    my ($self) = @_;
    select_serial_terminal;
    my %log_entries = (
        info => q{'(Testing, journalctl.pm) We need to call batman'},
        err => q{'(Testing, journalctl.pm) We NEED to call the batman NOW'},
        emerg => q{'(Testing, journalctl.pm) CALL THE BATMAN NOW!1!! AARRGGH!!'}
    );
    my @boots;

    # Ensure the time is correct, otherwise we might run into issues with the persistent journal
    # See e.g. https://bugzilla.suse.com/show_bug.cgi?id=1182802

    if (is_sle("<15")) {
        # SLES12 on Publiccloud has ntp enabled by default.
        if (!is_public_cloud) {
            # SLE 12 has no chrony by default but uses ntp
            assert_script_run("ntpdate -b 0.suse.pool.ntp.org", fail_message => "forced time sync failed");
            assert_script_run("systemctl enable --now ntpd");
            # We're not enabling ntp-wait until bsc#1207042 is resolved
            record_soft_failure("bsc#1207042 - Won't enable ntp-wait due to cron issues");
            #assert_script_run("systemctl enable ntp-wait.service");
        }
    } else {
        assert_script_run("systemctl start chronyd");
        script_retry("chronyc waitsync 60 1 0 5", timeout => 300, retry => 3, die => 1);
        systemctl('enable chrony-wait.service');
    }

    # create dropin directory for further journal.conf updates if it does not exists
    if (script_run "test -d ${\ DROPIN_DIR }") {
        assert_script_run "mkdir -p ${\ DROPIN_DIR }/";
    }

    # Enable persistent journal or check if it is enabled by default in opensuse
    # journald.conf is almost identical for opensuse and sle
    # default settings Storage=Auto behaves like "persistent" if the */var/log/journal* directory exists,
    # and "volatile" otherwise (the existence of the directory controls the storage mode).
    # Other configuration changes should be overridden using _drop-in_ file
    # To enable persistent logging in opensuse, we use systemd-logger.rpm that creates */var/log/journal/* directory
    get_current_boot_id \@boots;
    if (has_default_persistent_journal) {
        if (is_tumbleweed) {
            script_output(sprintf("test -d %s && ls --almost-all %s", PERSISTENT_LOG_DIR, PERSISTENT_LOG_DIR));
        } else {
            assert_script_run 'rpm -q systemd-logger';
            assert_script_run "rpm -q --conflicts systemd-logger | tee -a /dev/$serialdev | grep syslog";
        }
    } else {
        validate_script_output('journalctl --no-pager --boot=-1 2>&1', qr/no persistent journal was found/i, fail_message => "Persistent journal present where it shouldn't be") unless is_sle('<15');
        assert_script_run "mkdir -p ${\ PERSISTENT_LOG_DIR }";
        assert_script_run "systemd-tmpfiles --create --prefix ${\ PERSISTENT_LOG_DIR }";
        # https://bugzilla.suse.com/show_bug.cgi?id=1196637
        # should be backported to sle15sp3/leap15.3 later
        assert_script_run 'journalctl --flush' if (is_sle('15-sp4+') || is_leap('15.4+'));
        # test for installed rsyslog and for imuxsock existance
        # rsyslog must be there by design
        if (is_sle('=15-sp1') && is_jeos) {
            zypper_call 'in rsyslog';
            systemctl 'enable --now rsyslog';
        }
        assert_script_run 'rpm -q rsyslog';
        assert_script_run 'test -S /run/systemd/journal/syslog';
        upload_logs(${\SYSLOG});
        systemctl 'restart systemd-journald';
    }

    # Write first series of messages with different log priority
    write_test_log_entries \%log_entries;
    assert_test_log_entries(\%log_entries, \@boots);

    assert_script_run("date '+%F %T' | tee /var/tmp/reboottime");
    assert_script_run("echo 'The batman is going to sleep' | systemd-cat -p info -t batman");
    script_run('journalctl --list-boots');    # Debug output to help identify issues when less than 2 boots are displayed
    reboot($self);
    get_current_boot_id \@boots;
    my $listed_boots = script_output 'journalctl --list-boots';
    my @listed_boots = split('\n', $listed_boots);
    if (scalar(@listed_boots) < 2) {
        record_info("list-boots", $listed_boots);
        die "journal lists less than 2 boots";
    }
    is_journal_empty('--boot=-1', "journalctl-1.txt");
    script_retry('journalctl --identifier=batman --boot=-1| grep "The batman is going to sleep"', retry => 5, delay => 2);
    script_run('echo -e "Reboot time:  `cat /var/tmp/reboottime`\nCurrent time: `date -u \'+%F %T\'`"');
    die "journalctl after reboot empty" if is_journal_empty('-S "`cat /var/tmp/reboottime`"', "journalctl-after.txt");
    # Basic journalctl tests: Export journalctl with various arguments and ensure they are not empty
    die "journalctl output is empty!" if is_journal_empty('', "journalctl.txt");
    die "journalctl dmesg empty" if is_journal_empty("-k", "journalctl-dmesg.txt");

    # Check boot times from journal
    unless (is_journal_empty('-U "`cat /var/tmp/reboottime`"', "journalctl-before.txt")) {
        # Check for bsc1173856, i.e. the first date in the journal is newer than the last date
        my $awk = '{print($1 " " $2 " " $3);}';
        my $f_time = script_output("journalctl -q | head -n 1 | awk '$awk'", proceed_on_failure => 1);
        my $l_time = script_output("journalctl -q | tail -n 1 | awk '$awk'", proceed_on_failure => 1);
        record_info 'head time', "$f_time -> " . str2time($f_time);
        record_info 'tail time', "$l_time -> " . str2time($l_time);
        if (str2time($f_time) >= str2time($l_time)) {
            record_soft_failure "bsc#1173856 - journalctl until breaks when time is set back";
            die "journalctl before reboot is empty" unless is_hyperv;
        }
    }
    assert_script_run('journalctl --sync');
    assert_script_run('journalctl --flush');
    # Write second series of messages with different log priority
    # and grep with according to bootID
    write_test_log_entries \%log_entries;
    assert_test_log_entries(\%log_entries, \@boots);

    # Check journal state after reboot to trigger bsc#1171858
    verify_journal();
    # Note: Detailled error message is "Specifying boot ID or boot offset has no effect, no persistent journal was found."
    # Create virtual serial console for journal redirecting
    if (is_opensuse && !is_leap('>=15.3')) {
        zypper_call 'in socat';
        script_run('socat pty,raw,echo=0,link=/dev/ttyS100 pty,raw,echo=0,link=/dev/ttyS101 & true');
        assert_script_run('jobs | grep socat', fail_message => "socat is not running");
        # Redirect journal to virtual serial console and syslog
        assert_script_run qq(echo -e '[Journal]\\nForwardToConsole=yes\\nTTYPath=/dev/ttyS100\\nMaxLevelConsole=info' |tee ${\ DROPIN_DIR }/fw-ttyS100.conf);
        systemctl 'restart systemd-journald.service';
        script_run('cat /dev/ttyS101 > /var/tmp/journal_serial.out & true');
        assert_script_run('echo "journal redirect output started (grep for: aeru4Poh eiDeik5l)" | systemd-cat -p info -t redirect');
        die "Serial forward failed" if (script_retry('grep "aeru4Poh eiDeik5l" /var/tmp/journal_serial.out', retry => 5, delay => 2, die => 0) != 0);
        # Stop redirecting to serial console and syslog
        assert_script_run('rm /etc/systemd/journald.conf.d/fw-ttyS100.conf');
        systemctl 'restart systemd-journald.service';
        # Terminate background jobs (for serial console)
        script_run("kill %2");
        script_run("kill %1");
    }
    # Sync and Verify journal before FSS
    assert_script_run 'journalctl --disk-usage';
    assert_script_run 'journalctl --sync';
    assert_script_run 'journalctl --flush';
    verify_journal();

    if (is_sle('=15') && is_s390x) {
        zypper_call 'in haveged';
        systemctl 'start haveged';
    }

    die("System is not using persistent logging\n")
      if (script_output('journalctl --interval=10s --setup-keys 2>&1 | tee /var/tmp/journalctl-setup-keys.txt') =~
        '/var/log/journal is not a directory, must be using persistent logging for FSS.');
    my $key_regex = qr|(\b([a-f0-9]{6}-){3}[a-f0-9]{6}\/[a-f0-9]{7}-[a-f0-9]{6}\b)|;
    my $keyid;
    if (script_output('cat /var/tmp/journalctl-setup-keys.txt') =~ $key_regex) {
        $keyid = $1;
    } else {
        die "FSS key regex does not match\n";
    }

    # Set new log entries for FSS checks
    %log_entries = (
        info => q{'(Testing, journalctl.pm) We need to call batman-after sealing'},
        err => q{'(Testing, journalctl.pm) We NEED to call the batman NOW-after sealing'},
        emerg => q{'(Testing, journalctl.pm) CALL THE BATMAN NOW!1!! AARRGGH!!-after sealing'}
    );
    rotatelogs_and_verify;
    # remove first bootid
    # Write second series of messages with different log priority
    shift @boots;
    write_test_log_entries \%log_entries;
    assert_test_log_entries(\%log_entries, \@boots);
    # verify sealing
    sleep ${\SEALING_DELAY};
    verify_journal($keyid);
    # Rotate once more and verify the journal afterwards
    rotatelogs_and_verify;
    # Additional journalctl commands/use cases
    assert_script_run('journalctl --vacuum-size=100M');
    assert_script_run('journalctl --vacuum-time=1years');
    assert_script_run 'journalctl --disk-usage';
}

sub cleanup {
    script_run('rm -f /var/tmp/journalctl.txt');
    script_run('rm -f /var/tmp/journalctl-setup-keys.txt');
    script_run('rm -f /var/tmp/journal_serial.out');
    script_run('rm -f /var/tmp/reboottime');
    script_run("rm -rf ${\ DROPIN_DIR }");
    systemctl('stop haveged') if (is_sle('=15') && is_s390x);
}

sub post_fail_hook {

    shift->SUPER::post_fail_hook;
    script_run 'cp -a /var/log/journal /var/log/journal-backup';
    script_run 'tar Jcvf journal-backup.tar.xz /var/log/journal-backup';
    sleep 5;
    script_run 'tar Jcvf journal.tar.xz /var/log/journal/';
    if (script_run('test -s /var/tmp/journalctl-setup-keys.txt') == 0) {
        upload_logs('/var/tmp/journalctl-setup-keys.txt');
    }
    upload_logs('/etc/systemd/journald.conf');
    upload_logs('./journal.tar.xz');
    upload_logs('./journal-backup.tar.xz');
    cleanup();
}

sub post_run_hook {
    cleanup();
}

1;
