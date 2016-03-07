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

    $self->export_logs;

    save_screenshot;
}

sub post_run_hook {
    my ($self) = @_;

    assert_screen('generic-desktop');
}

1;
# vim: set sw=4 et:
