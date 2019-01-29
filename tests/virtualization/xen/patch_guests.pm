# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Apply patches to the all of our guests
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use warnings;
use strict;
use testapi;
use qam 'ssh_add_test_repositories';
use utils 'ssh_fully_patch_system';
use xen;

sub run {
    my ($self) = @_;
    my $domain = get_required_var('QAM_XEN_DOMAIN');

    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "Patching $guest";
        ssh_add_test_repositories "$guest.$domain";
        ssh_fully_patch_system "$guest.$domain";
    }
}

sub test_flags {
    return {fatal => 1};
}

1;

