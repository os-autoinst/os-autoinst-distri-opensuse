# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Upgrade all guests to their latest state
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use warnings;
use strict;
use testapi;
use qam 'ssh_add_test_repositories';
use utils;
use xen;

sub run {
    my ($self) = @_;

    record_info "DUP", "Upgrading the system to it's latest version";
    script_run "( ssh root\@$_ '( zypper -n dup > /tmp/dup.log; echo \$? > /tmp/dup )' & )" foreach (keys %xen::guests);
    record_info "WAIT", "Waiting for all systems to be upgraded";
    script_retry("ssh root\@$_ cat /tmp/dup", delay => 60, retry => 180) foreach (keys %xen::guests);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

