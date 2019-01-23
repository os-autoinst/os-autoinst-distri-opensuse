# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: RT installation media should contain devel packages
# Maintainer: mkravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

# https://fate.suse.com/316652
sub run {
    my $pkgs  = "babeltrace-devel lttng-tools-devel kernel-rt-devel kernel-rt_debug-devel kernel-devel-rt libcpuset-devel";
    my $count = () = $pkgs =~ /\S+/g;

    validate_script_output "zypper -q search -r `zypper lr|grep SLERT|awk '{print \$3}'` $pkgs | grep -c package\$", sub { /^$count$/ };
}

1;
