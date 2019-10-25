# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test OpenLDAP 2 using a modified test suite from upstream
# Maintainer: Alexandre Makoto Tanno <atanno@suse.com>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils 'zypper_call';
use version_utils 'is_sle';

my $test_path = '/opt/openldap-tests/tests/';
my @backends  = qw(bdb hdb);
my $version   = '';
my @tests_sle = '';

sub install_openldap2 {
    record_info 'Install OpenLDAP 2';
    zypper_call('in bzip2 openldap2-*');
}

sub prepare_test_suite {
    record_info 'Prepare test suite';
    assert_script_run('cd /opt');
    if (is_sle('>=15')) {
        $version   = '15';
        @tests_sle = qw(test000-rootdse test001-slapadd test002-populate test003-search
          test004-modify test005-modrdn test006-acls test008-concurrency test009-referral
          test010-passwd test011-glue-slapadd test012-glue-populate test013-language
          test014-whoami test015-xsearch test016-subref test017-syncreplication-refresh
          test018-syncreplication-persist test019-syncreplication-cascade test020-proxycache
          test021-certificate test022-ppolicy test023-refint test024-unique test025-limits
          test026-dn test027-emptydn test028-idassert test029-ldapglue test030-relay
          test031-component-filter test032-chain test033-glue-syncrepl test034-translucent
          test035-meta test036-meta-concurrency test037-manage test038-retcode
          test039-glue-ldap-concurrency test040-subtree-rename test041-aci test042-valsort
          test043-delta-syncrepl test044-dynlist test045-syncreplication-proxied
          test046-dds test047-ldap test048-syncrepl-multiproxy test049-sync-config
          test050-syncrepl-multimaster test051-config-undo test052-memberof
          test054-syncreplication-parallel-load test055-valregex test056-monitor
          test057-memberof-refint test058-syncrepl-asymmetric test059-slave-config
          test060-mt-hot test061-syncreplication-initiation test063-delta-multimaster
          test064-constraint test065-proxyauthz
        );
    }
    else {
        $version   = '12';
        @tests_sle = qw(test000-rootdse test001-slapadd test002-populate
          test003-search test004-modify test005-modrdn test006-acls
          test008-concurrency test009-referral test010-passwd test011-glue-slapadd
          test012-glue-populate test013-language test014-whoami test015-xsearch
          test016-subref test017-syncreplication-refresh test018-syncreplication-persist
          test019-syncreplication-cascade test020-proxycache test021-certificate
          test022-ppolicy test023-refint test024-unique test025-limits test026-dn
          test027-emptydn test028-idassert test029-ldapglue test030-relay
          test031-component-filter test032-chain test033-glue-syncrepl
          test034-translucent test035-meta test036-meta-concurrency test037-manage
          test038-retcode test039-glue-ldap-concurrency test040-subtree-rename
          test041-aci test042-valsort test043-delta-syncrepl test044-dynlist
          test045-syncreplication-proxied test046-dds test047-ldap
          test048-syncrepl-multiproxy test049-sync-config test050-syncrepl-multimaster
          test051-config-undo test052-memberof test054-syncreplication-parallel-load
          test055-valregex test056-monitor test057-memberof-refint test058-syncrepl-asymmetric
          test059-slave-config test060-mt-hot test061-syncreplication-initiation
          test063-delta-multimaster test064-constraint
        );
    }
    assert_script_run 'wget ' . data_url('console/openldap-tests-sle_' . $version . '.tar.bz2');
    assert_script_run 'tar jxvf openldap-tests-sle_' . $version . '.tar.bz2';
}

sub run_test_suite {
    foreach my $backend (@backends) {
        foreach my $test (@tests_sle) {
            record_info $test . ' ' . $backend;
            assert_script_run($test_path . 'run -b ' . $backend . ' ' . $test, timeout => 3600);
        }
    }
}

sub run {
    select_console("root-console");
    install_openldap2;
    prepare_test_suite;
    run_test_suite;
}

1;
