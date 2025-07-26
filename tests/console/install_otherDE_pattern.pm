# SUSE's openQA tests
#
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Framework to test other Desktop Environments
#    Non-Primary desktop environments are generally installed by means
#    of a pattern. For those tests, we assume a minimal-X based installation
#    where the pattern is being installed on top.
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';

    script_run("zypper lr -d | tee /dev/$serialdev");

    my $pattern = get_var("DE_PATTERN");
    my $zypp_type = "pattern";
    if (check_var("DE_IS_PKG", 1)) {
        $zypp_type = "package";
    }
    zypper_call "in -t $zypp_type $pattern";

    # Reset the state of lightdm, to have the new default in use (lightdm saves what the user's last session was)
    assert_script_run("rm -f ~lightdm/.cache/lightdm-gtk-greeter/state /var/lib/AccountsService/users/*");
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
