# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Update IBM's Trusted Computing Group Software Stack (TSS) to the latest version.
#          IBM has tested x86_64, s390x and ppc64le, we only need cover aarch64
#          This test module covers basic function test
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#101088, poo#102792, poo#103086, tc#1769800

use base 'opensusebasetest';
use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use version_utils 'is_sle';
use registration 'add_suseconnect_product';

sub run {
    my $self = shift;

    select_console('root-console');
    # Install required develop packages
    if (is_sle('>=15')) {
        add_suseconnect_product('sle-module-desktop-applications');
        add_suseconnect_product('sle-module-development-tools');
    }
    zypper_call('in -t pattern devel_basis');
    zypper_call('in openssl-devel');

    # Install emulated tpm server
    zypper_call('in ibmswtpm2');

    # Swith to root console to start tpm server in backaround
    my $tpm_spid;
    if (is_sle) {
        $tpm_spid = background_script_run('/usr/lib/ibmtss/tpm_server');
    }
    else {
        $tpm_spid = background_script_run('/usr/libexec/ibmtss/tpm_server');
    }

    # Download the test script, which is imported from link 'https://git.code.sf.net/p/ibmtpm20tss/tssi'
    $self->select_serial_terminal;

    assert_script_run('git clone https://git.code.sf.net/p/ibmtpm20tss/tss ibmtpm20tss-tss', timeout => 240);
    assert_script_run('cd ibmtpm20tss-tss/utils');
    assert_script_run('make -f makefiletpmc', timeout => 120);

    # Modify the script to use the binaries installed in current system
    assert_script_run q(sed -i 's#^PREFIX=.*#PREFIX=/usr/bin/tss#g' reg.sh);

    # Modify the rootcerts.txt to use the existing pem files
    assert_script_run q(sed -i "s#/gsa/yktgsa/home/k/g/kgold/tpm2/utils#$PWD#" certificates/rootcerts.txt);

    # Run the script
    assert_script_run('export TPM_INTERFACE_TYPE=socsim');
    my $tsslog = '/tmp/tss.log';
    script_run("./reg.sh -a | tee $tsslog", timeout => 240);
    upload_logs("$tsslog");

    # Check the test result
    assert_script_run("cat $tsslog | grep 'Success - 35 Tests 0 Warnings'");

    # Clean up
    assert_script_run('cd; rm -rf ibmtpm20tss-tss');
    assert_script_run("kill -9 $tpm_spid");
}

1;
