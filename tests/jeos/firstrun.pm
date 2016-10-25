# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure JeOS
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

sub select_locale {
    assert_screen 'jeos-locale', 120;
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

    # Without this login name and password won't get to the system. They get
    # lost somewhere. Applies for all systems installed via svirt, but zKVM.
    if (check_var('BACKEND', 'svirt') and !check_var('ARCH', 's390x')) {
        wait_idle;
    }

    select_console 'root-console';

    assert_script_run "useradd -m $username -c '$realname'";    # create user account
    my $str = time;
    script_run "passwd $username; echo $str-\$?- > /dev/$serialdev", 0;    # set user's password
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
