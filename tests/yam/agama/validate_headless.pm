## Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Agama headless validataion
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::agama_base;
use strict;
use warnings;
use testapi qw(assert_script_run select_console);
use utils qw(systemctl);

sub run {
    select_console 'install-shell';

    # verify we are not in graphic target.
    systemctl('is-active graphical.target', expect_false => 1);
    systemctl('is-active x11-autologin.service', expect_false => 1);

    # verify we are in muti-user target.
    assert_script_run('systemctl list-units --type=target | grep multi-user.target');
    systemctl('is-active multi-user.target');

    # check there is not instance of the firefox browser and icewm session.
    assert_script_run('! pgrep firefox');
    assert_script_run('! pgrep icewm-session');
}

1;
