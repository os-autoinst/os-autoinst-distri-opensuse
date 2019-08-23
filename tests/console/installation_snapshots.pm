# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check post-installation snapshot
# - Parse system variables and define snapshot type and description
# - Using the type and description, check if snapshot was already created
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: fate#317973, bsc#935923

use base 'consoletest';
use strict;
use warnings;
use testapi;
use version_utils "is_jeos";

sub run {
    select_console 'root-console';

    # Check if the corresponding snapshot is there
    my ($snapshot_desc, $snapshot_type);
    if (is_jeos) {
        $snapshot_desc = 'Initial Status';
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
    assert_script_run("snapper list --type $snapshot_type | grep '$snapshot_desc.*important=yes'");
}

1;
