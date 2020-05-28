# SUSE's openQA tests
#
# Copyright (C) 2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: Virtualization kernel functions
# Maintainer: Pavel Dostal <pdostal@suse.cz>

package virt_autotest::kernel;

use base Exporter;
use Exporter;

use utils;
use strict;
use warnings;
use testapi;
use virt_autotest_base;
use virt_utils;
use version_utils;

our @EXPORT = qw(check_virt_kernel);

sub check_virt_kernel {
    my $guest  = shift // '';
    my $suffix = shift // '';
    my $go_to_target = $guest eq '' ? '' : "ssh root\@$guest";
    my ($sles_running_version, $sles_running_sp) = get_sles_release($go_to_target);

    assert_script_run("$go_to_target uname -a");
    if ($sles_running_version >= 12) {
        assert_script_run("$go_to_target journalctl -b | tee /tmp/journalctl-b-$guest$suffix.log");
        upload_logs("/tmp/journalctl-b-$guest$suffix.log");
    } else {
        assert_script_run("$go_to_target dmesg | tee /tmp/dmesg-$guest$suffix.log");
        upload_logs("/tmp/dmesg-$guest$suffix.log");
    }

    my $dmesg = "dmesg | grep -i 'fail\\|error\\|segmentation\\|stack' |grep -vi 'acpi\\|ERST\\|bar\\|mouse\\|vesafb\\|thermal\\|Correctable Errors\\|calibration failed\\|PM-Timer\\|dmi\\|irqstacks\\|auto-init\\|TSC ADJUST\\|xapic not enabled\\|Firmware\\|missing monitors config'";
    if (script_run("$go_to_target $dmesg") != 1) {
        record_soft_failure "The $guest needs to be checked manually!";
    }
    save_screenshot;
}

1;
