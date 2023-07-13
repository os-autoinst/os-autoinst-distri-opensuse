# SUSE's openQA tests - FIPS tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: run upstream libica testsuite (build time) on s390x with enabled FIPS mode
# Maintainer: QE Security <none@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use Utils::Architectures 'is_s390x';
use registration qw(cleanup_registration register_product add_suseconnect_product);

sub run {
    return unless is_s390x();
    select_serial_terminal;
    # we need to add development tools to compile
    add_suseconnect_product('sle-module-desktop-applications');
    add_suseconnect_product('sle-module-development-tools');
    zypper_call('in libica rpmbuild autoconf automake fipscheck gcc-c++ libtool openssl-devel');
    my $version = get_required_var('VERSION');
    my $repourl = "https://download.suse.de/ibs/SUSE:/SLE-$version:/GA/standard/SUSE:SLE-$version:GA.repo";
    assert_script_run("cd /etc/zypp/repos.d ; curl -k $repourl -O");
    zypper_call('si libica');
    # build output should have FAIL: 0 and ERROR: 0, as example:
    #============================================================================
    #Testsuite summary for libica 4.2.1
    #============================================================================
    # TOTAL: 55
    # PASS:  33
    # SKIP:  22
    # XFAIL: 0
    # FAIL:  0
    # XPASS: 0
    # ERROR: 0
    #============================================================================
    validate_script_output 'rpmbuild -ba /usr/src/packages/SPECS/libica.spec',
      sub { m/Testsuite summary for libica.+XFAIL:\s+0.+FAIL:\s+0.+ERROR:\s+0/s },
      timeout => 600;
}

sub post_run_hook {
    zypper_call("rr libica-tests");
}

1;
