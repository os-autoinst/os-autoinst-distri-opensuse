# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Prepare AutoYaST xml files when using rules and clases
# by expanding variables before installation and setting correct URL
# for the installer.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use autoyast qw(
  get_test_data_files
  prepare_ay_file);

sub run {
    my $ay_path = get_required_var('AUTOYAST');

    die 'Please, in order to use AutoYaST rules and classes, AUTOYAST setting ' .
      'should point to a folder ending with `/`,' .
      'i.e.: AUTOYAST=autoyast_sle15/rule-based_example/' unless $ay_path =~ /\/$/;

    # read list of files from some folder in data/
    my $files = get_test_data_files($ay_path);

    # expand/map variables for each xml file processed
    prepare_ay_file($_) for (@$files);

    # set AutoYaST path as URL
    set_var('AUTOYAST', autoinst_url . "/files/$ay_path");
}

sub test_flags {
    return {fatal => 1};
}

1;
