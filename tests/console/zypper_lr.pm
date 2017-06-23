# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Validate SLE zypper repositories
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "consoletest";
use strict;
use testapi;
use utils;

sub run() {
    # ZYPPER_LR is needed for inconsistent migration, test would fail looking for deactivated addon
    set_var 'ZYPPER_LR', 1;
    select_console 'root-console';
    validate_repos;
}

1;
# vim: set sw=4 et:
