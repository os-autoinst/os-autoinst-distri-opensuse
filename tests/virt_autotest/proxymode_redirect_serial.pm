## SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: proxymode_redirect_serial1: Setup a channel which redirects Physical machine serial output to Proxy machine standard output.
# Maintainer: John <xgwang@suse.com>

use strict;
use warnings;
use testapi;
use base "proxymode";
sub run {
    my $self         = shift;
    my $test_machine = get_var("TEST_MACHINE");
    $self->redirect_serial($test_machine);
}

sub test_flags {
    return {fatal => 1};
}

1;
