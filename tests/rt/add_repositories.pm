# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Add RT repositories for kernel installation.
# Maintainer: Kernel QE <kernel-qa@suse.de>


use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_ar);

sub run {
    select_serial_terminal;
    # Add repositories if they are requested
    zypper_ar(get_var('REPO_RT_IMAGES'), name => 'repo_rt_images') if get_var('REPO_RT_IMAGES');
    zypper_ar(get_var('REPO_RT_STANDARD'), name => 'repo_rt_standard') if get_var('REPO_RT_STANDARD');
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Notes

=head2 REPO_RT_IMAGES
http://download.suse.de/ibs/SUSE:/SLE-15-SP3:/Update:/Products:/SLERT/images/repo/SLE-15-SP3-Module-RT-POOL-x86_64-Media1/

=head2 REPO_RT_STANDARD
http://download.suse.de/ibs/SUSE:/SLE-15-SP3:/Update:/Products:/SLERT/standard/

=cut
