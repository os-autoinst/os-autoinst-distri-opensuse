# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: iproute2
# Summary: Advanced test cases for wicked
# Test 2 : Create a GRE interface from wicked XML files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use testapi;

sub run {
    my ($self) = @_;
    record_info('Info', 'Create a GRE interface from wicked XML files');
    $self->create_tunnel_with_commands('gre1', 'gre', '24');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
