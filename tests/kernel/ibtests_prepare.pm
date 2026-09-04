# SUSE's openQA tests
#
# Copyright  SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: ibtests_prepare
# Summary: prepare for InfiniBand test suite hpc-testing
#
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use Utils::Backends;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use power_action_utils 'power_action';
use version_utils;
use registration;
use mmapi;
use repo_tools 'add_qa_head_repo';
use package_utils 'install_package';

sub run {
    my $role = get_required_var('IBTEST_ROLE');
    my $install = get_var('IBTEST_INSTALL', 'from_repo');
    my $packages = "rdma-core rdma-ndd iputils";
    my $packages_master = $packages . " git-core bc";


    select_serial_terminal;
    permit_root_ssh_in_sol unless is_sle('16+');

    # unload firewall. MPI- and libfabric-tests require too many open ports
    systemctl("disable --now " . opensusebasetest::firewall);

    # create a ssh key if we don't have one
    script_run('[ ! -f /root/.ssh/id_rsa ] && ssh-keygen -b 2048 -t rsa -q -N "" -f /root/.ssh/id_rsa');

    if (is_sle() && is_phub_ready()) {
        add_suseconnect_product(get_addon_fullname('phub'));
    }

    add_qa_head_repo(priority => 100);
    zypper_call("ref");
    zypper_call("dup --allow-vendor-change");
    $packages = $packages_master if $role eq 'IBTEST_MASTER';

    zypper_call("in $packages", exitcode => [0, 65, 107]);

    if ($role eq 'IBTEST_MASTER') {
        if ($install =~ /git/i) {
            my $hpc_testing = get_var('IBTEST_GITTREE', 'https://github.com/SUSE/hpc-testing.git');
            my $hpc_testing_branch = get_var('IBTEST_GITBRANCH', 'master');
            assert_script_run("git clone $hpc_testing --branch $hpc_testing_branch", timeout => get_var('IBTEST_TIMEOUT', '3600'));
        } else {
            install_package('hpc-testing', trup_apply => 1);
        }
    }

    power_action('reboot', textmode => 1, keepconsole => 1);
}

1;

=head1 Description

Prepares the machines for the InfiniBand test suite hpc-testing: adds the
required repositories, installs the required packages, unloads the
firewall, creates a SSH key if needed and reboots. On the master, also
fetches hpc-testing itself, either as an RPM (default) or via git, mainly
useful for debugging.

=head1 Configuration

=head2 IBTEST_ROLE

Role of the machine, either C<IBTEST_MASTER> or C<IBTEST_SLAVE>. Only the
master role additionally installs C<git-core> and C<bc>, and fetches the
hpc-testing testsuite, since only the master runs it.

=head2 IBTEST_INSTALL

Installation method for the hpc-testing suite, shared with ibtests.pm.
Defaults to C<from_repo>, which installs the C<hpc-testing> RPM from
QA:Head (see C<add_qa_head_repo>) on the master. Set to C<from_git> to
clone the testsuite from C<IBTEST_GITTREE> instead.

=head2 IBTEST_GITTREE

The hpc-testing git repository. Used only with C<IBTEST_INSTALL=from_git>.
Default: https://github.com/SUSE/hpc-testing.git

=head2 IBTEST_GITBRANCH

The hpc-testing git branch to checkout. Used only with
C<IBTEST_INSTALL=from_git>.
Default: master

=head2 IBTEST_TIMEOUT

Timeout in seconds for cloning the hpc-testing repository. Used only with
C<IBTEST_INSTALL=from_git>. Also used by ibtests.pm as the test run
timeout.
Default: 3600 (1 hour)
