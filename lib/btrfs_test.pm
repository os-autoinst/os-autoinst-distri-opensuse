# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

package btrfs_test;
use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils 'get_root_console_tty';
use Exporter 'import';
use version_utils qw(is_sle);
use Utils::Systemd qw(systemctl);

our @EXPORT_OK = qw(set_playground_disk cleanup_partition_table);

=head2 set_playground_disk

Returns disk without a partition table for filesystem experiments.
Sets the test variable C<PLAYGROUNDDISK>, on first invocation of
the function.
=cut

sub set_playground_disk {
    unless (get_var('PLAYGROUNDDISK')) {
        my $vd = 'vd';    # KVM
        if (check_var('VIRSH_VMM_FAMILY', 'xen')) {
            $vd = 'xvd';
        }
        elsif (check_var('VIRSH_VMM_FAMILY', 'hyperv') or check_var('VIRSH_VMM_FAMILY', 'vmware')) {
            $vd = 'sd';
        }
        assert_script_run 'parted --script --machine -l';
        my $output = script_output 'parted --script --machine -l';
        # Parse playground disk
        $output =~ m|(?<disk>/dev/$vd[ab]):.*unknown.*| || die "Failed to parse playground disk, got following output:\n$output";
        set_var('PLAYGROUNDDISK', $+{disk});
    }
}

sub cleanup_partition_table {
    assert_script_run 'wipefs --force --all ' . get_var('PLAYGROUNDDISK');
}

=head2 snapper_nodbus_setup

In `snapper --no-dbus` test we need DBus to be disabled on SLES12SP3 and Leap 42.3
systemd allows DBus to be disabled. On Tumbleweed this is not possible and the simplest
way to get DBus-less environment is to enter rescue.target via systemctl.
=cut

sub snapper_nodbus_setup {
    my ($self) = @_;
    if (script_run('! systemctl is-active dbus')) {
        script_run('systemctl rescue', 0);
        if (!check_screen('emergency-shell', 120)) {
            assert_screen('emergency-shell-boo1134533', no_wait => 1);
            record_soft_failure 'boo#1134533 - Welcome message is missing in emergency shell';
        }
        type_password;
        send_key 'ret';
        $self->set_standard_prompt('root');
        assert_screen 'root-console';
    }
}

=head2 snapper_nodbus_restore

Restore environment to default.target. Console root-console has to be reset, because
move from rescue to default target, logs us out. Die if DBus is active at this point,
it means that DBus got activated somehow, thus invalidated `snapper --no-dbus` testing.
=cut

sub snapper_nodbus_restore {
    my $ret = script_run('systemctl is-active dbus', timeout => 300, die_on_timeout => 1);
    die 'DBus service should be inactive, but it is active' if ($ret == 0);
    script_run('systemctl default', timeout => 600, die_on_timeout => 0);
    my $tty = get_root_console_tty;

    if (is_sle('<15-SP3') && !defined(my $match = check_screen("tty$tty-selected", 120))) {
        record_soft_failure("bsc#1185098 - logind fails after return back from rescue");
        select_console('log-console');
        if (script_run('systemctl is-active getty@tty2.service', die_on_timeout => 1) == 3) {
            systemctl('start getty@tty2');
            reset_consoles;
        }
        select_console('root-console');
    }

    assert_screen "tty$tty-selected", 600;
    reset_consoles;
    select_console 'root-console';
}

=head2 cron_mock_lastrun
snapper-0.5 and older is using cron jobs in order to schedule and execute cleanup routines.
Script /usr/lib/cron/run-crons looks into /etc/cron.{hourly,daily,weekly,monthly} for jobs
to be executed. The info about last run is stored in /var/spool/cron/lastrun
By updating the lastrun files timestamps, we make sure those routines won't be executed
while tests are running.
=cut

sub cron_mock_lastrun {
    my $tries = 5;
    while (script_run(q/ps aux | grep '[s]napper'/) == 0 && $tries > 0) {
        sleep 30;
        bmwqemu::diag('Snapper is running in the background...');
        $tries--;
    }
    $tries or bmwqemu::diag('Snapper might be still running in the background');

    assert_script_run 'touch /var/spool/cron/lastrun/cron.{hourly,daily,weekly,monthly}';
    assert_script_run 'ls -al /var/spool/cron/lastrun/cron.{hourly,daily,weekly,monthly}';
}

sub post_fail_hook {
    my ($self) = shift;
    select_console('log-console');
    $self->SUPER::post_fail_hook;

    upload_logs('/var/log/snapper.log');
}

1;
