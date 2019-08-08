# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Setup a convenience SSH tunnel setup to a remote lab hardware for
#  test execution
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: https://progress.opensuse.org/issues/49901

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use Remote::Lab 'setup_ssh_tunnels';


sub run {
    my ($self) = @_;
    select_console 'tunnel-console';
    setup_ssh_tunnels();
}

1;
