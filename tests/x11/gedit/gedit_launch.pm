# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gedit
# Summary: Gedit: Start and exit
# - Launch gedit
# - Close gedit by "close" button
# - Launch gedit again
# - Close gedit by CTRL-Q
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>
# Tags: tc#1436122

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    ensure_installed('gedit');
    x11_start_program('gedit');
    assert_and_click 'gedit-x-button';

    x11_start_program('gedit');
    send_key "ctrl-q";
}

1;
