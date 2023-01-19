# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test 'stig' hardening in the 'scap-security-guide' works: setup environment
# Maintainer: QE Security <none@suse.de>
# Tags: poo#93886, poo#104943

use base 'stigtest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle);

sub run {
    my ($self) = @_;
    select_console 'root-console';

    # Install packages
    zypper_call('in openscap-utils scap-security-guide', timeout => 180);

    # Record the pkgs' version for reference
    my $out = script_output("zypper se -s openscap-utils scap-security-guide");
    record_info("Pkg_ver", "openscap security guide packages' version: $out");

    # Set ds file
    $self->set_ds_file();

    # Check the ds file information for reference
    my $f_ssg_ds = is_sle ? $stigtest::f_ssg_sle_ds : $stigtest::f_ssg_tw_ds;
    $out = script_output("oscap info $f_ssg_ds");
    record_info("oscap info", "\"# oscap info $f_ssg_ds\" returns:\n $out");

    # Check the oscap version information for reference
    $out = script_output("oscap -V");
    record_info("oscap version", "\"# oscap -V\" returns:\n $out");
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
