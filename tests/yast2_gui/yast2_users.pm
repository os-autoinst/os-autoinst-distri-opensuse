# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: yast2-users
# Summary: Test initial startup of users configuration YaST2 module
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;

sub run {
    select_console 'x11';
    y2_module_guitest::launch_yast2_module_x11('users', match_timeout => 100);
    send_key "alt-o";    # OK => Exit
}

1;
