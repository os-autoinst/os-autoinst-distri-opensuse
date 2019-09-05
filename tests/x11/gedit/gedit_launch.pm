# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Gedit: Start and exit
# - Launch gedit
# - Close gedit by "close" button
# - Launch gedit again
# - Close gedit by CTRL-Q
# Maintainer: mitiao <mitiao@gmail.com>
# Tags: tc#1436122

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    x11_start_program('gedit');
    assert_and_click 'gedit-x-button';

    x11_start_program('gedit');
    send_key "ctrl-q";
}

1;
