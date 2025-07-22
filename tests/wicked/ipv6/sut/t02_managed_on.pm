# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: IPv6 - Managed on, prefix length != 64
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use lockapi;

sub run {
    my ($self, $ctx) = @_;
    mutex_wait('radvdipv6t02');
    $self->check_ipv6($ctx);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
