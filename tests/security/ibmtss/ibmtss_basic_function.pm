# Copyright 2021-2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Update IBM's Trusted Computing Group Software Stack (TSS) to the latest version.
#          IBM has tested x86_64, s390x and ppc64le, we only need cover aarch64
#          This test module covers basic function test
# Maintainer: QE Security <none@suse.de>
# Tags: poo#101088, poo#102792, poo#103086, poo#106501, tc#1769800, poo#128057, poo#169957

use base 'opensusebasetest';
use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use version_utils qw{is_sle package_version_cmp};

sub run {
    select_console('root-console');

    # Install emulated tpm server and git-core
    zypper_call('in ibmswtpm2 git-core');

    # Swith to root console to start tpm server in backaround
    my $tpm_spid;
    if (is_sle) {
        $tpm_spid = background_script_run('/usr/lib/ibmtss/tpm_server');
    }
    else {
        $tpm_spid = background_script_run('/usr/libexec/ibmtss/tpm_server');
    }

    # Download the test script.
    # For SLE we are using our local copy at 'https://gitlab.suse.de/qe-security/ibmtpm20tss'
    # which is cloned from 'https://git.code.sf.net/p/ibmtpm20tss/tssi' to avoid pulling files
    # from the public Internet and avoid possible code injections.
    # poo#169957
    select_serial_terminal;

    # choose correct test suite version to download according to installed package
    my $version = script_output 'rpm -q ibmswtpm2';

    # Select the relevant source
    my $git_url = is_sle ? '-c http.sslVerify=false https://gitlab.suse.de/qe-security/ibmtpm20tss' : 'https://git.code.sf.net/p/ibmtpm20tss/tss';

    record_info("ibmswtpm2 version: $version");

    assert_script_run("git clone --depth 1 $git_url ibmtpm20tss", timeout => 240);
    assert_script_run('cd ibmtpm20tss/utils ; git fetch --tags');
    # poo#128057 : latest upstream testsuite version (2.0) is not compatible with packaged binaries,
    # so let's use the previous stable for <= 15SP6
    my $ntests;
    if (is_sle('<=15-SP6')) {
        assert_script_run('git checkout v1.6.0');
        # Modify the rootcerts.txt to use the existing pem files
        assert_script_run q(sed -i "s#/gsa/yktgsa/home/k/g/kgold/tpm2/utils#$PWD#" certificates/rootcerts.txt);
        $ntests = 35;
    } else {
        assert_script_run('git checkout v2.4.1');
        assert_script_run q(sed -i "s#/home/kgold/tss2/utils#$PWD#" certificates/rootcerts.txt);
        $ntests = 38;
    }

    # Modify the script to use the binaries installed in current system
    assert_script_run q(sed -i 's#^PREFIX=.*#PREFIX=/usr/bin/tss#g' reg.sh);

    # Run the script
    assert_script_run('export TPM_INTERFACE_TYPE=socsim');
    my $tsslog = '/tmp/tss.log';
    script_run("./reg.sh -a | tee $tsslog", timeout => 600);
    upload_logs("$tsslog");

    # Check the test result
    # version 1.6.0 has 35 tests, version 2.4.1 has 38
    assert_script_run("cat $tsslog | grep 'Success - $ntests Tests 0 Warnings'");

    # Clean up
    assert_script_run('cd; rm -rf ibmtpm20tss');
    assert_script_run("kill -9 $tpm_spid");
}

1;
