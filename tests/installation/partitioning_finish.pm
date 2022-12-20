# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Rework the tests layout.
# - Wait for a screen change
# - Send next and wait for partitioning resume screen
# Maintainer: Alberto Planas <aplanas@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    wait_still_screen();
    send_key $cmd{next};
    wait_still_screen();
    assert_screen "after-partitioning";
}

1;
