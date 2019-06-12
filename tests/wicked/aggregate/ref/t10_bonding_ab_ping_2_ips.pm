# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Bonding, Active-Backup Ping 2 IPs
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>


use Mojo::Base 'wickedbase';
use testapi;


sub run {
    my ($self, $ctx) = @_;
    record_info('INFO', 'Bonding, Active-Backup Ping 2 IPs');
    my $ip = $self->get_ip(type => 'second_card', netmask => 1);
    assert_script_run('ip a a ' . $ip . ' dev ' . $ctx->iface());
}

sub test_flags {
    return {always_rollback => 1};
}

1;
