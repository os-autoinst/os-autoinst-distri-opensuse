# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Prepare AutoYaST xml profile by expanding variables
# before installation and setting correct URL for the installer.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use autoyast qw(
  detect_profile_directory
  prepare_ay_file);

sub run {
    my $ay_path = get_required_var('AUTOYAST');

    # get file from data directory and guess path if needed
    my $profile = get_test_data($ay_path);
    $ay_path = detect_profile_directory(profile => $profile, path => $ay_path);

    # expand/map variables in the xml file processed
    # AutoYaST path is updated in case of using templates
    $ay_path = prepare_ay_file($ay_path);

    # set AutoYaST path as URL
    set_var('AUTOYAST', autoinst_url . "/files/$ay_path");
}

sub test_flags {
    return {fatal => 1};
}

1;
