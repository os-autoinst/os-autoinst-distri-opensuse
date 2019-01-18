# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test docker-compose installation
#    Cover the following aspects of docker-compose:
#      * package can be installed
# Maintainer: Panagiotis Georgiadis <pgeorgiadis@suse.com>


use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;

# Setup the required testing environment
sub setup {
    # install the docker package if it's not already installed
    zypper_call('in docker');

    # make sure docker daemon is running
    systemctl('start docker');
    systemctl('status docker');
}

sub run {
    select_console("root-console");

    record_info 'Setup', 'Setup the environment';
    setup;

    record_info 'Test #1', 'Test: Installation';
    zypper_call("in docker-compose");
}

1;
