# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validate if generated autoyast profile corresponds to the expected one
# Maintainer: Joaquín Rivera <jeriveramoya@suse.com>

use strict;
use warnings;
use base 'basetest';
use testapi;
use xml_utils;
use scheduler;
use autoyast 'init_autoyast_profile';

sub run {
    my $errors;
    my $test_data      = get_test_suite_data();
    my $cloned_profile = $test_data->{cloned_profile};        # get test data related with ay profile
    my $xpc            = get_xpc(init_autoyast_profile());    # get XPathContext

    foreach my $check (@{$cloned_profile}) {
        my $res = verify_option(xpc => $xpc,
            xpath           => $check->{xpath},
            search_by_value => $check->{search_by_value},
            expected_value  => $check->{value}
        );
        $errors .= "$res\n" if ($res);
    }
    die "Errors:\n$errors" if ($errors);
}

1;
