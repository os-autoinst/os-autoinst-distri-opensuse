package x11test;
use base "opensusebasetest";

# Base class for all openSUSE tests

use testapi;

sub post_fail_hook() {
    my $self = shift;

    if ( check_var("DESKTOP", "kde") ) {
        send_key "ctrl-alt-f2";
        assert_screen("text-login", 10);
        type_string "root\n";
        sleep 2;
        type_password;
        type_string "\n";
        sleep 1;
        save_screenshot;

        my $fn = '/tmp/kde4_configs.tar.bz2';
        my $cmd = sprintf 'tar cjf %s /home/%s/.kde4/share/config/*rc', $fn, $username;
        type_string "$cmd\n";
        upload_logs $fn;
        save_screenshot;
    }
}

sub post_run_hook {
    my ($self) = @_;

    assert_screen('generic-desktop');
}

1;
# vim: set sw=4 et:
