# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm support fully, xen support not done yet
# Maintainer: alice <xlai@suse.com>

use strict;
use warnings;
use base "virt_autotest_base";
use testapi;
use virt_utils;

sub install_package {
    my $qa_server_repo = get_var('QA_HEAD_REPO', '');
    if ($qa_server_repo eq '') {
        #default repo according to version if not set from testsuite
        $qa_server_repo = 'http://dist.nue.suse.com/ibs/QA:/Head/SLE-' . get_var('VERSION');
        set_var('QA_HEAD_REPO', $qa_server_repo);
        bmwqemu::save_vars();
    }
    if (check_var('ARCH', 's390x')) {
        lpar_cmd("zypper --non-interactive rr server-repo");
        lpar_cmd("zypper --non-interactive --no-gpg-check ar -f '$qa_server_repo' server-repo");
    }
    else {
        script_run "zypper --non-interactive rr server-repo";
        assert_script_run("zypper --non-interactive --no-gpg-check ar -f '$qa_server_repo' server-repo");
    }

    #workaround for dependency on xmlstarlet for qa_lib_virtauto on sles11sp4 and sles12sp1
    #workaround for dependency on bridge-utils for qa_lib_virtauto on sles15sp0
    my $repo_0_to_install = get_var("REPO_0_TO_INSTALL", '');
    my $dependency_repo   = '';
    my $dependency_rpms   = '';
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
        if (check_var('ARCH', 's390x')) {
            lpar_cmd("zypper --non-interactive --no-gpg-check ar -f ${dependency_repo} dependency_repo");
            lpar_cmd("zypper --non-interactive --gpg-auto-import-keys ref");
            lpar_cmd("zypper --non-interactive in $dependency_rpms");
            lpar_cmd("zypper --non-interactive rr dependency_repo");
        }
        else {
            assert_script_run("zypper --non-interactive --no-gpg-check ar -f ${dependency_repo} dependency_repo");
            assert_script_run("zypper --non-interactive --gpg-auto-import-keys ref", 180);
            assert_script_run("zypper --non-interactive in $dependency_rpms");
            assert_script_run("zypper --non-interactive rr dependency_repo");
        }
    }

    #install qa_lib_virtauto
    if (check_var('ARCH', 's390x')) {
        lpar_cmd("zypper --non-interactive --gpg-auto-import-keys ref");
        lpar_cmd("zypper --non-interactive in qa_lib_virtauto");
    }
    else {
        assert_script_run("zypper --non-interactive --gpg-auto-import-keys ref", 180);
        assert_script_run("zypper --non-interactive in qa_lib_virtauto",         1800);
    }

    if (get_var("PROXY_MODE")) {
        if (get_var("XEN")) {
            assert_script_run("zypper --non-interactive in -t pattern xen_server", 1800);
        }
    }
}

sub run {
    install_package;
}


sub test_flags {
    return {fatal => 1};
}

1;

