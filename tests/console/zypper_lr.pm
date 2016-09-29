# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: harmorize zypper_ref between SLE and openSUSE
# G-Maintainer: Max Lin <mlin@suse.com>

use base "consoletest";
use strict;
use testapi;
use utils;

sub run() {
    select_console 'root-console';
    validate_repos;
}

1;
# vim: set sw=4 et:
