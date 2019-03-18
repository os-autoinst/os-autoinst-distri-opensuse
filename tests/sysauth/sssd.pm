# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
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
use version;


sub run {
    # Assume consoletest_setup is completed
    select_console 'root-console';

    # Install test subjects and test scripts
    my @test_subjects = qw(
      python3-python-pam
      sssd sssd-krb5 sssd-krb5-common sssd-ldap sssd-tools
      openldap2 openldap2-client
      krb5 krb5-client krb5-server krb5-plugin-kdb-ldap
    );
    systemctl 'stop packagekit.service';
    systemctl 'mask packagekit.service';
    if (check_var('DESKTOP', 'textmode')) {    # sssd test suite depends on killall, which is part of psmisc (enhanced_base pattern)
        assert_script_run "zypper -n in psmisc";
    }
    script_run "zypper -n refresh && zypper -n in @test_subjects";
    script_run "cd; curl -L -v " . autoinst_url . "/data/sssd-tests > sssd-tests.data && cpio -id < sssd-tests.data && mv data sssd && ls sssd";

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
        script_run "cd ~/sssd && mkdir $scenario && curl -L -v " . autoinst_url . "/data/sssd-tests/$scenario > $scenario/cdata";
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
