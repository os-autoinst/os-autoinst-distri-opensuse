# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Disable firewall in HA tests if needed
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base 'haclusterbasetest';
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
