package y2x11test;
use base "opensusebasetest";
use strict;

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
    assert_script_run "save_y2logs /tmp/y2logs.tar.bz2";
    upload_logs "/tmp/y2logs.tar.bz2";
}

sub post_fail_hook() {
    my $self = shift;

    select_console 'root-console';
    save_screenshot;

    if (check_var("DESKTOP", "kde")) {
        if (get_var('PLASMA5')) {
            my $fn = '/tmp/plasma5_configs.tar.bz2';
            my $cmd = sprintf 'tar cjf %s /home/%s/.config/*rc', $fn, $username;
            type_string "$cmd\n";
            upload_logs $fn;
        }
        else {
            my $fn = '/tmp/kde4_configs.tar.bz2';
            my $cmd = sprintf 'tar cjf %s /home/%s/.kde4/share/config/*rc', $fn, $username;
            type_string "$cmd\n";
            upload_logs $fn;
        }
        save_screenshot;
    }

    type_string "cat /home/*/.xsession-errors* > /tmp/XSE\n";
    upload_logs "/tmp/XSE";

    save_upload_y2logs;

    save_screenshot;
}

sub post_run_hook {
    my ($self) = @_;

    assert_screen('generic-desktop');
}

1;
# vim: set sw=4 et:
