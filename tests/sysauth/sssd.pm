# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test the integration between SSSD and its various backends - file database, LDAP, and Kerberos
# Maintainer: HouzuoGuo <guohouzuo@gmail.com>

use base "opensusebasetest";

use strict;
use warnings;

use testapi;
use utils;
use Utils::Systemd 'disable_and_stop_service';
use version;
use version_utils qw(is_sle is_opensuse);
use registration "add_suseconnect_product";

sub run {
    # Assume consoletest_setup is completed
    select_console 'root-console';
    if (is_sle) {
        assert_script_run 'source /etc/os-release';
        if (is_sle '>=15') {
            if (script_run('SUSEConnect -p PackageHub/${VERSION_ID}/${CPU}', 300) != 0) {
                record_soft_failure 'bsc#1124318 - Fail to get PackageHub Pool Metadata - running the command again as a workaround';
                assert_script_run 'SUSEConnect -p PackageHub/${VERSION_ID}/${CPU}', 300;
            }
            add_suseconnect_product('sle-module-legacy');
        }
    }

    # Install test subjects and test scripts
    my @test_subjects = qw(
      sssd sssd-krb5 sssd-krb5-common sssd-ldap sssd-tools
      openldap2 openldap2-client
      krb5 krb5-client krb5-server krb5-plugin-kdb-ldap
    );

    # for sle 12 we still use and support python2
    push @test_subjects, 'python-pam'         if is_sle('<15');
    push @test_subjects, 'python3-python-pam' if is_sle('15+') || is_opensuse;

    disable_and_stop_service('packagekit.service', mask_service => 1, ignore_failure => 1);
    if (check_var('DESKTOP', 'textmode')) {    # sssd test suite depends on killall, which is part of psmisc (enhanced_base pattern)
        zypper_call "in psmisc";
    }
    zypper_call "refresh";
    zypper_call "in @test_subjects";
    assert_script_run "cd; curl -L -v " . autoinst_url . "/data/lib/version_utils.sh > /usr/local/bin/version_utils.sh";
    assert_script_run "cd; curl -L -v " . autoinst_url . "/data/sssd-tests > sssd-tests.data && cpio -id < sssd-tests.data && mv data sssd && ls sssd";

    # Get sssd version, as 2.0+ behaves differently
    my $sssd_version = script_output('rpm -q sssd --qf \'%{VERSION}\'');

    # The test scenarios are now ready to run
    my @scenario_failures;

    my @scenario_list;
    push @scenario_list, 'local' if (version->parse($sssd_version) < version->parse(2.0.0));    # sssd 2.0+ removed support of 'local'
    push @scenario_list, qw(
      ldap
      ldap-no-auth
      ldap-nested-groups
      krb
    );

    foreach my $scenario (@scenario_list) {
        # Download the source code of test scenario
        script_run "cd ~/sssd && curl -L -v " . autoinst_url . "/data/sssd-tests/$scenario > $scenario/cdata";
        script_run "cd $scenario && cpio -idv < cdata && mv data/* ./; ls";
        validate_script_output "./test.sh", sub {
            (/junit testsuite/ && /junit success/ && /junit endsuite/) or push @scenario_failures, $scenario;
        }, 120;
    }
    if (@scenario_failures) {
        die "Some test scenarios failed: @scenario_failures";
    }
}

1;
