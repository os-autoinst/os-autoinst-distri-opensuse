# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: - Inject registration block for an AutoYaST profile cloned
#            due to registration code is never cloned as it is not stored in the system anywhere.
#          - Expand variables
#          - Upload modified profile
# Maintainer: Joaquín Rivera <jeriveramoya@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use autoyast qw(inject_registration expand_variables upload_profile);

sub run {
    my $path = get_required_var('AUTOYAST');
    # Get file from data directory
    my $profile = get_test_data($path);
    # Inject registration block with template variables
    $profile = inject_registration($profile);
    # Expand injected template variables
    $profile = expand_variables($profile);
    # Upload asset
    upload_profile(profile => $profile, path => $path);
}

sub test_flags {
    return {fatal => 1};
}

1;
