# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check that there is no perl-Bootloader component in installed system (#1571)
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: fate#317701 poo#11436

use base "consoletest";
use strict;
use testapi;

sub run() {
    select_console('user-console');
    assert_script_run('! rpm -qi perl-Bootloader-YAML');
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
