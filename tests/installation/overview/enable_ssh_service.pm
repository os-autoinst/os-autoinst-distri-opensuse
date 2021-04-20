# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for the Overview Page
#          of the installer.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;

sub run {
    $testapi::distri->get_overview_controller()->enable_ssh_service();
    save_screenshot;
}

1;
