# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enlarge the YaST window for fullscreen in ssh-X test.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use x11utils 'ensure_fullscreen';

sub run {
    ensure_fullscreen;
}

1;
