# SUSE's openQA tests
#
# Copyright 2018-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: git-core twopence-shell-client bc iputils python
# Summary: run InfiniBand test suite hpc-testing
#
# Maintainer: Michael Moese <mmoese@suse.de>, Nick Singer <nsinger@suse.de>, ybonatakis <ybonatakis@suse.com>

use Mojo::Base qw(opensusebasetest);
use Utils::Backends;
use testapi;
use utils;
use power_action_utils 'power_action';
use lockapi;
use version_utils;
use mmapi;

sub run {
    my $self = shift;
    my $master = get_required_var('IBTEST_IP1');
    my $slave = get_required_var('IBTEST_IP2');

    my $role = get_required_var('IBTEST_ROLE');
    my $packages = "rdma-core rdma-ndd iputils python";
    my $packages_master = $packages . " git-core twopence-shell-client bc";


    $self->select_serial_terminal;
    permit_root_ssh_in_sol;

    # unload firewall. MPI- and libfabric-tests require too many open ports
    systemctl("disable --now " . opensusebasetest::firewall);

    # create a ssh key if we don't have one
    script_run('[ ! -f /root/.ssh/id_rsa ] && ssh-keygen -b 2048 -t rsa -q -N "" -f /root/.ssh/id_rsa');


    if ($role eq 'IBTEST_MASTER') {
        zypper_ar(get_required_var('DEVEL_TOOLS_REPO'), no_gpg_check => 1);
        zypper_ar(get_required_var('SCIENCE_HPC_REPO'), no_gpg_check => 1, priority => 50) if get_var('SCIENCE_HPC_REPO', '');
        $packages = $packages_master;
    }

    zypper_call("in $packages", exitcode => [0, 65, 107]);


    power_action('reboot', textmode => 1, keepconsole => 1);


}

1;
