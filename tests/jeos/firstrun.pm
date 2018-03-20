# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
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
use version_utils 'is_sle';
use utils 'assert_screen_with_soft_timeout';

sub select_locale {
    assert_screen 'jeos-locale', 300;
    my $lang = get_var('INSTLANG', 'us');
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

sub run {
    select_locale;
    accept_license if is_sle;
    select_keyboard;

    assert_screen 'jeos-timezone';    # timzezone window, continue with selected timezone
    send_key 'ret';

    assert_screen 'jeos-root-password';    # set root password
    type_password;
    send_key 'ret';

    assert_screen 'jeos-confirm-root-password';    # confirm root password
    type_password;
    send_key 'ret';

    if (is_sle) {
        assert_screen 'jeos-please-register';
        send_key 'ret';
    }

    # Our current Hyper-V host and it's spindles are quite slow. Especially
    # when there are more jobs running concurrently. We need to wait for
    # various disk optimizations and snapshot enablement to land.
    # Meltdown/Spectre mitigations makes this even worse.
    assert_screen_with_soft_timeout('linux-login', timeout => 1000, soft_timeout => 300, bugref => 'bsc#1077007');

    select_console 'root-console';

    assert_script_run "useradd -m $username -c '$realname'";    # create user account
    my $str = time;
    script_run "passwd $username; echo $str-\$?- > /dev/$serialdev", 0;    # set user's password
    assert_screen 'passwd-prompt';
    type_password;
    send_key 'ret';
    assert_screen 'passwd-retype-prompt';
    type_password;
    send_key 'ret';
    my $ret = wait_serial "$str-\\d+-", 10;
    die "passwd failed" unless (defined $ret && $ret =~ /$str-0-/);
}

sub test_flags {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
