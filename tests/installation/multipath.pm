# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test module to activate multipath during initial installation
# - If MULTIPATH_CONFIRM is set to YES, select yes at multipath detection screen
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    # Sometimes multipath detection takes longer
    assert_screen "enable-multipath", 60;
    send_key((get_var("MULTIPATH_CONFIRM") =~ /\bNO\b/i) ? "alt-n" : "alt-y");
}

1;
