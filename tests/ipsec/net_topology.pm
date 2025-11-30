# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Define the network topology for kernel network tests
# Maintainer: Kernel QE <kernel-qa@suse.de>

# Test requirement and topology can refer following link:
# https://github.com/linux-test-project/ltp/issues/920
# https://www.ipv6ready.org/docs/Phase2_IPsec_Interoperability_Latest.pdf

package net_topology;
use Mojo::Base 'Kernel::net_tests';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use lockapi;
use network_utils;
