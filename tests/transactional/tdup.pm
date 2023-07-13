# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: To a transactional-update dup and reboot the node
# Maintainer: Richard Brown <rbrown@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use transactional;
use utils;

sub run {
    select_console 'root-console';

    zypper_call 'mr --all --disable';

    my $defaultrepo;
    if (get_var('SUSEMIRROR')) {
        $defaultrepo = "http://" . get_var("SUSEMIRROR");
    }
    else {
        die "No SUSEMIRROR variable set";
    }

    my $nr = 1;
    foreach my $r (split(/,/, get_var('ZDUPREPOS', $defaultrepo))) {
        zypper_call("--no-gpg-checks ar \"$r\" repo$nr");
        $nr++;
    }

    zypper_call '--gpg-auto-import-keys ref';

    trup_call 'dup', timeout => 600;

    check_reboot_changes;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
