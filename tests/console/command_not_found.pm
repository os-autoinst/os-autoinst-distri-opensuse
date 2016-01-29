# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use testapi;

# test for regression of bug http://bugzilla.suse.com/show_bug.cgi?id=952496
sub run() {
    # permissions don't matter

    my $not_installed_pkg = "xosview";
    assert_script_run("cnf $not_installed_pkg 2>&1 | tee /dev/stderr | grep -q \"zypper install $not_installed_pkg\"");
    save_screenshot;
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
