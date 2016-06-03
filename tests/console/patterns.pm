# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;
use utils;

sub run() {
    my $self = shift;
    select_console 'root-console';

    # System roles are defined in config.xml.
    # Currently the role 'kvm host' defines kvm_server as an additional pattern.
    my $pattern_name = 'kvm_server';

    # List the installed patterns and grep for $pattern_name as defined above.
    # grep's exit status will be 1 if it is not found and therefore
    # assert_script_run() will fail.
    assert_script_run("zypper patterns -i | grep $pattern_name");
}

1;
# vim: set sw=4 et:
