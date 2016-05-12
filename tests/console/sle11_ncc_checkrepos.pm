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
use strict;
use testapi;

sub run() {
    select_console 'user-console';

    my $script = 'zypper lr | tee zypper_lr.txt';
    validate_script_output $script, sub { m/nu_novell_com/ };    # need a better output validation here

    # upload the output of repos
    type_string "clear\n";
    upload_logs "zypper_lr.txt";
    assert_screen "zypper_lr-log-uploaded";
}

1;
# vim: set sw=4 et:
