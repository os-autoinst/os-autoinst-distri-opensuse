# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check for password security
# Maintainer: Oliver Kurz <okurz@suse.de>

package installation_user_settings;
use parent Exporter;
use strict;
use warnings;
use testapi;
use version_utils 'is_sle';
use utils 'type_string_slow';

our @EXPORT = qw(type_password_and_verification await_password_check enter_userinfo enter_rootinfo);

sub type_password_and_verification {
    for (1 .. 2) {
        wait_screen_change { type_string "$password\t" };
    }
}

sub await_password_check {
    # PW too easy (cracklib)
    # bsc#937012 is resolved in > SLE 12, skip if VERSION=12
    return if (is_sle('=12') && check_var('ARCH', 's390x'));
    assert_screen 'inst-userpasswdtoosimple';
    send_key 'ret';

}

sub enter_userinfo {
    my (%args) = @_;
    $args{username} //= $realname;
    send_key 'alt-f';    # Select full name text field
    wait_screen_change { $args{retry} ? type_string_slow $args{username} : type_string $args{username} };
    send_key 'tab';      # Select password field
    send_key 'tab';
    type_password_and_verification;
}

sub enter_rootinfo {
    assert_screen "inst-rootpassword";
    type_password_and_verification;
    assert_screen "rootpassword-typed";
    assert_and_click 'next-button';
    await_password_check;
}

1;
