# Copyright 2024 SUSE LLC
# Copyright 2024 Georg Pfuetzenreuter
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: wicked
# Summary: Dummy - ifup, ifreload

use base 'wickedbase';
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;

    my $config_base = '/etc/sysconfig/network/';
    my @interfaces = qw( dummy1 foo0 foo1 );

    foreach (@interfaces) {
        my $interface = $_;
        $self->get_from_data("wicked/ifcfg/$interface", "$config_base/$interface");

        $self->wicked_command('ifup', "$interface");
        $self->wicked_command('ifreload', "$interface");
    }

    foreach (@interfaces) {
        die if ($self->get_test_result($_) eq 'FAILED');
    }
}

sub test_flags {
    return {always_rollback => 1};
}

1;
