# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Temporary solution to combine qam-updinstall/update_install
# and qam-updinstall/update_install_mr to conditionally load one or
# the other from a YAML schedule depending on the value of BUILD.
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;

sub run {
    my $self = shift;
    if (get_required_var('BUILD') =~ /^MR:/) {
        record_info("Maintenance Request Build", "Scheduling qam-updinstall/update_install_mr");
        autotest::loadtest("tests/qam-updinstall/update_install_mr.pm");
    }
    else {
        record_info("update_install", "Scheduling qam-updinstall/update_install");
        autotest::loadtest("tests/qam-updinstall/update_install.pm");
    }
}

1;
