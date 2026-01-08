# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enlarge the YaST window for fullscreen in ssh-X test.

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';
use testapi;
use x11utils 'ensure_fullscreen';

sub run {
    ensure_fullscreen;
}

1;
