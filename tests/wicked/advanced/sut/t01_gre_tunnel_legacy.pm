# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Advanced test cases for wicked
# Test 1 : Create a GRE interface from legacy ifcfg files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    my $config = '/etc/sysconfig/network/ifcfg-gre1';
    record_info('Info', 'Create a GRE interface from legacy ifcfg files');
    $self->get_from_data('wicked/ifcfg/gre1', $config);
    $self->setup_tunnel($config, 'gre1');
    my $res = $self->get_test_result('gre1');
    die if ($res eq 'FAILED');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
