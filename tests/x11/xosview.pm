# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test that xosview is able to start
# Maintainer: jan.fooken@suse.com

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    ensure_installed('xosview');
    x11_start_program('xosview -geometry 300x300+10+10', target_match => 'xosview');
    send_key 'alt-f4';
}

1;
