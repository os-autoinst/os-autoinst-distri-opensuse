# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: pacemaker-cli
# Summary: Check cluster integrity
# Maintainer: Christian Lanig <clanig@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster;
use utils 'systemctl';

sub run {
    select_console 'root-console';
    # Check for the state of the whole cluster
    check_cluster_state;
}

1;
