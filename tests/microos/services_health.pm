# SUSE's openQA tests
#
# Copyright 2017-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check that not failed services are present on the system
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;

sub run {
    # Yes. This test is an awesome oneliner.
    # Please remove this comment when you are extending it.
    validate_script_output("systemctl --failed", qr/0 loaded units listed./, fail_message => "There are failed systemd units present on the system");
}

1;
