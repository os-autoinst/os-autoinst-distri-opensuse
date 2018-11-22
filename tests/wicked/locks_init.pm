# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Standalone card - ifdown, ifreload
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'opensusebasetest';
use strict;
use testapi;
use lockapi;
use mmapi;

sub run {
    my ($self, $args) = @_;

    if (get_var('IS_WICKED_REF')) {
        for my $test (@{$args->{wicked_tests}}) {
            my $barrier_name = 'test_' . $test . '_ready';

            record_info('barrier create', $barrier_name . ' num_children: 2');
            barrier_create($barrier_name, 2);
        }
        mutex_create('wicked_barriers_created');
    }
    else {
        #we need this to make sure that we will not start using barriers before they created
        mutex_wait('wicked_barriers_created');
    }
}

1;
