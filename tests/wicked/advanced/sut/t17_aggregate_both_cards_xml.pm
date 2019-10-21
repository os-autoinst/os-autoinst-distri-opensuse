# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Aggregate both cards from wicked XML files
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
    my $sut_iface = 'bond0';
    my $config    = '/etc/wicked/ifconfig/bonding.xml';
    record_info('Info', 'Aggregate both cards from wicked XML files');
    $self->get_from_data('wicked/xml/bonding.xml', $config);
    file_content_replace($config, iface0 => $ctx->iface(), iface1 => $ctx->iface2(), ip_address => $self->get_ip(type => 'bond'));
    $self->wicked_command('ifup', $sut_iface);
    validate_script_output('ip a s dev ' . $ctx->iface(),  sub { /SLAVE/ });
    validate_script_output('ip a s dev ' . $ctx->iface2(), sub { /SLAVE/ });
    $self->ping_with_timeout(type => 'host', interface => $sut_iface, count_success => 30, timeout => 4);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
