# SUSE's openQA tests
#
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
    assert_script_run "yast OneClickInstallCLI prepareinstall url=http://machinery-project.org/machinery.ymp targetfile=/tmp/local.ymp", 200;
    assert_script_run "yast OneClickInstallCLI doinstall instructionsfile=/tmp/local.ymp", 200;

    if (match_has_tag('import-untrusted-gpg-key')) {
        send_key "f10";
    }

    # run machinery --help
    validate_script_output "machinery --help", sub { m/machinery - A systems management toolkit for Linux/ }, 100;
}

1;
# vim: set sw=4 et:
