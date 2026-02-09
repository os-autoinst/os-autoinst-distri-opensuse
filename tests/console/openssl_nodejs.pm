# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: OpenSSL update regression test using NodeJS tls and crypto tests
#          The test will:
#          - Check the latest nodejs package and sources available and install it
#          - Apply patches to the sources
#          - Run the crypto and tls tests.
#          - List eventually skipped and failed test
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use repo_tools 'generate_version';
use version_utils qw(is_sle);

sub run {
    #Preparation
    select_serial_terminal;

    my $os_version = generate_version();
    my $source_repo;
    if (zypper_call('se -t srcpackage nodejs', exitcode => [0, 104]) == 104) {
        record_info('Source package not found', 'Enable the Source Pool');
        set_var('ENABLE_SRC_REPO', 1);
        $source_repo = script_output(q{zypper lr | grep Source-Pool | awk -F '|' '/Web_and_Scripting_Module/ {print $2}'}) if (is_sle('<16.0'));
        $source_repo = script_output(q{zypper lr | grep Source | awk -F '|' '/SLE-Product-SLES/ {print $2}'}) if (is_sle('>=16.0'));
        zypper_call("mr -e $source_repo", exitcode => [0, 3]);
    }
    assert_script_run 'wget --quiet ' . data_url('qam/crypto_rsa_dsa.patch') unless get_var('FLAVOR') =~ /TERADATA/ || is_sle('=12-sp5') || is_sle('=15-sp4');
    assert_script_run 'wget --quiet ' . data_url('console/test_openssl_nodejs.sh');
    assert_script_run 'chmod +x test_openssl_nodejs.sh';
    assert_script_run "./test_openssl_nodejs.sh $os_version", 900;
    zypper_call("mr -d $source_repo", exitcode => [0, 3]) if get_var('ENABLE_SRC_REPO', 0);
}

1;
