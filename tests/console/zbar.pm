# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test zbar to be able to decode a qr code
#  added for fun during OSC together with DimStar to show a third person how
#  easy adding a new test to openQA can be
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "consoletest";
use strict;
use testapi;
use utils;

sub run {
    select_console 'user-console';
    assert_script_sudo("zypper -n in wget zbar");
    assert_script_run("wget " . autoinst_url . "/data/qr.png -O /tmp/qr.png");
    validate_script_output "zbarimg /tmp/qr.png", sub { m/OPENPGP4FPR:6F58C4635A519E8C4A6ACD6EE69F22089B497C99\?mac=891507df5bf02c60452e0de63ec30c24/ };
}

1;
