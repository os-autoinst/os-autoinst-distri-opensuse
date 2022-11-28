# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

package packages;
use Mojo::Base qw(basetest);
use testapi;
use version_utils 'is_transactional';
use transactional 'trup_call';

our @EXPORT = "install_package";

sub install_package {
    my $command = $_[0];
    if (is_transactional) {
        trup_call('pkg in -l ' . $command);
    } else {
        zypper_call('in -l ' . $command);
    }
}
