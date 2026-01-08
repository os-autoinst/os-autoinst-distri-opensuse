# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Validate the base product from /etc/products.d/baseproduct.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;
use Test::Assert ':assert';

sub run {
    select_console 'root-console';
    my $expected_prod = get_required_var("AGAMA_PRODUCT_ID");
    my $prod = script_output 'basename `readlink /etc/products.d/baseproduct ` .prod';
    assert_equals($expected_prod, $prod, "Wrong product name in '/etc/products.d/baseproduct'");
}

1;
