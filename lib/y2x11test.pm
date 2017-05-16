package y2x11test;
use base "opensusebasetest";
use strict;

use testapi;

sub launch_yast2_module_x11 {
    my ($self, $module, %args) = @_;
    $module //= '';
    my $tag = $args{tag} // "yast2-$module-ui";
    my $timeout = $args{timeout} // 30;

    x11_start_program("xdg-su -c '/sbin/yast2 $module'");
    assert_screen ['root-auth-dialog', $tag], $timeout;
    if (match_has_tag 'root-auth-dialog') {
        if ($password) {
            type_password;
            send_key 'ret';
        }
        assert_screen $tag, $timeout;
    }
}

sub post_fail_hook() {
    my ($self) = shift;
    $self->export_logs;
    save_screenshot;
}

sub post_run_hook {
    assert_screen('generic-desktop');
}

1;
# vim: set sw=4 et:
