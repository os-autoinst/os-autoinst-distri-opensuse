# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: SIT tunnel - ifdown
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
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
