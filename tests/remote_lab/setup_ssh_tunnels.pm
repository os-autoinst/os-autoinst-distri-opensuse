# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Setup a convenience SSH tunnel setup to a remote lab hardware for
#  test execution
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: https://progress.opensuse.org/issues/49901

use base 'opensusebasetest';
use testapi;
use Remote::Lab 'setup_ssh_tunnels';


sub run {
    my ($self) = @_;
    select_console 'tunnel-console';
    setup_ssh_tunnels();
}

1;
