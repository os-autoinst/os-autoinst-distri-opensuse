# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: visualize data integrity of the images provided by comparing checksums.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use data_integrity_utils 'verify_checksum';
use Utils::Backends;

sub run {
    # If variable is set, we only inform about it
    my $errors = get_var('CHECKSUM_FAILED');
    record_info("Checksum", $errors, result => 'fail') if $errors;
}

1;
