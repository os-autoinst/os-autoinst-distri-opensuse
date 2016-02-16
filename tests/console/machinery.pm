# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use testapi;

sub run() {
    select_console 'root-console';

    # add machinery repository from ymp file
    assert_script_run "yast OneClickInstallCLI prepareinstall url=http://machinery-project.org/machinery.ymp targetfile=/tmp/local.ymp";
    assert_script_run "yast OneClickInstallCLI doinstall instructionsfile=/tmp/local.ymp";

    assert_screen ['Import Untrusted GnuPG Key'], 60;
    send_key "f10";

    # run machinery --help 
    assert_script_run "machinery --help", 200;
    die "machinery --help failed" unless wait_serial "machinery - A systems management toolkit for Linux"
}

1;
# vim: set sw=4 et:
