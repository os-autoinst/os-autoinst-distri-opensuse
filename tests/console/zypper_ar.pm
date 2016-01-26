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

sub run() {
    select_console 'root-console';

    # non-NET installs have only milestone repo, which might be incompatible.
    my $repourl = 'http://' . get_var("SUSEMIRROR");
    unless (get_var("FULLURL")) {
        $repourl = $repourl . "/repo/oss";
    }
    assert_script_run "zypper ar -c $repourl Factory";
    script_run "zypper lr", 0;
    assert_screen "addn-repos-listed";
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
