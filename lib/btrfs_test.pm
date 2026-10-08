# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

package btrfs_test;

use base 'consoletest';
use strict;
use warnings;
use Exporter 'import';
use testapi;
use utils 'get_root_console_tty';
use version_utils qw(is_sle is_jeos is_opensuse);
use Utils::Systemd qw(systemctl);
use JSON qw(decode_json);

our @EXPORT_OK = qw(set_playground_disk cleanup_partition_table);
my $old_snapper = undef;

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
    my $ret = script_run('systemctl is-active dbus', timeout => 300);
    die 'DBus service should be inactive, but it is active' if ($ret == 0);

    # workaround bsc#1231986 by enabling the tty before switching to default target
    script_run('systemctl enable getty@tty6.service') if (is_jeos && is_opensuse);

    script_run('systemctl default', timeout => 600);
    my $tty = get_root_console_tty;

    if (is_sle('<15-SP3') && !defined(my $match = check_screen("tty$tty-selected", 120))) {
        record_soft_failure("bsc#1185098 - logind fails after return back from rescue");
        select_console('log-console');
        if (script_run('systemctl is-active getty@tty2.service') == 3) {
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

# recent versions of snapper support json output
# otherwise fallback to old implementation of parsing
sub get_last_snap_number {
    if (!defined($old_snapper)) {
        $old_snapper = script_run('snapper --jsonout list --disable-used-space');
    }

    if (!!$old_snapper) {
        return _get_last_snap_number_old();
    }

    my $snaps = decode_json(script_output('snapper --jsonout list --disable-used-space'));
    my $last = (@{$snaps->{root}})[-1];
    return $last->{number};
}

# In many cases script output returns not only script execution results
# but other data which was written to serial device. We have to ensure
# that we got what we expect. See poo#25716
sub _get_last_snap_number_old {
    # get snapshot id column, parse output in perl to avoid SIGPIPE
    my $snap_head = script_output("snapper list");
    # strip kernel messages - for some reason we always get something like this at this very position:
    # [ 1248.663412] BTRFS info (device vda2): qgroup scan completed (inconsistency flag cleared)
    my @lines = split(/\n/, $snap_head);
    @lines = grep(/\|/, @lines);
    die "Unable to receive snapshot list column header line - got this output: $snap_head" unless (@lines);
    $snap_head = $lines[0];

    my $snap_col_found = 0;
    my $snap_id_col_index = 1;
    for my $field (split(/\|/, $snap_head)) {
        $field =~ s/^\s+|\s+$//g;    # trim spaces
        if ($field eq '#') {
            # get snapshot id field
            $snap_col_found = 1;
            last;
        }
        $snap_id_col_index++;
    }
    die "Unable to determine snapshot id column index" unless ($snap_col_found);

    my $output = script_output("snapper list | tail -n1 | awk -F '|' '{ print \$$snap_id_col_index }' | tr -d '[:space:]*' | awk '{ print \">>>\" \$1 \"<<<\" }'");
    if ($output =~ />>>(?<snap_number>\d+)<<</) {
        return $+{snap_number};
    }
    die "Could not get last snapshot number, got following output:\n$output";
}

sub post_fail_hook {
    my ($self) = shift;
    return if get_var('NOLOGS');
    select_console('log-console');
    $self->SUPER::post_fail_hook;

    upload_logs('/var/log/snapper.log');
}

1;
