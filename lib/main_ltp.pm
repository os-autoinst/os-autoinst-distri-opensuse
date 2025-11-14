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
use main_common qw(boot_hdd_image load_bootloader_s390x load_kernel_baremetal_tests replace_opensuse_repos_tests is_repo_replacement_required);
use 5.018;
use Utils::Backends;
use Utils::Architectures qw(is_s390x);
use version_utils qw(is_opensuse is_transactional is_sle_micro);
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

    # Schedule bootloader only for PowerVM non-installation tests
    loadtest_kernel "../installation/bootloader" if (is_pvm && !get_var('LTP_BAREMETAL'));

    if (get_var('INSTALL_LTP')) {
        if (is_transactional) {
            # Handle specific boot requirements for different backends and architectures
            if (is_s390x) {
                loadtest 'boot/boot_to_desktop';
            }
            elsif ((is_ipmi || is_pvm)) {
                loadtest 'installation/ipxe_install' if is_ipmi;
                loadtest 'microos/install_image';
            }
            else {
                loadtest 'microos/disk_boot';
            }
            replace_opensuse_repos_tests if is_repo_replacement_required;
            loadtest 'transactional/host_config';
            loadtest 'console/suseconnect_scc' if is_sle_micro;
        }

        if (get_var('INSTALL_KOTD')) {
            loadtest_kernel 'install_kotd';
        }
        elsif (get_var('CHANGE_KERNEL_REPO') ||
            get_var('CHANGE_KERNEL_PKG') ||
            get_var('ASSET_CHANGE_KERNEL_RPM')) {
            loadtest_kernel 'change_kernel';
        }
        if (get_var('FLAVOR', '') =~ /Incidents-Kernel|Updates-Staging|Increments|Maintenance-KOTD/) {
            loadtest_kernel 'update_kernel';
        }

        # transactional needs to first run install_ltp due broken grub menu
        # counting detection in add_custom_grub_entries():
        # Test died: Unexpected number of grub entries: 5, expected: 3 at lib/bootloader_setup.pm line 166.
        my $needs_update = is_transactional && (get_var('FLAVOR', '') =~ /-Staging|-Updates/);

        if ($needs_update && get_var('KGRAFT')) {
            loadtest_kernel 'update_kernel';
        }

        loadtest_kernel 'install_ltp';

        if ($needs_update && !get_var('KGRAFT')) {
            loadtest 'transactional/install_updates';
        }

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
        shutdown_ltp();
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
    elsif (get_var('KDUMP')) {
        loadtest_kernel 'kdump';
    }

    if (is_svirt && get_var('PUBLISH_HDD_1')) {
        loadtest_kernel '../shutdown/svirt_upload_assets';
    }
}
