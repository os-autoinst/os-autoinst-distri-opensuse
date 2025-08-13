# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: lynx
# Summary: check that lynx can connect via HTTPS.
#
# Maintainer: QE Security <none@suse.de>

use base "consoletest";
use testapi;
use utils 'zypper_call';
use web_browser qw(setup_web_browser_env run_web_browser_text_based);

sub run {
    select_console("root-console");
    setup_web_browser_env();
    zypper_call("--no-refresh --no-gpg-checks in lynx");
    run_web_browser_text_based("lynx", "-accept_all_cookies -head -dump");
}

sub test_flags {
    return {fatal => 0};
}

1;
