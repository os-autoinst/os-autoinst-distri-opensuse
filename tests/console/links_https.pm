# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: links
# Summary: Test with "FIPS" installed and enabled, the WWW browser "links"
#          can access https web pages successfully.
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#52289, tc#1621467, poo#65375

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use web_browser qw(setup_web_browser_env run_web_browser_text_based);

sub run {
    select_console "root-console";
    setup_web_browser_env();
    zypper_call("--no-refresh --no-gpg-checks in links");
    run_web_browser_text_based("links", undef);
}

sub test_flags {
    return {fatal => 0};
}

1;
