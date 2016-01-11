# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    my $check_state    = "systemctl show --no-pager sshd | grep ActiveState | cut -d'=' -f2";
    my $check_substate = "systemctl show --no-pager sshd | grep SubState | cut -d'=' -f2";

    validate_script_output $check_state,    sub { m/^active$/ };
    validate_script_output $check_substate, sub { m/^running$/ };
}

sub test_flags() {
    return {important => 1};
}

1;
