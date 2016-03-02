# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;

# Installation media contain devel packages
# https://fate.suse.com/316652
sub run() {
    my $repo  = "SLERT12-SP1_12.1-0";
    my $pkgs  = "babeltrace-devel lttng-tools-devel kernel-compute-devel kernel-compute_debug-devel kernel-rt-devel kernel-rt_debug-devel kernel-devel-rt libcpuset-devel";
    my $count = () = $pkgs =~ /\S+/g;

    validate_script_output "zypper -q search -r $repo $pkgs | grep -c package\$", sub { /^$count$/ };
}

1;
