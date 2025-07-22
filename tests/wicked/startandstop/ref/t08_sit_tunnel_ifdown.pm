# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: SIT tunnel - ifdown
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use testapi;

sub run {
    my ($self) = @_;
    record_info('Info', 'SIT tunnel - ifdown');
    $self->create_tunnel_with_commands('sit1', 'sit', '127');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
