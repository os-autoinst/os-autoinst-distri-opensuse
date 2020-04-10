# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Expand variables in the autoyast profiles and make it accessible for SUT
#
# - Get profile from autoyast template
# - Map version names
# - Get IP address from system variables
# - Get values from SCC_REGCODE SCC_REGCODE_HA SCC_REGCODE_GEO SCC_REGCODE_HPC SCC_URL ARCH LOADER_TYPE
# - Modify profile with obtained values and upload new autoyast profile
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use autoyast qw(
  detect_profile_directory
  expand_template
  expand_version
  adjust_network_conf
  expand_variables
  upload_profile);

sub run {
    my $path = get_required_var('AUTOYAST');
    # Get file from data directory
    my $profile = get_test_data($path);

    $path    = detect_profile_directory(profile => $profile, path => $path);
    $profile = get_test_data($path);
    die "Empty profile" unless $profile;

    # if profile is a template, expand and rename
    $profile = expand_template($profile) if $path =~ s/^(.*\.xml)\.ep$/$1/;
    die $profile if $profile->isa('Mojo::Exception');

    $profile = expand_version($profile);
    $profile = adjust_network_conf($profile);
    $profile = expand_variables($profile);
    upload_profile(profile => $profile, path => $path);
}

sub test_flags {
    return {fatal => 1};
}

1;
