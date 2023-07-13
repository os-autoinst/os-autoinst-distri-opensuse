# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Installs and checks a service for migration scenarios
# Maintainer: Joachim Rauch <jrauch@suse.com>

use strict;
use warnings;
use base 'installbasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'systemctl', 'zypper_call';
use service_check;
use version_utils qw(is_hyperv is_sle is_sles4sap);
use main_common 'is_desktop';

sub run {
    if (get_var('SEL_SERIAL_CONSOLE')) {
        select_serial_terminal();
    }
    else {
        select_console 'root-console';
    }

    install_services($default_services)
      if is_sle
      && !is_desktop
      && !is_sles4sap
      && !is_hyperv
      && !get_var('MEDIA_UPGRADE')
      && !get_var('ZDUP')
      && !get_var('INSTALLONLY');

    if ($srv_check_results{'before_migration'} eq 'FAIL') {
        record_info("Summary", "failed", result => 'fail');
        die "Service check before migration failed!";
    }
}

sub test_flags {
    return {fatal => 0};
}

1;
