package btrfs_test;
use base 'consoletest';

use strict;
use warnings;
use testapi;
use utils 'get_root_console_tty';

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
        assert_screen('emergency-shell', 120);
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
    if (script_run('systemctl is-active dbus')) {
        script_run('systemctl default', 0);
        my $tty = get_root_console_tty;
        assert_screen "tty$tty-selected";
        reset_consoles;
        select_console 'root-console';
    }
    else {
        die 'DBus service ought not to be active (but is)';
    }
}

sub post_fail_hook {
    my ($self) = shift;
    select_console('log-console');
    $self->SUPER::post_fail_hook;

    upload_logs('/var/log/snapper.log');
    $self->export_logs;
}

1;
