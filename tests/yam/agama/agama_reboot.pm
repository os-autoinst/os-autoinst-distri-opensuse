## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Use single module that handle reboot for all architectures
# integration test from GitHub.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "installbasetest";
use testapi qw(get_var);
use Utils::Architectures;
use utils 'reconnect_mgmt_console';

sub run {
    reconnect_mgmt_console if is_s390x;
}

1;
