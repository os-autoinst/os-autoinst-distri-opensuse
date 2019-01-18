# SUSE's openQA tests
#
# Copyright (c) 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Disable firewall in HA tests if needed
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use hacluster;
use utils 'systemctl';

sub run {
    my ($self) = @_;
    my $firewall = $self->firewall;

    if (is_package_installed $firewall) {
        # SuSEfirewall2 can't be disabled and stopped at
        # the same time using 'disable --now'...
        systemctl "disable $firewall";
        systemctl "stop $firewall";
    }
}

1;
