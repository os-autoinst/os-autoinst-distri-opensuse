# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Exit startshell.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;


sub run {
    assert_screen 'startshell', 90;
    enter_cmd "exit";
}

1;
