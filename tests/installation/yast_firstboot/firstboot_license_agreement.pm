# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Handles Licence Agreement dialog in YaST Firstboot Configuration.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_firstboot_basetest';
use strict;
use warnings;
use scheduler 'get_test_suite_data';

sub run {
    my $test_data              = get_test_suite_data()->{license_agreement};
    my $license_agreement      = $testapi::distri->get_firstboot_license_agreement();
    my $license_agreement_info = $license_agreement->collect_current_license_agreement_info();
    if ($test_data->{language} ne $license_agreement_info->{language}) {
        die "Wrong EULA language. Expected: '$test_data->{language}' got: '$license_agreement_info->{language}'";
    }
    for my $line (@{$test_data->{text}}) {
        if ($license_agreement_info->{text} !~ /$line/) {
            die "EULA does not contain expected text '$line'.\nEULA content: $license_agreement_info->{text}";
        }
    }
    $license_agreement->accept_license();
}

1;
