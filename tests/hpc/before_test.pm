# SUSE's openQA tests
#
# Copyright © 2017-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary:  Basic preparation before any HPC test
# Maintainer: Sebastian Chlad <schlad@suse.de>

use base 'hpcbase';
use base 'hpc::cluster';
use strict;
use warnings;
use testapi;
use utils;
use lockapi;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    # disable packagekitd
    pkcon_quit();

    # Stop firewall
    systemctl 'stop ' . $self->firewall;

    $self->provision_cluster();

    set_hostname(get_var('HOSTNAME', 'susetest'));

    if (get_var('HPC_REPO')) {
        my $repo     = get_var('HPC_REPO');
        my $reponame = get_required_var('HPC_REPONAME');
        zypper_call("ar -f $repo $reponame");
        assert_script_run "zypper lr | grep $reponame";

        zypper_call("--gpg-auto-import-keys ref");
        zypper_call 'up';
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
