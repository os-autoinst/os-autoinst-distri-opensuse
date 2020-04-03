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
    # Get path in the worker
    my $path = get_required_var(get_required_var('AUTOYAST'));
    record_info('path', $path);

    # Read content of file
    my $fh;
    open($fh, '<:encoding(UTF-8)', $path) or die "Could not open file '$path'";
    read $fh, my $profile, -s $fh;
    close $fh;
    record_info('profile before:', $profile);

    # Inject registration block with template variables
    $profile = inject_registration($profile);

    # Expand injected template variables
    $profile = expand_variables($profile);
    record_info('profile after:', $profile);

    upload_profile(profile => $profile, path => get_var('AUTOYAST'));
}

sub test_flags {
    return {fatal => 1};
}

1;
