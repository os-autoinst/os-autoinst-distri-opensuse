# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
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
use version_utils;

our @EXPORT = qw(check_virt_kernel);

sub check_virt_kernel {
    my %args         = @_;
    my $target       = $args{target}   // 'localhost';
    my $suffix       = $args{suffix}   // '';
    my $log_file     = $args{log_file} // '/tmp/virt_kernel.txt';
    my $go_to_target = $target eq 'localhost' ? '' : "ssh root\@$target";
    my ($sles_running_version, $sles_running_sp) = get_os_release($go_to_target);

    record_info "KERNEL $target$suffix", "We are now checking kernel on $target$suffix.";
    assert_script_run qq(echo -e "\\n# $target$suffix:" >> $log_file);

    assert_script_run("$go_to_target uname -a | tee -a $log_file");
    assert_script_run("$go_to_target uptime | tee -a $log_file");
    script_run("$go_to_target zypper lr -d | tee -a $log_file");

    if ($sles_running_version >= 12) {
        assert_script_run("$go_to_target journalctl -b | tee /tmp/journalctl-b-$target$suffix.txt");
        upload_logs("/tmp/journalctl-b-$target$suffix.txt");
    } else {
        assert_script_run("$go_to_target dmesg | tee /tmp/dmesg-$target$suffix.txt");
        upload_logs("/tmp/dmesg-$target$suffix.txt");
    }

    my $dmesg = "dmesg | grep -i 'fail\\|error\\|segmentation\\|stack\\|buffer' | grep -vi 'acpi\\|ERST\\|bar\\|mouse\\|vesafb\\|firmware\\|calibration\\|thermal\\|Correctable Errors\\|calibration failed\\|PM-Timer\\|dmi\\|irqstacks\\|auto-init\\|TSC ADJUST\\|xapic not enabled\\|Firmware\\|missing monitors config\\|perfctr\\|mitigation\\|vesa\\|ram buffer\\|microcode\\|frame\\|nmi\\|pci-dma\\|pm-timer\\|tsc\\|drm\\|hv_vmbus\\|floppy\\|fd0\\|nmi\\|x2apic\\|show_stack\\|dump_stack\\|pstore\\|pagetables\\|page allocation failure\\|amd64_edac_mod\\|FW version\\|Failed to check link status'";
    if (script_run("$go_to_target $dmesg") != 1) {
        record_soft_failure "The $target needs to be checked manually!";
        assert_script_run("$go_to_target $dmesg | tee -a $log_file");
    }
    save_screenshot;
}

1;
