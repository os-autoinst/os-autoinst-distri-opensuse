# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validation module to check patterns installed.
# Scenarios covered:
# - zypper search for named patterns(base,enhanced_base;
# - zypper search for removed pattern apparmor
#
# Maintainer: Yiannis Bonatakis <ybonatakis@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use utils;

sub run {

    select_console('root-console');

    my @installed_patterns = split /,/, get_var('PATTERNS');

    foreach my $pattern (@installed_patterns) {
        my $installed = ($pattern =~ s/^-//) ? 0 : 1;
        if ($installed) {
            record_info("Installed", "$pattern");
            zypper_call("se -x -t pattern -i -n $pattern");
        }
        else {
            record_info("Not installed", "$pattern");
            zypper_call("se -x -t pattern -u -n $pattern");
        }
    }
}

1;
