# Feature tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case #1480023 : [316585] Drop suseRegister

use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    select_console 'root-console';

    #Check SUSEConnect is installed
    assert_script_run('rpm -q SUSEConnect');
    save_screenshot;

    #Check suseRegister is not installed
    assert_script_run('! rpm -q suseRegister');
    save_screenshot;
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
