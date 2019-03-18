# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: List all guests so they're running
# Maintainer: Jan Baier <jbaier@suse.cz>

use base 'xen';

use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;

    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "Listing $guest guest";
        assert_script_run "virsh list --all | grep $guest";
    }
}

1;
