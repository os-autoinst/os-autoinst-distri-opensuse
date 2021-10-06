# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: virt_autotest: Virtualization multi-machine job : Guest Migration
# Maintainer: jerry <jtang@suse.com>

use base multi_machine_job_base;
use strict;
use warnings;
use testapi;
use guest_migration_base;

sub run {
    my ($self) = @_;

    #Keep the guest after succeed install
    $self->execute_script_run($guest_install_prepare_keep_guest, 500);

    #perform the installation
    for my $guest (split(",", $guest_os)) {
        $self->execute_script_run("$install_script $guest", 3600);
        save_screenshot;
    }
}
1;
