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

sub run {
    select_console 'root-console';
    systemctl 'start vsftpd';
    systemctl 'status vsftpd';
    save_screenshot;
    assert_script_run 'systemctl status vsftpd --no-pager | grep active';
}

1;
