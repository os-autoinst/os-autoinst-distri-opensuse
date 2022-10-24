# SUSE's Apache regression test
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rpm aaa_base
# Summary: Test functionality of the rpm tool:
#  * List all packages
#  * Simple query for a package
#  * List files in a package
#  * Get detailed information for a package
#  * Read changelog of a package
#  * List what a package provides
#  * List contents of an RPM package
#  * List all packages that require a given package
#  * Dump basic file information of every file in a package
#  * List requirements of an RPM package
#  * Check if installation of a package will go through, do not actually install
#  * Install an RPM package
#  * Uninstall an already installed package
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils 'zypper_call';
use File::Basename 'basename';

sub run {
    select_serial_terminal;
    my $dir_prefix = '/tmp/';
    my @test_pkgs = map { $dir_prefix . $_ } qw(openqa_rpm_test-1.0-0.noarch.rpm aaa_base.rpm);

    # Download dummy test packages
    # wget is not present in opensuse-15.1
    assert_script_run("curl -o ${dir_prefix}openqa_rpm_test-1.0-0.noarch.rpm " . autoinst_url . "/data/rpm/openqa_rpm_test-1.0-0.noarch.rpm");
    # Package openqa_rpm_test-1.0-0.noarch.rpm is signed by custom key
    # Upload and import it to rpm
    assert_script_run("curl -o ${dir_prefix}openqa_test_rpm_pub.asc " . autoinst_url . "/data/rpm/openqa_test_rpm_pub.asc");
    assert_script_run('rpm --import ' . $dir_prefix . 'openqa_test_rpm_pub.asc');
    # Pull and store aaa_base in zypper's cache
    zypper_call 'in -fy --download-only aaa_base';
    assert_script_run "mv `find /var/cache/zypp/packages/ | grep aaa_base | head -n1` ${dir_prefix}aaa_base.rpm";
    # List all packages
    assert_script_run 'rpm -qa';

    foreach my $pkg (@test_pkgs) {
        record_info($pkg, script_output qq[ rpm -qpi $pkg]);
        # Verify that the package has not been corrupted
        assert_script_run("rpm -Kv $pkg",
            fail_message => "Signature or digest does not match!\nPackage might be corrupted!");
        # List contents of an RPM package
        assert_script_run("rpm -qlp $pkg");
        # List requirements of an RPM package
        assert_script_run("rpm -qp --requires $pkg");
        # Check if installation of a package will go through, then try real rpm deployment
        unless (script_run("rpm --test -ivh $pkg")) {
            # Install an RPM package
            assert_script_run("rpm -ivh $pkg");
        }
        # Get rid of suffix, package has been already installed
        my $installed_pkg = basename($pkg, '.rpm');
        # Simple query for a package
        assert_script_run("rpm -q $installed_pkg");
        # List files in a package
        assert_script_run("rpm -ql $installed_pkg");
        # Get detailed information for a package
        assert_script_run("rpm -qi $installed_pkg");
        # Read changelog of a package
        assert_script_run("rpm -q --changelog $installed_pkg | tail -n 40", 90);
        # List what a package provides
        assert_script_run("rpm -q --provides $installed_pkg");
        # Dump basic file information of every file in a package
        assert_script_run("rpm -q --dump $installed_pkg");
        # List all packages that require a given package
        # Custom openqa_rpm_test package does not require any deps, therefore rpm returns false
        # And is not required by any other package
        if ((script_run("rpm -q --whatrequires $installed_pkg")) and ($pkg =~ /aaa_base/)) {
            die "There should be at least one dependent package on \'aaa_base\'\n";
        }
        # Uninstall an already installed package
        # aaa_base has to fail due to external deps
        if (script_run("rpm -evh $installed_pkg")) {
            if ($pkg =~ /openqa_rpm_test/) {
                die "\'openqa_rpm_test\' was not removed!\n";
            } else {
                record_info('Fail', "Expected on $pkg\nPackage cannot be removed!");
            }
        } else {
            record_info('Removed!', $installed_pkg);
        }
        # Install the custom package again
        if (script_run("rpm -Uvh $pkg")) {
            if ($pkg =~ /openqa_rpm_test/) {
                die "Could not install \'openqa_rpm_test\'!\n";
            } else {
                record_info('Fail', "Expected on $pkg\nPackage cannot be installed!");
            }
        } else {
            record_info('Installed!', $installed_pkg);
        }
    }
    # Execute installled script
    assert_script_run('/opt/openqa_tests/openqa_rpm_test.sh');
    assert_script_run('rpm -e openqa_rpm_test-1.0-0');
    # get previously imported custom key
    # we are interested in the first column
    my $key_id = (split('\s+',
            script_output(
                q[rpm -q gpg-pubkey --qf '%{NAME}-%{VERSION}-%{RELEASE}\t%{SUMMARY}\n' | grep openqa_rpm_owner]
            )
        )
    )[0];
    # Remove previously imported custom key
    assert_script_run("rpm -e $key_id");

}

1;

