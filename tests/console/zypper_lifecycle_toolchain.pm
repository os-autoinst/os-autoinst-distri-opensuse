# Copyright (C) 2017-2021 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# Package: zypper
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: test for 'zypper lifecycle' for toolchain module
#          Fail when latest gcc does have EOS Now or n/a
# Maintainer: Maintainer: QE Core <qe-core@suse.de>
# Tags: fate#322050

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    my $latest_gcc = script_output(q(zypper se -t package 'gcc>10'|awk '/\s+gcc[0-9]+\s+/ {print$2}'|sort -Vr|head -n1));
    zypper_call("in sle-module-toolchain-release $latest_gcc", timeout => 1500);
    my $output = script_output("zypper lifecycle $latest_gcc", 300);
    diag($output);
    if ($output =~ m/.*$latest_gcc\s*(Now|n\/a).*/) {
        die("For toolchain module $latest_gcc end of support should be not Now, lifecycle output:\n $output");
    }
}

1;
