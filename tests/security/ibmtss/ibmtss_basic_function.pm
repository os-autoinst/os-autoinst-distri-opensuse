# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Update IBM's Trusted Computing Group Software Stack (TSS) to the latest version.
#          IBM has tested x86_64, s390x and ppc64le, we only need cover aarch64
#          This test module covers basic function test
# Maintainer: QE Security <none@suse.de>
# Tags: poo#101088, poo#102792, poo#103086, poo#106501, tc#1769800, poo#128057, poo#169957

use base 'opensusebasetest';
use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use version_utils qw(is_sle package_version_cmp);

sub run {
    select_console('root-console');

    # Install emulated tpm server and git-core
    zypper_call('in ibmswtpm2 git-core');

    my $tpm_spid = is_sle
      ? background_script_run('/usr/lib/ibmtss/tpm_server')
      : background_script_run('/usr/libexec/ibmtss/tpm_server');

    # Download the test script.
    # Choose correct test suite version to download according to installed package version
    select_serial_terminal;
    my $version = script_output 'rpm -q ibmswtpm2';
    record_info("ibmswtpm2 version: $version");

    # Select the relevant source
    # For SLE we are using our local copy at 'https://gitlab.suse.de/qe-security/ibmtpm20tss'
    # which is cloned from 'https://git.code.sf.net/p/ibmtpm20tss/tssi' to avoid pulling files
    # from the public Internet and avoid possible code injections.
    # poo#169957
    my $git_url = is_sle
      ? '-c http.sslVerify=false https://gitlab.suse.de/qe-security/ibmtpm20tss'
      : 'https://git.code.sf.net/p/ibmtpm20tss/tss';

    assert_script_run("git clone --depth 1 $git_url ibmtpm20tss", timeout => 240);
    assert_script_run('cd ibmtpm20tss/utils');
    assert_script_run('git fetch --tags');
    # poo#128057 : latest upstream testsuite version (2.0) is not compatible with packaged binaries,
    # so let's use the previous stable for <= 15SP6
    my $ntests;
    if (is_sle('<=15-SP6')) {
        assert_script_run('git checkout v1.6.0');
        # Modify the rootcerts.txt to use the existing pem files
        assert_script_run q(sed -i "s#/gsa/yktgsa/home/k/g/kgold/tpm2/utils#$PWD#" certificates/rootcerts.txt);
        # Version 1.6.0 has 35 tests
        $ntests = 35;
    } else {
        assert_script_run('git checkout v2.4.1');
        assert_script_run q(sed -i "s#/home/kgold/tss2/utils#$PWD#" certificates/rootcerts.txt);
        # Version 2.4.1 has 38 tests
        $ntests = 38;
    }

    # Modify the script to use binaries installed in the current system
    assert_script_run("sed -i 's#^PREFIX=.*#PREFIX=/usr/bin/tss#g' reg.sh");

    # Run the script
    my $tsslog = script_output('mktemp /tmp/tss.log.XXXXXX');
    script_run("export TPM_INTERFACE_TYPE=socsim; ./reg.sh -a | tee $tsslog", timeout => 600);
    upload_logs("$tsslog");

    # Check test results
    assert_script_run("cat $tsslog | grep 'Success - $ntests Tests 0 Warnings'");

    # Clean up
    assert_script_run('cd; rm -rf ibmtpm20tss');
    assert_script_run("kill $tpm_spid");
}

1;
