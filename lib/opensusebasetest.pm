package opensusebasetest;
use base 'basetest';

use testapi qw(send_key assert_screen type_password);

# Base class for all openSUSE tests

sub clear_and_verify_console {
    my ($self) = @_;

    send_key "ctrl-l";
    assert_screen('cleared-console');

}

sub pass_disk_encrypt_check {
    my ($self) = @_;

    assert_screen("encrypted-disk-password-prompt");
    type_password;    # enter PW at boot
    send_key "ret";
}

sub post_run_hook {
    my ($self) = @_;
    # overloaded in x11 and console
}

1;
# vim: set sw=4 et:
