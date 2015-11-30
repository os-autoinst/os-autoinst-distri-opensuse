package x11test;
use base "opensusebasetest";

# Base class for all openSUSE tests

use strict;
use testapi;

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

    save_screenshot;
}

sub post_run_hook {
    my ($self) = @_;

    assert_screen('generic-desktop');
}

sub check_kwallet {
    my ($self, $enable) = @_;
    # enable = 1 as enable kwallet, archive kwallet enabling process
    # enable = 0 as disable kwallet, just close the popup dialog
    $enable //= 0;    # default is disable kwallet

    if (check_screen("kwallet-wizard", 5)) {
        if ($enable) {
            send_key "alt-n";
            sleep 2;
            send_key "spc";
            sleep 2;
            send_key "down";    # use traditional way
            type_password;
            send_key "tab";
            sleep 1;
            type_password;
            send_key "alt-f";

            assert_screen "kwallet-opening", 5;
            type_password;
            send_key "ret", 1;
        }
        else {
            send_key "alt-f4", 1;
        }
    }
}

1;
# vim: set sw=4 et:
