# SUSE's openQA tests
#
# Copyright 2017-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Login as user test https://progress.opensuse.org/issues/13306
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "x11test";
use testapi;
use x11utils 'handle_relogin';

sub run {
    handle_relogin;
}

1;
