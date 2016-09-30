# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Add test for fate#317701 - Do not use perl-bootloader in yast2-bootloader (#1571)
#    On SLE 12-SP2 or greater check that no perl-Bootloader-YAML is present in the
#    installed system as described as a test case in fate#317701.
#
#    Locally verified on TW where it fails because perl-Bootloader-YAML is present.
#
#    Verification run: http://lord.arch/tests/2057
#
#    Related progress issue: https://progress.opensuse.org/issues/11436
# G-Maintainer: Oliver Kurz <okurz@suse.de>

use base "consoletest";
use strict;
use testapi;

# Check that there is no perl-Bootloader component in installed system
# (fate#317701)
sub run() {
    select_console('user-console');
    assert_script_run('! rpm -qi perl-Bootloader-YAML');
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
