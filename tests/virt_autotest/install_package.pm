# SUSE's openQA tests
#
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm support fully, xen support not done yet
# Maintainer: alice <xlai@suse.com>

use base "virt_autotest_base";
use virt_autotest::utils;
use testapi;
use Utils::Architectures;
use version_utils qw(is_sle);
use virt_utils;
use utils;
use Utils::Backends qw(use_ssh_serial_console is_remote_backend);
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

    #Install KVM role patterns for aarch64 virtualization host
    if (is_remote_backend && is_aarch64) {
        zypper_call("--gpg-auto-import-keys ref", timeout => 180);
        zypper_call("in -t pattern kvm_server kvm_tools", timeout => 300);
    }

    #Install qa_lib_virtauto
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

    virt_autotest::utils::install_default_packages() unless get_var('AUTOYAST');

    #Install required package for window guest installation on xen host
    if (get_var('GUEST_LIST', '') =~ /^win-.*/ && (is_xen_host)) { zypper_call '--no-refresh --no-gpg-checks in mkisofs' }

    #Subscribing packagehub from SLE 15-SP4 onwards that enables access to many useful software tools
    virt_autotest::utils::subscribe_extensions_and_modules(reg_exts => 'PackageHub') if (!get_var('AUTOYAST') and is_sle('>=15-sp4') and !is_s390x);

    #Switch all VM Passwords from installed settings files
    my $setting_file = "/usr/share/qa/virtautolib/data/settings." . locate_sourcefile;
    my $qa_password = $testapi::password;
    my $vm_password = get_var('VIRTAUTO_VM_PASSWORD');
    my $cmd = "sed -i -e 's/vm.pass=/vm.pass=$vm_password/g' -e 's/xen.pass=/xen.pass=$vm_password/g' -e 's/migratee.pass=/migratee.pass=$vm_password/g' -e 's/vm.sshpassword=/vm.sshpassword=$qa_password/g' $setting_file";
    if (is_s390x) {
        lpar_cmd("$cmd");
    }
    else {
        script_run "$cmd";
    }
}

sub run {
    # Only for x86_64
    if (is_x86_64) {
        select_console 'sol', await_console => 0;
        use_ssh_serial_console;
    }
    install_package;
}


sub test_flags {
    return {fatal => 1};
}

1;

