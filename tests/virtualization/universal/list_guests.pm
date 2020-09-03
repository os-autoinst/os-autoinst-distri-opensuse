#Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: List every guest and ensure they are online
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base "consoletest";
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;

    ensure_default_net_is_active();

    assert_script_run "virsh list --all", 90;

    # Ensure all guests are online and have network connectivity
    foreach my $guest (keys %virt_autotest::common::guests) {
        # This should fix some common issues on the guests. If the procedure fails we still want to go on
        eval {
            ensure_online($guest);
        } or do {
            my $err = $@;
            record_info("$guest failure: $err");
        };
    }
}

1;

