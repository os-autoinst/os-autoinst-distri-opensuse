# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: snapper
# Summary: Check post-installation snapshot
# - Parse system variables and define snapshot type and description
# - Using the type and description, check if snapshot was already created
# Maintainer: QE Core <qe-core@suse.de>
# Tags: fate#317973, bsc#935923

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal;
use version_utils qw(is_jeos is_sle);

sub run {
    select_serial_terminal;

    # Check if the corresponding snapshot is there
    my ($snapshot_desc, $snapshot_type);
    if (is_jeos) {
        $snapshot_desc = (is_sle('<=15-sp1')) ? 'Initial Status' : 'After jeos-firstboot configuration';
        $snapshot_type = 'single';
    }
    elsif (get_var('AUTOUPGRADE')) {
        $snapshot_desc = 'before update';
        $snapshot_type = 'pre-post';
    }
    elsif (get_var('ONLINE_MIGRATION')) {
        $snapshot_desc = 'before online migration';
        $snapshot_type = 'pre-post';
    }
    else {
        $snapshot_desc = 'after installation';
        $snapshot_type = 'single';
    }
    assert_script_run("snapper list --type $snapshot_type | tee -a /dev/$serialdev | grep '$snapshot_desc.*important=yes'");
}

1;
