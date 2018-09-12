# Base for YaST tests.  Switches to text console 2 and uploady y2logs

package console_yasttest;
use base 'y2logsstep';
use strict;
use testapi;

sub change_service_configuration {
    my ($self, %args) = @_;
    my $after_writing_ref = $args{after_writing};
    my $after_reboot_ref  = $args{after_reboot};

    assert_screen 'yast2_ncurses_service_start_widget';
    change_service_configuration_step('after_writing_conf', $after_writing_ref) if $after_writing_ref;
    change_service_configuration_step('after_reboot',       $after_reboot_ref)  if $after_reboot_ref;
}

sub change_service_configuration_step {
    my ($step_name, $step_conf_ref) = @_;
    my ($action)         = keys %$step_conf_ref;
    my ($shortcut)       = values %$step_conf_ref;
    my $needle_selection = 'yast2_ncurses_service_' . $action . '_' . $step_name;
    my $needle_check     = 'yast2_ncurses_service_check_' . $action . '_' . $step_name;

    send_key $shortcut;
    send_key 'end';
    send_key_until_needlematch $needle_selection, 'up', 5, 1;
    send_key 'ret';
    assert_screen $needle_check;
}

sub post_fail_hook {
    my $self = shift;

    select_console 'log-console';
    save_screenshot;

    upload_logs('/var/log/zypper.log');
    $self->remount_tmp_if_ro;
    $self->save_upload_y2logs;
    $self->save_system_logs;
    $self->save_strace_gdb_output('yast');
}

sub post_run_hook {
    my ($self) = @_;

    $self->clear_and_verify_console;
}

1;
