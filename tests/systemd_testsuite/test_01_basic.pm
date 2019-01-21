# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run test executed by TEST-01-BASIC from upstream after openSUSE/SUSE patches.
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>, Thomas Blume <tblume@suse.com>

use base "consoletest";
use warnings;
use strict;
use testapi;
use utils 'zypper_call';
use power_action_utils 'power_action';

sub run {
    select_console 'root-console';
    zypper_call 'in mypackage';
    assert_script_run 'cd /var/opt/systemd-tests';
    power_action('reboot', textmode => 1);
    zypper_call 'in mypackage';
    assert_script_run 'cd /var/opt/systemd-tests';
}

sub test_flags {
    return { always_rollback => 1 };
}

# sub post_fail_hook {
#     my ($self) = shift;
#     $self->SUPER::post_fail_hook;
#     assert_script_run('tar -cjf TEST-01-BASIC-logs.tar.bz2 logs/');
#     upload_logs('TEST-01-BASIC-logs.tar.bz2');
# }


1;
