# Copyright 2017-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: test for 'zypper lifecycle' for toolchain module
#          Fail when latest gcc does have EOS Now or n/a
# Maintainer: Maintainer: QE Core <qe-core@suse.de>
# Tags: fate#322050

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';

sub run {
    select_serial_terminal;
    my $latest_gcc = script_output(q(zypper se -t package 'gcc>10'|awk '/\s+gcc[0-9]+\s+/ {print$2}'|sort -Vr|head -n1));
    zypper_call("in sle-module-toolchain-release $latest_gcc", timeout => 1500);
    my $output = script_output("zypper lifecycle $latest_gcc", 300);
    diag($output);
    if ($output =~ m/.*$latest_gcc\s*(Now|n\/a).*/) {
        die("For toolchain module $latest_gcc end of support should be not Now, lifecycle output:\n $output");
    }
}

1;
