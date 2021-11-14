# SUSE's openQA tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check for password security
# Maintainer: Oliver Kurz <okurz@suse.de>

package installation_user_settings;
use parent Exporter;
use strict;
use warnings;
use testapi;
use Utils::Architectures;
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
    return if (is_sle('=12') && is_s390x);
    assert_screen('inst-userpasswdtoosimple', (check_var('BACKEND', 'pvm_hmc')) ? 60 : 30);
    send_key 'ret';

}

sub enter_userinfo {
    my (%args) = @_;
    $args{username} //= $realname;
    $args{max_interval} //= undef;
    send_key 'alt-f';    # Select full name text field
    wait_screen_change { type_string($args{username}, max_interval => $args{max_interval}); };
    send_key 'tab';    # Select password field
    send_key 'tab';
    type_password_and_verification;
}

sub enter_rootinfo {
    assert_screen "inst-rootpassword";
    type_password_and_verification;
    assert_screen "rootpassword-typed";
    send_key $cmd{next};
    await_password_check;
}

1;
