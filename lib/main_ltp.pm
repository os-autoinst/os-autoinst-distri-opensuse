## no critic (Strict)
# Copyright © 2017-2020 SUSE LLC
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
#
# See kernel/install_ltp.pm and kernel/run_ltp.pm for documentation.
package main_ltp;
use base 'Exporter';
use Exporter;
use testapi qw(check_var get_required_var get_var);
use autotest;
use Archive::Tar;
use utils;
use File::Basename 'basename';
use main_common qw(boot_hdd_image load_bootloader_s390x load_kernel_baremetal_tests);
use 5.018;
use Utils::Backends 'is_pvm';
# FIXME: Delete the "## no critic (Strict)" line and uncomment "use warnings;"
# use warnings;

our @EXPORT = qw(
  load_kernel_tests
  loadtest
  shutdown_ltp
);

sub loadtest {
    my ($test, %args) = @_;
    autotest::loadtest("tests/kernel/$test.pm", %args);
}

sub shutdown_ltp {
    loadtest('proc_sys_dump') if get_var('PROC_SYS_DUMP');
    loadtest('shutdown_ltp', @_);
}

sub load_kernel_tests {
    if (get_var('LTP_BAREMETAL') && get_var('INSTALL_LTP')) {
        load_kernel_baremetal_tests();
    } else {
        load_bootloader_s390x();
    }

    loadtest "../installation/bootloader" if is_pvm;

    if (get_var('INSTALL_LTP')) {
        if (get_var('INSTALL_KOTD')) {
            loadtest 'install_kotd';
        }
        elsif (get_var('CHANGE_KERNEL_REPO') ||
            get_var('CHANGE_KERNEL_PKG') ||
            get_var('ASSET_CHANGE_KERNEL_RPM')) {
            loadtest 'change_kernel';
        }
        if (get_var('FLAVOR', '') =~ /Incidents-Kernel/) {
            loadtest 'update_kernel';
        }
        loadtest 'install_ltp';
    }
    elsif (get_var('LTP_COMMAND_FILE')) {
        if (get_var('INSTALL_KOTD')) {
            loadtest 'install_kotd';
        }
        elsif (get_var('CHANGE_KERNEL_REPO') ||
            get_var('CHANGE_KERNEL_PKG') ||
            get_var('ASSET_CHANGE_KERNEL_RPM')) {
            loadtest 'change_kernel';
        }

        loadtest 'boot_ltp';
    }
    elsif (get_var('QA_TEST_KLP_REPO')) {
        if (get_var('INSTALL_KOTD')) {
            loadtest 'install_kotd';
        }
        loadtest 'boot_ltp';
        loadtest 'qa_test_klp';
    }
    elsif (get_var('VIRTIO_CONSOLE_TEST')) {
        loadtest 'virtio_console';
        loadtest 'virtio_console_long_output';
    }
    elsif (get_var('BLKTESTS')) {
        boot_hdd_image();
        loadtest 'blktests';
    }
    elsif (get_var('TRINITY')) {
        if (get_var('INSTALL_KOTD')) {
            loadtest 'install_kotd';
        }
        elsif (get_var('CHANGE_KERNEL_REPO') ||
            get_var('CHANGE_KERNEL_PKG') ||
            get_var('ASSET_CHANGE_KERNEL_RPM')) {
            loadtest 'change_kernel';
        }
        else {
            boot_hdd_image();
        }
        loadtest "trinity";
    } elsif (get_var('NUMA_IRQBALANCE')) {
        boot_hdd_image();
        loadtest 'numa_irqbalance';
    }

    if (check_var('BACKEND', 'svirt') && get_var('PUBLISH_HDD_1')) {
        loadtest '../shutdown/svirt_upload_assets';
    }
}
