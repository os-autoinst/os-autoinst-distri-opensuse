# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
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

sub type_password_and_verification {
    for (1 .. 2) {
        assert_screen_change { type_string "$password\t" };
    }
}

sub await_password_check {
    # PW too easy (cracklib)
    if (check_var('LIVECD', 1)) {
        record_soft_failure 'boo#1013206' unless check_screen 'inst-userpasswdtoosimple';
    }
    else {
        # bsc#937012 is resolved in > SLE 12
        assert_screen 'inst-userpasswdtoosimple' unless (check_var('VERSION', '12') && check_var('ARCH', 's390x'));
    }
    send_key 'ret' if match_has_tag 'inst-userpasswdtoosimple';
}

1;
