# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate registered extensions against the extension list.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';
use strict;
use warnings;
use utils 'zypper_call';
use testapi;
use JSON;
use scheduler 'get_test_suite_data';

sub run {
    select_console 'root-console';

    my $json = decode_json(script_output("SUSEConnect -s"));

    for my $product (@{get_test_suite_data()->{products}}) {
        zypper_call("search -i -t product $product");

        foreach my $data_product (@$json) {
            if ($data_product->{identifier} eq $product && $data_product->{status} ne 'Registered' && $data_product->{subscription_status} ne 'ACTIVE') {
                die "Product $product not registered or not active subscription";
            }
        }
    }
}

1;
