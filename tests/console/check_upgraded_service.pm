# SUSE's openQA tests
#
# Copyright ©2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Checks an service after an upgrade
# Maintainer: Joachim Rauch <jrauch@suse.com>

use base 'consoletest';
use testapi;
use strict;
use warnings;
use utils 'systemctl';
use service_check;
use version_utils qw(is_sle is_sles4sap);
use main_common 'is_desktop';

sub run {
    select_console 'root-console';
    check_services($default_services) if (is_sle && !is_desktop && !is_sles4sap && !get_var('MEDIA_UPGRADE') && !get_var('ZDUP') && !get_var('INSTALLONLY'));
    check_nvidia() if (get_var('SCC_ADDONS') =~ m/we/);
}

sub test_flags {
    return {fatal => 0};
}

1;
