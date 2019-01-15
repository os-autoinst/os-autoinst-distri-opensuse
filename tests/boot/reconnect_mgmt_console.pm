# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Reconnect management-consoles after reboot
# Maintainer: Matthias Grießmeier <mgriessmeier@suse.de>

use strict;
use warnings;
use base "installbasetest";
use utils 'reconnect_mgmt_console';

sub run {
    reconnect_mgmt_console;
}

1;
