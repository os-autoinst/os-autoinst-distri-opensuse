# SUSE's openQA tests
#
# Copyright © 2015-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: a2ps test based on: https://progress.opensuse.org/issues/9472
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';
    zypper_call "in a2ps";
    assert_script_run("curl https://www.suse.com > /tmp/suse.html");
    validate_script_output "a2ps -o /tmp/suse.ps /tmp/suse.html 2>&1", sub { m/saved into the file/ }, 3;
}

1;

