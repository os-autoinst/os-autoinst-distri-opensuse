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
use virt_autotest::utils 'reset_network_config';
use utils 'select_backend_console';

sub run {
    # Login as root
    select_backend_console if (!check_screen('text-logged-in-root'));
    # Ensure automatic network configuration migration
    reset_network_config;
}

1;
