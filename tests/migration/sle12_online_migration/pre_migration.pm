# SLE12 online migration tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: sle12 online migration testsuite
# Maintainer: mitiao <mitiao@gmail.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use migration;
use version_utils 'is_sle';

sub set_scc_proxy_url {
    if (my $u = get_var('SCC_PROXY_URL')) {
        type_string "echo 'url: $u' > /etc/SUSEConnect\n";
    }
    save_screenshot;
}

sub check_or_install_packages {
    if (get_var("FULL_UPDATE") || get_var("MINIMAL_UPDATE")) {
        # if system is fully updated or even minimal patch applied, all necessary packages for online migration should be installed
        # check if the packages was installed along with update
        my $output = script_output "rpm -qa yast2-migration zypper-migration-plugin rollback-helper | sort";
        if ($output !~ /rollback-helper.*?yast2-migration.*?zypper-migration-plugin/s) {
            record_soft_failure 'bsc#982150: migration packages were not installed along with system update. Installing missed package to continue the test';
            assert_script_run "zypper -n in yast2-migration zypper-migration-plugin rollback-helper snapper", 190;
        }
    }
    else {
        # install necessary packages for online migration if system is not updated
        # also update snapper to ensure rollback service work properly after migration
        assert_script_run "zypper -n in yast2-migration zypper-migration-plugin rollback-helper snapper", 190;
    }
}

sub remove_kgraft_patch {
    if (get_var('SCC_ADDONS')) {
        for my $addon (split(/,/, get_var('SCC_ADDONS', ''))) {
            if ($addon eq 'live') {
                zypper_call('rm $(rpm -qa kgraft-patch-*)');
                record_soft_failure 'bsc#985647: [online migration] Conflict on kgraft-patch-3_12_57 when doing SCC online migration with Live Patching addon';
            }
        }
    }
}

sub run {
    select_console 'root-console';

    check_or_install_packages;

    # set scc proxy url here to perform online migration via scc proxy
    set_scc_proxy_url;

    disable_installation_repos;

    # according to comment 19 of bsc#985647, uninstall all kgraft-patch* packages prior to migration as a workaround to
    # solve conflict during online migration with live patching addon
    remove_kgraft_patch if is_sle('<15');
    # create btrfs subvolume for aarch64 before migration
    create_btrfs_subvolume() if (check_var('ARCH', 'aarch64'));
}

sub test_flags {
    return {fatal => 1};
}

1;
