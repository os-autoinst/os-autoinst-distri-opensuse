# Base for YaST tests.  Switches to text console 2 and uploady y2logs

package console_yasttest;
use base 'y2logsstep';
use strict;
use testapi;

sub assert_service_widget {
    my ($self, %args) = @_;
    my $after_writing_conf = $args{after_writing_conf} || 'alt-f';
    my $after_reboot       = $args{after_reboot}       || 'alt-a';

    assert_screen 'yast2_ncurses_service_start_widget';
    send_key $after_writing_conf;
    send_key_until_needlematch 'yast2_ncurses_service_start_widget_start_after_conf', 'up';
    send_key 'ret';
    assert_screen 'yast2_ncurses_service_start_widget_check_start_after_conf';
    send_key $after_reboot;
    send_key_until_needlematch 'yast2_ncurses_service_start_widget_start_on_boot', 'up';
    send_key 'ret';
    assert_screen 'yast2_ncurses_service_start_widget_check_start_on_boot';
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
