# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Enable kdump and verify it's enabled
# Maintainer: Nathan Zhao <jtzhao@suse.com>
package enable_kdump;

use strict;
use 5.018;
use warnings;
use base "opensusebasetest";
use utils qw(power_action zypper_call);
use kdump_utils;
use testapi;

sub run {
    my $self = shift;
    select_console('root-console');

    # Also panic when softlockup
    assert_script_run("echo 'kernel.softlockup_panic = 1' >> /etc/sysctl.conf");
    assert_script_run("sysctl -p");

    # Activate kdump
    prepare_for_kdump;
    activate_kdump;

    # Reboot
    power_action('reboot');
    $self->wait_boot;
    select_console('root-console');
    return 1 unless kdump_is_active;
}

1;
