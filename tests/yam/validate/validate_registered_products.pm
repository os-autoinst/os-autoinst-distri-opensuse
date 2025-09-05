# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate registered extensions against the extension list.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';
use utils 'zypper_call';
use testapi;
use JSON;
use scheduler 'get_test_suite_data';

sub is_registered_and_active {
    my ($product) = @_;

    return $product->{status} eq 'Registered' &&
      $product->{subscription_status} eq 'ACTIVE';
}

sub run {
    select_console 'root-console';

    my $json = decode_json(script_output("SUSEConnect -s"));
    my %map;
    foreach my $data (@$json) {
        $map{$data->{identifier}} = $data;
    }

    for my $product (@{get_test_suite_data()->{products}}) {
        zypper_call("search -i -t product $product");

        unless (is_registered_and_active($map{$product})) {
            die "Product $product not registered or not active subscription";
        }
    }
}

1;
