# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: IPv6 - Managed on, prefix length != 64, RDNSS
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use testapi;
use utils 'file_content_replace';

sub run {
    my ($self, $ctx) = @_;
    $self->get_from_data('wicked/radvd/radvd_01.conf', '/etc/radvd.conf');
    my $ipv6_dns = $self->get_ip(type => 'dns_advice');
    file_content_replace('/etc/radvd.conf', xxx => $ctx->iface(), dns_advice => $ipv6_dns);
    $self->sync_start_of('radvd', 'radvdipv6t01');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
