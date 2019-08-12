# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ensure the ssh daemon is running
# - Check if sshd is started
# - Check if sshd is running
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    systemctl 'show -p ActiveState sshd|grep ActiveState=active';
    systemctl 'show -p SubState sshd|grep SubState=running';
}

1;
