# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: visualize data integrity of the images provided by comparing checksums.
# Maintainer: Joaquín Rivera <jeriveramoya@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use data_integrity_utils 'verify_checksum';
use version_utils 'is_svirt_except_s390x';

sub run {
    # If variable is set, we only inform about it
    my $errors = get_var('CHECKSUM_FAILED');
    record_info("Checksum", $errors, result => 'fail') if $errors;
}

1;
