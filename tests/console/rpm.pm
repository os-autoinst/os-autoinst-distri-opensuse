# SUSE's Apache regression test
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
use strict;
use warnings;
use utils 'zypper_call';

sub run {
    select_console 'root-console';

    # List all packages
    assert_script_run 'rpm -qa';

    # Simple query for a package
    assert_script_run 'rpm -q aaa_base';

    # List files in a package
    assert_script_run 'rpm -ql aaa_base';

    # Get detailed information for a package
    assert_script_run 'rpm -qi aaa_base';

    # Read changelog of a package
    assert_script_run 'rpm -q --changelog aaa_base';

    # List what a package provides
    assert_script_run 'rpm -q --provides aaa_base';

    # Prepare test rpm file of installed package
    zypper_call 'in -fy --download-only aaa_base';
    assert_script_run 'mv `find /var/cache/zypp/packages/ | grep aaa_base | head -n1` /tmp/aaa_base.rpm';

    # List contents of an RPM package
    assert_script_run 'rpm -qlp /tmp/aaa_base.rpm';

    # List all packages that require a given package
    assert_script_run 'rpm -q --whatrequires aaa_base';

    # Dump basic file information of every file in a package
    assert_script_run 'rpm -q --dump aaa_base';

    # List requirements of an RPM package
    assert_script_run 'rpm -qp --requires /tmp/aaa_base.rpm';

    # Prepare test rpm file of missing package
    assert_script_run('rpm -e sysstat') if (script_run("rpm -q sysstat") == 0);
    zypper_call 'in -fy --download-only sysstat';
    assert_script_run 'mv `find /var/cache/zypp/packages/ | grep sysstat | head -n1` /tmp/sysstat.rpm';

    # Install prerequizities of sysstat package
    zypper_call 'in procmail';

    # Check if installation of a package will go through, do not actually install
    assert_script_run 'rpm -ivh --test /tmp/sysstat.rpm';

    # Install an RPM package
    assert_script_run 'rpm -ivh /tmp/sysstat.rpm';

    # Uninstall an already installed package
    assert_script_run 'rpm -evh sysstat';

    # Install the package again
    assert_script_run 'rpm -ivh /tmp/sysstat.rpm';
}

1;

