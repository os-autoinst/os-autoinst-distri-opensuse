# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify kernel configuration
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use version_utils;
use Utils::Architectures;

sub run {
    my ($self) = @_;

    # Check for bsc#1260359: Ensure there are no console= arguments on ppc64le for SLES
    validate_script_output("grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub", sub { !m/console=/ }, fail_message => "Console= argument found in GRUB_CMDLINE_LINUX (bsc#1260359)") if (is_sle(">16.0") && is_ppc64le);
}

1;
