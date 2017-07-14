# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test all officially SLE supported shells
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "consoletest";
use strict;
use testapi;
use utils 'zypper_call';

sub run() {
    select_console 'root-console';
    zypper_call 'in ksh tcsh zsh';
    select_console 'user-console';
    assert_script_run 'ksh -c "print hello" | grep hello';
    assert_script_run 'tcsh -c "printf \'hello\n\'" | grep hello';
    assert_script_run 'csh -c "printf \'hello\n\'" | grep hello';
    assert_script_run 'zsh -c "echo hello" | grep hello';
    assert_script_run 'sh -c "echo hello" | grep hello';
}

1;
