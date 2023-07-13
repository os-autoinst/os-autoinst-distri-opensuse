# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-users
# Summary: Test initial startup of users configuration YaST2 module
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;

sub run {
    select_console 'x11';
    y2_module_guitest::launch_yast2_module_x11('users', match_timeout => 200);
    send_key "alt-o";    # OK => Exit
}

1;
