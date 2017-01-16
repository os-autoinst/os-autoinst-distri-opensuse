# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add test for command-not-found tool
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base "consoletest";
use testapi;
use strict;

# test for regression of bug http://bugzilla.suse.com/show_bug.cgi?id=952496
sub run() {
    # select user-console; for one we want to be sure cnf works for a user, 2nd assert_script_run does not work in root-console
    select_console 'user-console';

    if (check_var('DESKTOP', 'textmode')) {    # command-not-found is part of the enhanced_base pattern, missing in textmode
        assert_script_sudo "zypper -n in command-not-found";
    }

    my $not_installed_pkg = "xosview";
    assert_script_run("echo \"\$(cnf $not_installed_pkg 2>&1 | tee /dev/stderr)\" | grep -q \"zypper install $not_installed_pkg\"");
    save_screenshot;
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
