# SUSE's openQA tests
#
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm support fully, xen support not done yet
# Maintainer: alice <xlai@suse.com>

use strict;
use warnings;
use base "virt_autotest_base";
use virt_autotest::utils;
use testapi;
use Utils::Architectures;
use version_utils qw(is_sle);
use virt_utils;
use utils;
use Utils::Backends 'is_remote_backend';
use virt_autotest::utils qw(is_xen_host subscribe_extensions_and_modules);

sub install_package {

    my $qa_server_repo = get_var('QA_HEAD_REPO', '');
    if ($qa_server_repo eq '') {
        #default repo according to version if not set from testsuite
        $qa_server_repo = 'http://dist.nue.suse.com/ibs/QA:/Head/SLE-' . get_var('VERSION');
        set_var('QA_HEAD_REPO', $qa_server_repo);
        bmwqemu::save_vars();
    }
    if (is_s390x) {
        lpar_cmd("zypper --non-interactive rr server-repo");
        lpar_cmd("zypper --non-interactive --no-gpg-checks ar -f '$qa_server_repo' server-repo");
    }
    else {
        script_run "zypper --non-interactive rr server-repo";
        zypper_call("--no-gpg-checks ar -f '$qa_server_repo' server-repo");
    }

    #workaround for dependency on xmlstarlet for qa_lib_virtauto on sles11sp4 and sles12sp1
    #workaround for dependency on bridge-utils for qa_lib_virtauto on sles15sp0
    my $repo_0_to_install = get_var("REPO_0_TO_INSTALL", '');
    my $dependency_repo = '';
    my $dependency_rpms = '';
    if ($repo_0_to_install =~ /SLES-11-SP4/m) {
        $dependency_repo = 'http://download.suse.de/ibs/SUSE:/SLE-11:/Update/standard/';
        $dependency_rpms = 'xmlstarlet';
    }
    elsif ($repo_0_to_install =~ /SLE-12-SP1/m) {
        $dependency_repo = 'http://download.suse.de/ibs/SUSE:/SLE-12:/Update/standard/';
        $dependency_rpms = 'xmlstarlet';
    }
    elsif ($repo_0_to_install =~ /SLE-15-Installer/m) {
        $dependency_repo = 'http://download.suse.de/ibs/SUSE:/SLE-15:/GA/standard/';
        $dependency_rpms = 'bridge-utils';
    }

    if ($dependency_repo) {
        if (is_s390x) {
            lpar_cmd("zypper --non-interactive --no-gpg-checks ar -f ${dependency_repo} dependency_repo");
            lpar_cmd("zypper --non-interactive --gpg-auto-import-keys ref");
            lpar_cmd("zypper --non-interactive in $dependency_rpms");
            lpar_cmd("zypper --non-interactive rr dependency_repo");
        }
        else {
            zypper_call("--no-gpg-checks ar -f ${dependency_repo} dependency_repo");
            zypper_call("--gpg-auto-import-keys ref", 180);
            zypper_call("in $dependency_rpms");
            zypper_call("rr dependency_repo");
        }
    }

    ###Install KVM role patterns for aarch64 virtualization host
    if (is_remote_backend && is_aarch64) {
        zypper_call("--gpg-auto-import-keys ref", timeout => 180);
        zypper_call("in -t pattern kvm_server kvm_tools", timeout => 300);
    }

    #install qa_lib_virtauto
    if (is_s390x) {
        lpar_cmd("zypper --non-interactive --gpg-auto-import-keys ref");
        my $pkg_lib_data = "qa_lib_virtauto-data";
        my $cmd = "rpm -q $pkg_lib_data";
        my $ret = console('svirt')->run_cmd($cmd);
        if ($ret == 0) {
            lpar_cmd("zypper --non-interactive rm $pkg_lib_data");
        }
        lpar_cmd("zypper --non-interactive in qa_lib_virtauto");
    }
    else {
        zypper_call("--gpg-auto-import-keys ref", 180);
        zypper_call("in qa_lib_virtauto", 1800);
    }

    if (get_var("PROXY_MODE")) {
        if (is_xen_host) {
            zypper_call("in -t pattern xen_server", 1800);
        }
    }

    virt_autotest::utils::install_default_packages();

    ###Install required package for window guest installation on xen host
    if (get_var('GUEST_LIST') =~ /^win-.*/ && (is_xen_host)) { zypper_call '--no-refresh --no-gpg-checks in mkisofs' }

    #Subscribing packagehub from SLE 15-SP4 onwards that enables access to many useful software tools
    virt_autotest::utils::subscribe_extensions_and_modules(reg_exts => 'PackageHub') if (is_sle('>=15-sp4') and !is_s390x);
}

sub run {
    install_package;
}


sub test_flags {
    return {fatal => 1};
}

1;

