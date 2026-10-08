# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Just nothing to do. Used for conditional create_hdd job
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

package nop;
use Mojo::Base 'opensusebasetest';

sub run {
    # NOP!!
    sleep 10;
}

1;
