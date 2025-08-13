# SUSE's openQA tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: virt-manager
# Summary: Virtualization virtman installation setup
# Maintainer: aginies <aginies@suse.com>

use base 'x11test';
use testapi;


sub run {
    select_console 'x11';
    ensure_installed('virt-manager');
}

1;

