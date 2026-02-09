# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate registered extensions against the extension list.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'consoletest';
use utils 'zypper_call';
use testapi;
use JSON;
use scheduler 'get_test_suite_data';

sub is_registered_and_active {
    my ($product) = @_;

    return $product->{status} eq 'Registered' &&
      $product->{version} eq get_var("VERSION") &&
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
        unless (is_registered_and_active($map{$product})) {
            die "Product $product error Status: " . $map{$product}->{status} .
              "\nVersion: " . $map{$product}->{version} .
              "\nSubscription status: " . $map{$product}->{subscription_status};
        }
        zypper_call("search -i -t product $product");
    }
}

1;
