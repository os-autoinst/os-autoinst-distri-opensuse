# SUSE's openQA tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary:  Basic preparation before any HPC test
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase hpc::cluster), -signatures;
use testapi;
use utils;
use lockapi;

sub run ($self) {
    $self->select_serial_terminal;

    # disable packagekitd
    quit_packagekit();

    # Stop firewall
    systemctl 'stop ' . $self->firewall;

    $self->provision_cluster();

    set_hostname(get_var('HOSTNAME', 'susetest'));

    if (get_var('HPC_REPO')) {
        my $repo = get_var('HPC_REPO');
        my $reponame = get_required_var('HPC_REPONAME');
        zypper_call("ar -f $repo $reponame");
        assert_script_run "zypper lr | grep $reponame";

        zypper_call("--gpg-auto-import-keys ref");
        zypper_call 'up';
    }
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}
sub post_run_hook ($self) { }

1;
