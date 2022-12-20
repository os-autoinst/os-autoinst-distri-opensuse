# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: liboauth test for FIPS integration test
#
# Description: liboauth is a collection of c functions implementing the
#              http://oauth.net API. liboauth provides functions to escape
#              and encode stings according to OAuth specifications  and
#              offers high-level functionality built on top to sign requests
#              or verify signatures using either NSS or OpenSSL for calculating
#              the hash/signatures.
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#81260, tc#1767540

use base "consoletest";
use testapi;
use utils;
use utils "zypper_call";
use strict;
use warnings;
use registration qw(add_suseconnect_product cleanup_registration register_product);

sub run {
    select_console 'root-console';

    zypper_output();

    # Since we use the functional group qcow2 which is registered to proxyscc
    # The Source RPM packages are all located in SCC source pool repository
    # Step 1. SUSEConnect -d deregister from proxyscc
    # Step 2. SUSEConnect -r <CODE> to SCC
    # Step 3. SUSEConnect -p module to add DEV tool and Desktop App modules

    # De-register the system from proxyscc due to source RPM package does not mirror to proxyscc
    cleanup_registration();
    zypper_output();

    # Register to official SCC(https://scc.suse.com) to get source RPM packages
    register_product();
    zypper_output();

    # Add Desktop Applications Module
    add_suseconnect_product("sle-module-desktop-applications");

    # Add Development Tool Modules
    add_suseconnect_product("sle-module-development-tools");

    zypper_output();

    # enable source repositories to get latest source packages
    assert_script_run('for r in `zypper lr|awk \'/Source-Pool/ {print $5}\'`; do zypper mr -e --refresh $r; done');
    zypper_output();

    # Install the liboauth source RPM package
    zypper_call('in -t srcpackage liboauth');
    assert_script_run('rpm -qi liboauth0');

    # rpm-build is from Development Tools Module 15 SP3 repo
    # Need to register and Install to Devleopment Tool module first
    # libcurl-devel & libtool need to be installed due to liboauth dependency
    # libopenssl-devel is required to build liboauth
    # zypper in libcurl-devel ( Development files for the curl library)
    # zypper in libtool (A Tool to Build Shared Libraries)
    zypper_call('in rpm-build libcurl-devel libopenssl-devel libtool');

    # Use rpmbuild tool to Compile liboauth
    assert_script_run('cd /usr/src/packages');
    assert_script_run('rpmbuild -bc SPECS/liboauth.spec', 2000);

    # Run liboauth self-tests
    assert_script_run('cd /usr/src/packages/BUILD/liboauth-*/ && pwd');
    # Execute 'make check' to do the self-tests check
    validate_script_output "make check 2>&1 || true", sub { m/PASS:  3/ };

}

sub zypper_output {
    zypper_call("ref", timeout => 1200);
    zypper_call('lr');
    zypper_call('lr -u');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
