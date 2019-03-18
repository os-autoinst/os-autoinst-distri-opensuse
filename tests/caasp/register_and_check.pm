# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Register system and check if registration was succesful
#  Can be also registered during installation
# Maintainer: Martin Kravec <mkravec@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;

sub run {
    my $regcode = get_var 'REGCODE';
    if (check_var('REGISTER', 'suseconnect')) {
        assert_script_run "SUSEConnect --regcode $regcode";
    }

    # Check that registration was succeeded
    assert_script_run 'SUSEConnect --status-text | tee /dev/tty | grep -q "Status: ACTIVE"';
    assert_script_run 'test -f /etc/zypp/credentials.d/SCCcredentials';
}

1;
