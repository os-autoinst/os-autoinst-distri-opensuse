package btrfs_test;
use base 'consoletest';

use strict;
use testapi;
use utils 'get_root_console_tty';
use serial_terminal 'login';

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
    # serial console prints text style as ascii chars in PS1 by default.
    my $escseq = '[\]\[\(\)\e\d\w\s]*';

    my $rescue_service_config_path   = "/usr/lib/systemd/system/rescue.service";
    my $rescue_service_override_path = "/etc/systemd/system/rescue.service";

    return unless script_run('! systemctl is-active dbus');
    if (!serial_terminal::select_virtio_console()) {
        die 'Selection of virtio console failed.';
    }

    # Replace StandardInput in rescue.service file and add TTYPath.
    assert_script_run "cp $rescue_service_config_path $rescue_service_override_path";
    assert_script_run "sed -i 's@^StandardInput=.*\$\@StandardInput=tty\\nTTYPath='\$(tty)'\@g' '$rescue_service_override_path'";

    assert_script_run "systemctl reenable rescue";
    type_string "systemctl rescue";
    wait_serial "systemctl rescue";
    type_string "\n";
    wait_serial ".*or press Control-D to continue.*:";
    type_password;
    type_string "\n";

    wait_serial "$escseq:~ #$escseq";
    type_string 'PS1="# "; export TERM=dumb; stty cols 2048';
    wait_serial 'PS1="# "; export TERM=dumb; stty cols 2048';
    type_string "\n";
    wait_serial "# ";
    $self->set_standard_prompt('root');
}

=head2 snapper_nodbus_restore

Restore environment to default.target. Console root-console has to be reset, because
move from rescue to default target, logs us out. Die if DBus is active at this point,
it means that DBus got activated somehow, thus invalidated `snapper --no-dbus` testing.
=cut
sub snapper_nodbus_restore {

    if (script_run '! systemctl is-active dbus') {
        die 'DBus service ought not to be active (but is)';
    }
    type_string "tty";
    wait_serial "tty";
    type_string "\n";
    if (!wait_serial '\/dev\/hvc\d+') {
        die 'This subroutine needs a virtio console being selected.';
    }
    wait_serial "# ";
    type_string "systemctl default";
    wait_serial "systemctl default";
    type_string "\n";
    login "root", "# ";
    assert_script_run "systemctl revert rescue";
    console("root-console")->reset;
    select_console "root-console";
}

sub post_fail_hook {
    my ($self) = shift;
    select_console('log-console');
    $self->SUPER::post_fail_hook;

    upload_logs('/var/log/snapper.log');
    $self->export_logs;
}

1;
