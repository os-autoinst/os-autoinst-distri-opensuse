# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check for any orphaned packages. There should be none in fully
#   supported systems
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: poo#19606

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use version_utils 'is_upgrade';
use services::orphaned_packages_check;

sub run {
    select_console 'root-console';
    services::orphaned_packages_check::orphaned_packages_list;
}

1;
