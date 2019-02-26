# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Advanced test cases for wicked
# Test 5 : Create a IPIP  interface from legacy ifcfg files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    record_info('Info', 'Create a IPIP interface from legacy ifcfg files');
    $self->create_tunnel_with_commands('tunl1', 'ipip', '24');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
