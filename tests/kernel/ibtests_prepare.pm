# SUSE's openQA tests
#
# Copyright  SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: ibtests_prepare
# Summary: prepare for InfiniBand test suite hpc-testing
#
# Maintainer: Michael Moese <mmoese@suse.de>, Nick Singer <nsinger@suse.de>, ybonatakis <ybonatakis@suse.com>

use Mojo::Base qw(opensusebasetest);
use Utils::Backends;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use power_action_utils 'power_action';
use version_utils;
use registration;
use mmapi;
use repo_tools 'add_qa_head_repo';

sub run {
    my $role = get_required_var('IBTEST_ROLE');
    my $packages = "rdma-core rdma-ndd iputils";
    my $packages_master = $packages . " git-core bc";


    select_serial_terminal;
    permit_root_ssh_in_sol unless is_sle('16+');

    # unload firewall. MPI- and libfabric-tests require too many open ports
    systemctl("disable --now " . opensusebasetest::firewall);

    # create a ssh key if we don't have one
    script_run('[ ! -f /root/.ssh/id_rsa ] && ssh-keygen -b 2048 -t rsa -q -N "" -f /root/.ssh/id_rsa');

    if (is_sle) {
        if (is_phub_ready) {
            add_suseconnect_product(get_addon_fullname('phub'));
        } else {
            record_info('Warning', 'stress-ng from QA repo');
            add_qa_head_repo(priority => 100);    # needed when phub is not yet available
        }
    }

    add_qa_head_repo(priority => 100);

    zypper_ar(get_var('SCIENCE_HPC_REPO'), no_gpg_check => 1, priority => 49) if get_var('SCIENCE_HPC_REPO', '');
    zypper_call("ref");
    zypper_call("dup --allow-vendor-change");
    $packages = $packages_master if $role eq 'IBTEST_MASTER';

    zypper_call("in $packages", exitcode => [0, 65, 107]);

    power_action('reboot', textmode => 1, keepconsole => 1);
}

1;
