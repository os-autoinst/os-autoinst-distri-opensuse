# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: tracker startup
# Maintainer: nick wang <nwang@suse.com>

use base "x11test";
use testapi;

sub run {
    x11_start_program("tracker-needle", target_match => 'tracker-needle-launched');
    send_key "alt-f4";
}

1;
