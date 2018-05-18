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
use strict;
use warnings;
use testapi;
use version_utils 'is_sle';

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

1;
