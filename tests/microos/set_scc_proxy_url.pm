# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Register the already installed system on a specific SCC server/proxy if needed
# Maintainer: qa-c@suse.de

use base "consoletest";
use strict;
use warnings;
use migration qw(set_scc_proxy_url);

sub run {
    set_scc_proxy_url();
}

1;
