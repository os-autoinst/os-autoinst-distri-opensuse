# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: transactional-update
# Summary: Installation of K3s
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use serial_terminal qw(select_serial_terminal);
use containers::k8s qw(install_k3s);

sub run {
    select_serial_terminal;

    install_k3s();
}

sub test_flags {
    return {no_rollback => 1, fatal => 1, milestone => 1};
}

1;
