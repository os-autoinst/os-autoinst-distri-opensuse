## SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: proxymode_redirect_serial1: Setup a channel which redirects Physical machine serial output to Proxy machine standard output.
# Maintainer: John <xgwang@suse.com>

use testapi;
sub run {
    my $self = shift;
    my $test_machine = get_var("TEST_MACHINE");
    $self->redirect_serial($test_machine);
}

sub test_flags {
    return {fatal => 1};
}

1;
