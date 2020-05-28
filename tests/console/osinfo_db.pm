# SUSE's openQA tests
#
# Copyright © 2019-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Regression test osinfo-db:
# use osinfo-query tool to query the OS database;
# - List all OSes in the database;
# - List all OSes from a specific vendor;
# - List all OSes drom a specific vendor and specified columns only;
# - If succeed, the test passes, proving All commands return without error.
#
# Maintainer: Marcelo Martins <mmartins@suse.cz>
use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    #install osdbinfo packages
    zypper_call 'in osinfo-db libosinfo';

    # list all OSes in the database
    assert_script_run "osinfo-query os";

    # list all OSes from a *specific* vendor
    assert_script_run 'osinfo-query os vendor="SUSE"';
    assert_script_run 'osinfo-query os vendor="openSUSE"';

    # list all OSes from a specific vendor *and* specified columns only
    assert_script_run 'osinfo-query --fields=short-id,version os vendor="openSUSE"';
    assert_script_run 'osinfo-query --fields=short-id,version os vendor="SUSE"';

}

1;
