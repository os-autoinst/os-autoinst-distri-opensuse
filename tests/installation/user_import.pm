# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Use existing encrypted volume and import old users rather than
#   configure new ones
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    assert_screen 'import-user-data';
    send_key 'alt-i';
    send_key 'alt-e';
    assert_screen 'import-user-data-selection';
    send_key 'alt-a';
    assert_screen 'import-user-data-selected-user';
    send_key $cmd{ok};

    send_key $cmd{next};
}

1;
