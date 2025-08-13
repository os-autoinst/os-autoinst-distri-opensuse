# SUSE's openQA tests - FIPS tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: w3m
# Summary: check that w3m can connect via HTTPS.
#
# Maintainer: QE Security <none@suse.de>

use base "consoletest";
use testapi;
use utils 'zypper_call';
use web_browser qw(setup_web_browser_env run_web_browser_text_based);

sub run {
    select_console("root-console");
    zypper_call("--no-refresh --no-gpg-checks in w3m");
    run_web_browser_text_based("w3m", "-dump_head");
}

1;
