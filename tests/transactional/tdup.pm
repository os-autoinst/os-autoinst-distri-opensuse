# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: To a transactional-update dup and reboot the node
# Maintainer: Richard Brown <rbrown@suse.com>

use base "opensusebasetest";
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

    trup_call 'dup';

    check_reboot_changes;

}

1;
