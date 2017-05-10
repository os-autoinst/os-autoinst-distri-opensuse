# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Enable HPC repo through yast
# Maintainer: mgriessmeier <mgriessmeier@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;
use lockapi;

sub run() {
    select_console 'root-console';

    # disable packagekitd
    pkcon_quit();

    my $repo     = get_required_var('HPC_REPO');
    my $reponame = get_required_var('HPC_REPONAME');
    zypper_call("ar -f $repo $reponame");
    assert_script_run "zypper lr | grep $reponame";

    zypper_call("--gpg-auto-import-keys ref");
    zypper_call 'up';
}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
