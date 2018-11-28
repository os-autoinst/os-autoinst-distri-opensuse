# XEN regression tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Test if Dom0 metrics are visible to VM
# Maintainer: Jan Baier <jbaier@suse.cz>

use base 'xen';

use strict;
use testapi;
use utils;

sub run {
    my $self = shift;

    ## TODO:
    #    * start some systems in xl stack
    #    * install vhostmd package
    #    * add vhostmd devices into guests
    #    * install vm-dump-metrics package on the guest
    #    * check whether the data from host can be obtained
}

1;
