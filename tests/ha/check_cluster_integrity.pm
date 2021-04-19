# SUSE's openQA tests
#
# Copyright (c) 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
