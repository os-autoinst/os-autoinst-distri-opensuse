# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Expand variables in the autoyast profiles and make it accessible for SUT
#
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use strict;
use base "opensusebasetest";
use testapi;
use File::Copy 'copy';
use File::Path 'make_path';

sub run {
    my $path = get_required_var('AUTOYAST');
    # Get file from data directory
    my $profile = get_test_data($path);
    # Return if profile is not available
    return unless $profile;
    # Expand variables
    my @vars = qw(SCC_REGCODE SCC_URL VERSION ARCH);
    foreach (@vars) {
        my $value = get_var($_);
        # Skip if value is not defined
        next unless $value;
        $profile =~ s/\{\{$_\}\}/$value/g;
    }
    # Upload modified profile
    save_tmp_file($path, $profile);
    # Copy profile to ulogs directory, so profile is available in job logs
    make_path('ulogs');
    copy(hashed_string($path), 'ulogs/autoyast_profile.xml');
    # Set AUTOYAST variable with new url
    my $url = autoinst_url . "/files/$path";
    set_var('AUTOYAST', $url);
}


sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
