# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Just creating required locks to sync between ref and sut.
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'basetest';
use wickedbase;
use testapi;
use lockapi;

sub run {
    my ($self, $args) = @_;

    if (get_var('IS_WICKED_REF')) {
        for my $test (@{$args->{wicked_tests}}) {
            wickedbase::do_barrier_create('pre_run', $test);
            wickedbase::do_barrier_create('post_run', $test);
        }
        mutex_create('wicked_barriers_created');
    }
    else {
        #we need this to make sure that we will not start using barriers before they created
        mutex_wait('wicked_barriers_created');
    }
}

1;
