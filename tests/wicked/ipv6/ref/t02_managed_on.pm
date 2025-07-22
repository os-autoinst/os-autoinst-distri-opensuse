# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: radvd
# Summary: IPv6 - Managed on, prefix length != 64
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use testapi;
use utils 'file_content_replace';

sub run {
    my ($self, $ctx) = @_;
    $self->get_from_data('wicked/radvd/radvd_02.conf', '/etc/radvd.conf');
    file_content_replace('/etc/radvd.conf', xxx => $ctx->iface());
    $self->sync_start_of('radvd', 'radvdipv6t02');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
