# Base for YaST tests.  Switches to text console 2 and uploady y2logs

package console_yasttest;
use base 'y2logsstep';
use strict;
use warnings;
use testapi;
use utils 'show_tasks_in_blocked_state';

sub post_fail_hook {
    my $self = shift;

    my $defer_blocked_task_info = testapi::is_serial_terminal();
    show_tasks_in_blocked_state unless ($defer_blocked_task_info);

    select_console 'log-console';
    save_screenshot;

    show_tasks_in_blocked_state if ($defer_blocked_task_info);

    $self->remount_tmp_if_ro;
    $self->save_upload_y2logs;
    upload_logs('/var/log/zypper.log');
    $self->save_system_logs;
    $self->save_strace_gdb_output('yast');
}

sub post_run_hook {
    my ($self) = @_;

    $self->clear_and_verify_console;
}

sub test_flags {
    return {fatal => 0};
}

1;
