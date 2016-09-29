# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Postgres tests for 11SP4
# G-Maintainer: Richard Brown <rbrownccb@opensuse.org>

use base "consoletest";
use strict;
use testapi;
use utils;

sub run() {
    my $self = shift;

    select_console 'root-console';

    # install the postgresql94 client package
    zypper_call "in postgresql94";

    # check the postgresql94 client
    assert_script_run "/usr/bin/psql --help", 200;
}

1;
# vim: set sw=4 et:
