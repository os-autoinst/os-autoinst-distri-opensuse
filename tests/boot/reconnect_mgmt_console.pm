# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Reconnect management-consoles after reboot
# Maintainer: Matthias Grießmeier <mgriessmeier@suse.de>

use base "installbasetest";
use utils 'reconnect_mgmt_console';

sub run {
    reconnect_mgmt_console;
}

1;
