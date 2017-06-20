package btrfs_test;
use base 'consoletest';

use strict;
use testapi;

=head2 unpartitioned_disk_in_bash

Choose the disk without a partition table for btrfs experiments.
Defines the variable C<$disk> in a bash session.
=cut
sub set_unpartitioned_disk_in_bash {
    my $vd = 'vd';    # KVM
    if (check_var('VIRSH_VMM_FAMILY', 'xen')) {
        $vd = 'xvd';
    }
    elsif (check_var('VIRSH_VMM_FAMILY', 'hyperv') or check_var('VIRSH_VMM_FAMILY', 'vmware')) {
        $vd = 'sd';
    }
    assert_script_run 'parted --script --machine -l';
    assert_script_run 'disk=${disk:-$(parted --script --machine -l |& sed -n \'s@^\(/dev/' . $vd . '[ab]\):.*unknown.*$@\1@p\')}';
    assert_script_run 'echo $disk';
}

sub cleanup_partition_table {
    assert_script_run 'wipefs --force --all $disk';
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
        assert_screen('emergency-shell', 10);
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
        assert_screen 'tty2-selected';
        console('root-console')->reset;
        select_console 'root-console';
    }
    else {
        die 'DBus service ought not to be active (but is)';
    }
}

sub post_fail_hook {
    upload_logs('/var/log/snapper.log');
}

1;
# vim: set sw=4 et:
