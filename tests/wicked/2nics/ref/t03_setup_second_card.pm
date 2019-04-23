# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Set up a second card
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use testapi;


sub run {
    my ($self, $ctx) = @_;
    record_info('Info', 'Set up a second card');
    my $ip_address = $self->get_ip(type => 'second_card');
    assert_script_run("ip a a $ip_address dev " . $ctx->iface());
}

1;
