## no critic (Strict)
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# See kernel/install_ltp.pm and kernel/run_ltp.pm for documentation.
package main_ltp;
use base 'Exporter';
use Exporter;
use testapi qw(check_var get_required_var get_var);
use utils;
use main_common qw(boot_hdd_image load_bootloader_s390x load_kernel_baremetal_tests);
use 5.018;
use Utils::Backends;
use version_utils qw(is_opensuse is_alp);
use LTP::utils qw(loadtest_kernel shutdown_ltp);
use main_common 'loadtest';
# FIXME: Delete the "## no critic (Strict)" line and uncomment "use warnings;"
# use warnings;

our @EXPORT_OK = qw(
  load_kernel_tests
);

sub load_kernel_tests {
    if ((get_var('LTP_BAREMETAL') && get_var('INSTALL_LTP')) ||
        is_backend_s390x) {
        load_kernel_baremetal_tests();
    } else {
        load_bootloader_s390x();
    }

    loadtest_kernel "../installation/bootloader" if is_pvm;

    if (get_var('INSTALL_LTP')) {
        if (get_var('INSTALL_KOTD')) {
            loadtest_kernel 'install_kotd';
        }
        elsif (get_var('CHANGE_KERNEL_REPO') ||
            get_var('CHANGE_KERNEL_PKG') ||
            get_var('ASSET_CHANGE_KERNEL_RPM')) {
            loadtest_kernel 'change_kernel';
        }
        if (get_var('FLAVOR', '') =~ /Incidents-Kernel/) {
            loadtest_kernel 'update_kernel';
        }
        loadtest_kernel 'install_ltp';

        if (get_var('LIBC_LIVEPATCH')) {
            die 'LTP_COMMAND_FILE and LIBC_LIVEPATCH are mutually exclusive'
              if get_var('LTP_COMMAND_FILE');
            loadtest_kernel 'ulp_openposix';
        }

        # If there is a command file then install_ltp schedules boot_ltp which
        # will schedule shutdown. If there is LIBC_LIVEPATCH, shutdown will be
        # scheduled by ulp_openposix.
        shutdown_ltp()
          unless get_var('LTP_COMMAND_FILE') || get_var('LIBC_LIVEPATCH');
    }
    elsif (get_var('LTP_COMMAND_FILE')) {
        if (get_var('INSTALL_KOTD')) {
            loadtest_kernel 'install_kotd';
        }
        elsif (get_var('CHANGE_KERNEL_REPO') ||
            get_var('CHANGE_KERNEL_PKG') ||
            get_var('ASSET_CHANGE_KERNEL_RPM')) {
            loadtest_kernel 'change_kernel';
        }

        loadtest_kernel 'boot_ltp';
    }
    elsif (get_var('QA_TEST_KLP_REPO')) {
        if (get_var('INSTALL_KOTD')) {
            loadtest_kernel 'install_kotd';
        }
        loadtest_kernel 'boot_ltp';
        loadtest_kernel 'qa_test_klp';
        unless (get_var('KOTD_REPO') ||
            get_var('INSTALL_KOTD') ||
            get_var('AZURE') ||
            is_opensuse) {
            loadtest_kernel 'install_klp_product';
        }
    }
    elsif (get_var('INSTALL_KLP_PRODUCT')) {
        loadtest_kernel 'boot_ltp';
        loadtest_kernel 'install_klp_product';
    }
    elsif (get_var('VIRTIO_CONSOLE_TEST')) {
        loadtest_kernel 'virtio_console';
        loadtest_kernel 'virtio_console_user';
        loadtest_kernel 'virtio_console_long_output';
    }
    elsif (get_var('BLKTESTS')) {
        boot_hdd_image();
        loadtest_kernel 'blktests';
    }
    elsif (get_var('TRINITY')) {
        if (get_var('INSTALL_KOTD')) {
            loadtest_kernel 'install_kotd';
        }
        elsif (get_var('CHANGE_KERNEL_REPO') ||
            get_var('CHANGE_KERNEL_PKG') ||
            get_var('ASSET_CHANGE_KERNEL_RPM')) {
            loadtest_kernel 'change_kernel';
        }
        else {
            boot_hdd_image();
        }
        loadtest_kernel "trinity";
    } elsif (get_var('NUMA_IRQBALANCE')) {
        boot_hdd_image();
        loadtest_kernel 'numa_irqbalance';
    }
    elsif (get_var('LIBC_LIVEPATCH')) {
        loadtest_kernel 'boot_ltp';
        loadtest_kernel 'ulp_openposix';
    }

    if (is_svirt && get_var('PUBLISH_HDD_1')) {
        loadtest_kernel '../shutdown/svirt_upload_assets';
    }
}
