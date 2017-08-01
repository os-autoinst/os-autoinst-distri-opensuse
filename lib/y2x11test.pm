package y2x11test;
use base "opensusebasetest";
use strict;

use testapi;

sub launch_yast2_module_x11 {
    my ($self, $module) = @_;
    $module //= '';

    x11_start_program("xdg-su -c '/sbin/yast2 $module'");
    if (check_screen "root-auth-dialog") {
        if ($password) {
            type_password;
            wait_screen_change { send_key "ret" };
        }
    }
}

sub post_fail_hook {
    my ($self) = shift;
    $self->export_logs;
    save_screenshot;
}

sub post_run_hook {
    assert_screen('generic-desktop');
}

1;
# vim: set sw=4 et:
