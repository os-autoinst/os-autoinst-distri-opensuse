# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "consoletest";
use testapi;

sub run() {
    select_console 'root-console';
    assert_script_run("zypper -n in a2ps");
    assert_script_run("curl https://www.suse.com > /tmp/suse.html");
    validate_script_output "a2ps -o /tmp/suse.ps /tmp/suse.html 2>&1", sub { m/saved into the file/ }, 3;
}

1;
#vim: set sw=4 et:

