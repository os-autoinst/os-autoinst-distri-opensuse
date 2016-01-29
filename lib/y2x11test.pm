package y2x11test;
use base "opensusebasetest";

# Base class for all openSUSE tests

use testapi;

sub launch_yast2_module_x11 {
    my ($self, $module) = @_;
    $module //= '';

    x11_start_program("xdg-su -c '/sbin/yast2 $module'");
    if (check_screen "root-auth-dialog") {
        if ($password) {
            type_password;
            send_key "ret", 1;
        }
    }
}

sub save_upload_y2logs() {
    my $self = shift;

    my $fn = sprintf '/tmp/y2logs-%s.tar.bz2', ref $self;
    assert_script_run "save_y2logs $fn";
    upload_logs $fn;
}

sub post_fail_hook() {
    my $self = shift;

    select_console 'root-console';

    my $fn = sprintf '/tmp/XSE-%s', ref $self;
    type_string "cat /home/*/.xsession-errors* > $fn\n";
    upload_logs $fn;

    $self->save_upload_y2logs;

    save_screenshot;
}

sub post_run_hook {
    my ($self) = @_;

    assert_screen('generic-desktop');
}

1;
# vim: set sw=4 et:
