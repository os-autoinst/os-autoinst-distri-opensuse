# SUSE's openQA tests
#
# Copyright © 2016-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: machinery
# Summary: Add simple machinery test thanks to greygoo (#1592)
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils;
use registration qw(add_suseconnect_product register_product);


sub run {
    my $self = shift;
    $self->select_serial_terminal;

    if (zypper_call 'in machinery', exitcode => [0, 4]) {
        my $reported_pkgs_regex = q[(builder|kramdown)];
        if (is_sle && !script_run(q{grep -E 'nothing\s+provides.*rubygem\(ruby.*} . $reported_pkgs_regex . q{\)' /var/log/zypper.log})) {
            record_soft_failure 'bsc#1124304 - Dependency of machinery missing (dep is in HA module)';
            return;
        } else {
            die "Newly found missing dependency, please report in bsc#1124304!\n";
        }
    }
    validate_script_output 'machinery --help', sub { m/machinery - A systems management toolkit for Linux/ }, 100;
    if (get_var('ARCH') =~ /aarch64|ppc64le/ && \
        script_run("machinery inspect localhost | grep 'no machinery-helper for the remote system architecture'", 300) == 0) {
        record_soft_failure 'boo#1125785 - no machinery-helper for this architecture.';
    } else {
        assert_script_run 'machinery inspect localhost',               300;
        assert_script_run 'machinery show localhost | grep machinery', 100;
    }
}

1;
