# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Restore system for automatic upgrade which avoids missing features
# after upgrade, for example, non-auto dns policy leads to no dns config after
# upgrade.
#
# Maintainer: Wayne Chen <wchen@suse.com>, qe-virt@suse.de

use Mojo::Base 'opensusebasetest';
use testapi;
use virt_autotest::utils qw(select_backend_console reset_network_config subscribe_extensions_and_modules);
use utils qw(remove_installed_packages);

sub run {
    # Login as root
    select_backend_console(init => 0) if (!check_screen('text-logged-in-root'));
    # Remove unnecessary or unsupported packages
    remove_installed_packages(packages => get_var('INSTALL_OTHER_PACKAGES', ''));
    # Deregister unnecessary or unsupported extensions
    subscribe_extensions_and_modules(reg_exts => get_var('SCC_REGEXTS', ''), activate => 0);
    # Ensure automatic network configuration migration
    reset_network_config;
}

1;
