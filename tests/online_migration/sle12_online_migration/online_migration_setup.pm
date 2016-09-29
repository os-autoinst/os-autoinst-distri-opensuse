# SLE12 online migration tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Add sle12 online migration testsuite
#    Fixes follow up by the comments
#
#    Apply fully patch system function
#
#    Fix typo and remove redundant comment
#
#    Remove a unnecessary line
# G-Maintainer: mitiao <mitiao@gmail.com>

use base "consoletest";
use strict;
use testapi;
use utils;

sub run() {
    my $self = shift;

    # if source system is minimal installation then boot to textmode
    wait_boot textmode => !is_desktop_installed;
    select_console 'root-console';

    # stop packagekit service
    script_run "systemctl mask packagekit.service";
    script_run "systemctl stop packagekit.service";

    type_string "chown $username /dev/$serialdev\n";

    # enable Y2DEBUG all time
    type_string "echo 'export Y2DEBUG=1' >> /etc/bash.bashrc.local\n";
    script_run "source /etc/bash.bashrc.local";

    save_screenshot;
}

1;
# vim: set sw=4 et:
