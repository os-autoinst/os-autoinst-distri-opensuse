# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: Clear unneed repos before updating for Staging Project
# Maintainer: Max Lin <mlin@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';
    # packagekit service may block zypper when operate on repos
    quit_packagekit;

    # remove Factory repos
    my $repos_folder = '/etc/zypp/repos.d';
    zypper_call 'lr -d', exitcode => [0, 6];
    assert_script_run(
"find $repos_folder/ -name \\*.repo -type f -exec grep -Eq 'baseurl=(http|https)://download.opensuse.org/' {} \\; -delete && echo 'unneed_repos_removed' > /dev/$serialdev",
        15
    );
    zypper_call 'lr -d', exitcode => [0, 6];
    save_screenshot;    # take a screenshot after repos removed

    if (get_var("STAGING")) {
        # With FATE#320494 the local repository would be disabled after installation
        # in Staging, enable it here.
        clear_console;
        assert_script_run("grep -rlE 'baseurl=cd:/(//)?\\?devices' $repos_folder | xargs --no-run-if-empty sed -i 's/^enabled=0/enabled=1/g'");
        zypper_call 'lr -d', exitcode => [0, 6];
        save_screenshot;    # take a screenshot after repo enabled
    }
}

1;
