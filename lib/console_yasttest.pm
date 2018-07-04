# Base for YaST tests.  Switches to text console 2 and uploady y2logs

package console_yasttest;
use base 'y2logsstep';
use strict;

use testapi;

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
