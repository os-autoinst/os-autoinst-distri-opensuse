# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: check that command-not-found works as intended
# - as a normal user, check that command-not-found works
# - if in textmode or on SLE-15+, prepare the systembefore executing the command
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base "consoletest";
use testapi;
use strict;
use warnings;
use utils;
use version_utils 'is_sle';
use registration qw(add_suseconnect_product remove_suseconnect_product);

# test for regression of bug http://bugzilla.suse.com/show_bug.cgi?id=952496
sub run {
    my ($self) = @_;
    my $not_installed_pkg = 'iftop';

    select_console 'root-console';
    zypper_call("rm $not_installed_pkg") if (script_run("which $not_installed_pkg") == 0);
    zypper_call('in command-not-found') if (check_var('DESKTOP', 'textmode'));    # command-not-found is part of the enhanced_base pattern, missing in textmode

    # select user-console; for one we want to be sure cnf works for a user, 2nd assert_script_run does not work in root-console
    select_console 'user-console';

    save_screenshot;
    assert_script_run(qq{echo "\$(cnf $not_installed_pkg 2>&1 | tee /dev/stderr)" | grep -q "zypper install $not_installed_pkg"});
    save_screenshot;

    select_console 'root-console';
    zypper_call "in $not_installed_pkg";
    zypper_call "rm $not_installed_pkg";
    select_console 'user-console';

    if (is_sle('15+')) {
        # test for https://fate.suse.com/323424 if cnf works for non-registered modules
        $not_installed_pkg = 'wireshark';    # wireshark is in desktop module which is not registered here
        if (script_run(qq{echo "\$(cnf $not_installed_pkg 2>&1 | tee /dev/stderr)" | grep -q "zypper install $not_installed_pkg"}) != 0) {
            record_soft_failure "https://fate.suse.com/323424 - cnf doesn't cover non-registered modules";
        }
    }
}

1;
