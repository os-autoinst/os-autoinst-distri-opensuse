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

# poo#11798
sub run() {
    select_console 'root-console';

    my $acpi = "/sys/firmware/acpi";
    my $dt   = "/sys/firmware/devicetree";

    if (get_var("EXTRABOOTPARAMS", "") =~ /acpi=force/) {
        script_run "ls $acpi/*";
        assert_script_run "! ls $dt/*";
    }
    else {
        assert_script_run "ls $dt/*";
        assert_script_run "! ls $acpi/*";
    }
}

sub test_flags {
    return {important => 1};
}

1;
# vim: set sw=4 et:
