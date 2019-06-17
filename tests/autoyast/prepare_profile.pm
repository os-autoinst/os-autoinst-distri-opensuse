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
use warnings;
use base "opensusebasetest";
use testapi;
use version_utils 'is_sle';
use registration 'scc_version';
use autoyast 'expand_template';
use File::Copy 'copy';
use File::Path 'make_path';

sub run {
    my $path = get_required_var('AUTOYAST');
    # Get file from data directory
    my $profile = get_test_data($path);
    # Return if profile is not available
    return unless $profile;

    # Profile is a template, expand and rename
    $profile = expand_template($profile) if $path =~ s/^(.*\.xml)\.ep$/$1/;
    die $profile if $profile->isa('Mojo::Exception');

    # Expand VERSION, as e.g. 15-SP1 has to be mapped to 15.1
    if (my $version = scc_version(get_var('VERSION', ''))) {
        $profile =~ s/\{\{VERSION\}\}/$version/g;
    }
    # For s390x and svirt backends need to adjust network configuration
    my $hostip;
    if (check_var('BACKEND', 's390x')) {
        ($hostip) = get_var('S390_NETWORK_PARAMS') =~ /HostIP=(.*?)\//;
    }
    elsif (check_var('BACKEND', 'svirt')) {
        $hostip = get_var('VIRSH_GUEST');
    }
    $profile =~ s/\{\{HostIP\}\}/$hostip/g if $hostip;

    # Expand other variables
    my @vars = qw(SCC_REGCODE SCC_REGCODE_HA SCC_REGCODE_GEO SCC_URL ARCH LOADER_TYPE);
    # Push more variables to expand from the job setting
    my @extra_vars = push @vars, split(/,/, get_var('AY_EXPAND_VARS', ''));

    for my $var (@vars) {
        # Skip if value is not defined
        next unless my ($value) = get_var($var);
        $profile =~ s/\{\{$var\}\}/$value/g;
    }
    if (check_var('IPXE', '1')) {
        $path = get_required_var('SUT_IP') . $path;
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
