# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handle x11 login (username+password)
# Maintainer: QE Core <qe-core@suse.de>

use base "x11test";
use testapi;

sub run {
    enter_cmd $username;
    sleep 1;
    enter_cmd $password;
}

1;
