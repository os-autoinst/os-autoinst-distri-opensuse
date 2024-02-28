# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Waits for parallel children to finish
# Maintainer: Marius Kittler <mkittler@suse.de>

use base 'basetest';
use strict;
use warnings;
use testapi;
use mmapi;

sub run {
    my $hostname = get_required_var('HOSTNAME');
    wait_for_children if $hostname =~ m/server|master/;
}

1;
