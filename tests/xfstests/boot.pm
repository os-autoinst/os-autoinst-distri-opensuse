# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Wait for system to boot
# Maintainer: Nathan Zhao <jtzhao@suse.com>
package boot;

use strict;
use 5.018;
use warnings;
use base "opensusebasetest";
use testapi;

sub run {
    my $self = shift;
    $self->wait_boot;
}

1;
