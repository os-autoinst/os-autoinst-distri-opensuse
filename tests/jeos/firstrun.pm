use base "opensusebasetest";
use strict;
use testapi;

sub select_locale {
    my $lang = get_var("INSTLANG", 'us');
    send_key_until_needlematch "jeos-system-locale-$lang", 'e', 50;
    send_key 'ret';
}
sub accept_license {
    assert_screen 'jeos-license', 60;
    send_key 'ret';
    assert_screen 'jeos-doyouaccept';
    send_key 'ret';
}
sub select_keyboard {
    assert_screen 'jeos-keylayout', 200;
    send_key 'ret';
}

sub run() {
    my $self = shift;

    if (check_var('VERSION', '12')) {
        # JeOS-SLE
        accept_license;
        select_keyboard;
        select_locale;
    }
    else {
        # JeOS-SLE-SP1, Leap 42.1
        select_locale;
        accept_license if check_var('DISTRI', 'sle');
        select_keyboard;
    }

    assert_screen 'jeos-timezone';    # timzezone window, continue with selected timezone
    send_key "ret";

    assert_screen 'jeos-root-password';    # set root password
    type_password;
    send_key 'ret';

    assert_screen 'jeos-confirm-root-password';    # confirm root password
    type_password;
    send_key 'ret';

    if (check_var('DISTRI', 'sle')) {
        assert_screen 'jeos-please-register';
        send_key 'ret';
    }

    assert_screen 'linux-login';

    select_console 'root-console';

    assert_script_run "useradd -m $username";    # create bernhard account
    my $str = time;
    script_run "passwd $username; echo $str-\$?- > /dev/$serialdev";    # set bernhards password
    type_password;
    send_key 'ret';
    type_password;
    send_key 'ret';
    my $ret = wait_serial "$str-\\d+-", 10;
    die "passwd failed" unless (defined $ret && $ret =~ /$str-0-/);
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
