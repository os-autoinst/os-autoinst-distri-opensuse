# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This test module handles ZFCP disk activation
#          through libyui-rest-client.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

use strict;
use warnings;
use base 'y2_installbase';

sub run {
    my $zfcp_add_disk = $testapi::distri->get_add_new_zfcp_device();
    $zfcp_add_disk->configure({channel => '0.0.fa00'});
}

1;
