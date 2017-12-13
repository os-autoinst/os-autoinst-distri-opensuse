# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: virt_autotest: virtualization automation test in openqa, both kvm and xen supported
# Maintainer: alice <xlai@suse.com>

use strict;
use warnings;
use testapi;
use base "reboot_and_wait_up";

sub run {
    my $self    = shift;
    my $timeout = 180;
    $self->reboot_and_wait_up($timeout);
}

sub test_flags {
    return {fatal => 1};
}

1;

