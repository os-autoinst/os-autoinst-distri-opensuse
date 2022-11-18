# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Module to install tar package via transactional-update. The system is
# rebooted so changes take effect.

# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use transactional;

sub run {
    select_console 'root-console';

    record_info 'Install tar', 'Install package tar using transactional server and reboot';
    trup_install "tar";
}

1;
