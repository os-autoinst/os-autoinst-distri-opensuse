# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install all packages available in certain repository
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>

use base "consoletest";
use strict;
use testapi;
use utils;

sub run {
    select_console('root-console');
    install_all_from_repo();
}

1;
