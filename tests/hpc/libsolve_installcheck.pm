# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Checking if it is possible to install packages in repo with libsolv
# Maintainer: Sebastian Chlad <schlad@suse.de>

use base "opensusebasetest";
use testapi;
use utils;
use strict;
use warnings;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    my $installcheck_script = 'installcheck_hpc_module.sh';
    assert_script_run("wget --quiet " . data_url("hpc/$installcheck_script") . " -O $installcheck_script");
    assert_script_run("chmod +x $installcheck_script");
    my $rez = script_run("./$installcheck_script " . get_required_var('ARCH') . ' ' . get_required_var('VERSION') . " > result.txt");
    if ($rez != 0) {
        upload_logs('./result.txt', failok => 1);
        die('There are failures! Check result.txt for details');
    }
}

1;
