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
    my $go_to_target = $target eq 'localhost'                ? ''              : "ssh root\@$target";
    my $bootlog      = (script_run("which journalctl") == 0) ? "journalctl -b" : "dmesg";

    record_info "KERNEL $target$suffix", "We are now checking kernel on $target$suffix.";
    assert_script_run qq(echo -e "\\n# $target$suffix:" >> $log_file);

    # Print the Welcome message containng the system version
    assert_script_run("$go_to_target grep -i ^welcome /etc/issue | tee -a $log_file");

    # Print the detected hypervisor (may be empty)
    script_run("$go_to_target $bootlog | grep -i 'Hypervisor Detected' | tee -a $log_file");

    # Print the system information
    assert_script_run("$go_to_target uname -a | tee -a $log_file");

    # Print the uptime
    assert_script_run("$go_to_target uptime | tee -a $log_file");

    # Print the list of repositories
    script_run("$go_to_target zypper lr -d");

    # Upload all the logs from the current boot
    assert_script_run("$go_to_target $bootlog | tee /tmp/bootlog-$target$suffix.txt");
    upload_logs("/tmp/bootlog-$target$suffix.txt");

    my $dmesg = "dmesg | grep -i 'fail\\|error\\|segmentation\\|stack\\|buffer' | grep -vi 'acpi\\|ERST\\|bar\\|mouse\\|vesafb\\|firmware\\|calibration\\|thermal\\|Correctable Errors\\|calibration failed\\|PM-Timer\\|dmi\\|irqstacks\\|auto-init\\|TSC ADJUST\\|xapic not enabled\\|Firmware\\|missing monitors config\\|perfctr\\|mitigation\\|vesa\\|ram buffer\\|microcode\\|frame\\|nmi\\|pci-dma\\|pm-timer\\|tsc\\|drm\\|hv_vmbus\\|floppy\\|fd0\\|nmi\\|x2apic\\|show_stack\\|dump_stack\\|pstore\\|pagetables\\|page allocation failure\\|amd64_edac_mod\\|FW version\\|Failed to check link status\\|task [0-9a-zA-Z]{4,16} task.stack: [0-9a-zA-Z]{4,16}\\|segfault at .* in libwicked.*.so'";
    if (script_run("$go_to_target $dmesg") != 1) {
        record_soft_failure "The $target needs to be checked manually!";
        assert_script_run("$go_to_target $dmesg | tee -a $log_file");
    }
    save_screenshot;
}

1;
