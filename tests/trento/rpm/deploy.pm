# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Prepare the SUT to deploy Trento from RPM packages
# Packages: ansible-trento
# Maintainer: Trento team <trento-developers@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use trento::rpm;

sub run {
    select_serial_terminal;

    trento_rpm_install_ansible_trento();
}

sub test_flags {
    return {fatal => 1};
}

1;
