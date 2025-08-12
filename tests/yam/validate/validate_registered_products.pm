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

sub run {
    select_console 'root-console';

    my @product_list = split(/,/, get_var('PRODUCTS'));
    my $list_size = @product_list;

    script_run('suseconnect -d');

    # Verify that the products are registered
    foreach (@product_list) { zypper_call("search -i -t product $_"); }
    foreach (@product_list) {
        my $json = decode_json(script_output("SUSEConnect -s"));
        for my $i (0 .. $list_size - 1) {
            if ($json->[$i]->{identifier} eq $_ && $json->[$i]->{status} ne 'Registered') {
                die "Product $_ not registered";
            }
        }
    }
}

1;
