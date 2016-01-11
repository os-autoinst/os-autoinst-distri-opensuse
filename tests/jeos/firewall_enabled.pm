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
    my $check_state    = "systemctl show --no-pager SuSEfirewall2 | grep ActiveState | cut -d'=' -f2";
    my $check_substate = "systemctl show --no-pager SuSEfirewall2 | grep SubState | cut -d'=' -f2";
    my $check_ssh_port = "grep -E 'FW_SERVICES_EXT_TCP=|FW_CONFIGURATIONS_EXT=' /etc/sysconfig/SuSEfirewall2 | cut -d'\"' -f2 | grep -v '^\$'";

    validate_script_output $check_state,    sub { /^active$/ };
    validate_script_output $check_substate, sub { /^exited$/ };
    validate_script_output $check_ssh_port, sub { /^sshd|22$/ };
}

sub test_flags() {
    return {important => 1};
}

1;
