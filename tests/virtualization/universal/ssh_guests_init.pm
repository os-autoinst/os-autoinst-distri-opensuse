# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: openssh
# Summary: This test fetch SSH keys of all guests and authorize the client one
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use base "consoletest";
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    # Use serial terminal, unless defined otherwise. The unless will go away once we are certain this is stable
    select_serial_terminal unless get_var('_VIRT_SERIAL_TERMINAL', 1) == 0;

    foreach my $guest (keys %virt_autotest::common::guests) {
        record_info "$guest", "Establishing SSH connection to $guest";

        virt_autotest::utils::ssh_copy_id($guest);
        assert_script_run "ssh root\@$guest 'rm /etc/cron.d/qam_cron; hostname'";
    }
    assert_script_run qq(echo -e "PreferredAuthentications publickey\\nControlMaster auto\\nControlPersist 86400\\nControlPath ~/.ssh/ssh_%r_%h_%p" >> ~/.ssh/config);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

