# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Clear unneed repos before updating for Staging Project
# Maintainer: Max Lin <mlin@suse.com>

use base "consoletest";
use strict;
use testapi;
use utils;

sub run {
    select_console 'root-console';
    # packagekit service may block zypper when operate on repos
    pkcon_quit;

    # remove Factory repos
    my $repos_folder = '/etc/zypp/repos.d';
    script_run("zypper lr -d");
    assert_script_run(
"find $repos_folder/*.repo -type f -exec grep -q 'baseurl=http://download.opensuse.org/' {} \\; -delete && echo 'unneed_repos_removed' > /dev/$serialdev",
        15
    );
    script_run("zypper lr -d");
    save_screenshot;    # take a screenshot after repos removed

    if (get_var("STAGING")) {
        # With FATE#320494 the local repository would be disabled after installation
        # in Staging, enable it here.
        clear_console;
        assert_script_run("grep -rlE 'baseurl=cd:/(//)?\\?devices' $repos_folder | xargs --no-run-if-empty sed -i 's/^enabled=0/enabled=1/g'");
        script_run("zypper lr -d");
        save_screenshot;    # take a screenshot after repo enabled
    }
}

1;
