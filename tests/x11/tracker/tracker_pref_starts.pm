# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: tracker
# Summary: start preference of tracker
# Maintainer: nick wang <nwang@suse.com>
# Tags: tc#1436344

use base "x11test";
use testapi;


sub run {
    x11_start_program('tracker-preferences');
    send_key "alt-f4";
}

1;
