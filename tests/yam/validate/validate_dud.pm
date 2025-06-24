# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that a simple test DUD passed by kernel cmd-line parameter was installed and can be executed.
# Check DUD functionality by boot option "inst.dud="
# See https://agama-project.github.io/docs/user/boot_options

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::agama_base;
use strict;
use warnings;
use testapi;

sub run {
    select_console 'root-console';
    # See https://build.opensuse.org/package/show/home:lslezak:dud-test/hello-world
    validate_script_output("hello-world.sh", qr/Hello world!/);
}

1;
