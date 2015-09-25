use base "opensusebasetest";
use strict;
use testapi;
use ttylogin;

sub run() {
    my $self = shift;

    assert_screen 'jeos-license'; # License time
    send_key 'ret';
    assert_screen 'jeos-doyouaccept';
    send_key 'ret';

    assert_screen 'jeos-keylayout', 200; # Language picker

    my $lang = get_var("INSTLANG", 'us');
    send_key_until_needlematch "jeos-lang-$lang", 'u'; # Press u until it gets to the $lang menu option
    send_key 'ret';
    send_key_until_needlematch "jeos-system-locale-$lang", 'e', 50;
    send_key 'ret';

    assert_screen 'jeos-timezone';  # timzezone window, continue with selected timezone
    send_key "ret";

    assert_screen 'jeos-root-password'; # set root password
    type_password;
    send_key 'ret';

    assert_screen 'jeos-confirm-root-password'; # confirm root password
    type_password;
    send_key 'ret';

    assert_screen 'jeos-please-register';
    send_key 'ret';

    assert_screen 'linux-login';

    ttylogin 4, 'root';

    assert_script_run "useradd -m $username"; # create bernhard account
    my $str = time;
    script_run "passwd $username; echo $str-\$?- > /dev/$serialdev"; # set bernhards password
    type_password;
    send_key 'ret';
    type_password;
    send_key 'ret';
    my $ret = wait_serial "$str-\\d+-", 10;
    die "passwd failed" unless (defined $ret && $ret =~ /$str-0-/);
}

sub test_flags() {
    return { 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
