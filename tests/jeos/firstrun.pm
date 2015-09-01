use base "opensusebasetest";
use strict;
use testapi;
use ttylogin;

sub run() {
    my $self = shift;

    assert_screen "jeos-grub2", 15;
    send_key 'ret'; # Press enter
    assert_screen 'jeos-keylayout'; # Language picker

    if (get_var("INSTLANG")) {
        my $lang = get_var("INSTLANG");
        send_key_until_needlematch "jeos-lang-$lang", 'u'; # Press u until it gets to the $lang menu option
        send_key 'ret';
        send_key_until_needlematch "jeos-system-locale-$lang", 'e', 50;
        send_key 'ret';
    } else {
        send_key_until_needlematch 'jeos-lang-us', 'u'; # Press u until it gets to the US menu option
        send_key 'ret';
        send_key_until_needlematch 'jeos-system-locale-us', 'e', 50;
        send_key 'ret';

    }
    assert_screen 'jeos-timezone';  # timzezone window, continue with selected timezone
    send_key "ret";
    assert_screen 'jeos-root-password'; # set root password
    type_password;
    send_key 'ret'; # Press enter, go to License
    assert_screen 'linux-login';
    send_key 'ctrl-alt-f4';
    assert_screen 'tty4-selected';
    assert_screen 'text-login';
    type_string "root\n";
    assert_screen 'password-prompt', 10;
    type_password;
    send_key 'ret';
    assert_screen 'jeos-license'; # License time
    send_key_until_needlematch 'jeos-license-end', 'pgdn'; # Might as well scroll to the bottom, somewhat redundant
    send_key 'q';   # quit license
    assert_screen 'jeos-doyouaccept';
    send_key 'y';   # acept license
    send_key 'ret';
    assert_screen 'jeos-firstrun-finished'; # Check the config made
    script_run "useradd -m $username"; # Make bernhard his account
    script_run "passwd $username"; # set bernhards password
    type_password;
    send_key 'ret';
    type_password;
    send_key 'ret';
}

sub test_flags() {
    return { 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
