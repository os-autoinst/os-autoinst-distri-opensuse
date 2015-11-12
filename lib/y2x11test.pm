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
    type_string "save_y2logs /tmp/y2logs.tar.bz2; echo y2logs-saved-\$? > /dev/$serialdev\n";
    my $ret = wait_serial 'y2logs-saved-\d+';
    die "failed to save y2logs" unless (defined $ret && $ret =~ /y2logs-saved-0/);
    upload_logs "/tmp/y2logs.tar.bz2";
}

sub post_fail_hook() {
    my $self = shift;

    send_key "ctrl-alt-f2";
    assert_screen("text-login", 10);
    type_string "root\n";
    sleep 2;
    type_password;
    type_string "\n";
    sleep 1;
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
