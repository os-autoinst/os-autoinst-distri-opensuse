#SUSE"s openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: zypper
# Summary: This is a zypper extend regression tests. poo#51521.
#   This test is based on https://gitlab.suse.de/ONalmpantis/scripts/blob/master/zypper_regression_test.sh.
# - Combination of search commands for a package (star)
# - Get information about what a package provides
# - Get information about the requirements of a package
# - Only download a package for later installation, don't ask for permission
# - Check if the RPM actually been downloaded
# - Disable auto-refresh, install star, don't ask for permission
# - Remove star, don't ask for permission
# - Install specific version of a package
# - Install and remove package combination
# - Clean up dependencies of a removed package
# - Add a repository
# - Install package from a disabled repository
# - Prioritize, rename, remove a repository
# - Verify whether all dependencies are fulfilled
# - Identify processes and services using deleted files
# - List all applicable patches
# - List applicable patches for all CVE issues, or issues whose number matches the given string
# - List applicable patches for all Bugzilla issues, or issues whose number matches the given string
# - List all available released patches, no matter if they are applicable on our system or not
# - Show packages which are without repository
# - Show packages which are installed but are not needed
# - List all available patterns
# - List all available products
# - List all defined repositories and corresponding URIs
# - Disable a specific repository
# - Enable a specific repository
# - Force refresh repositories
# - Disable/Enable rpm file caching for all the repositories.
# - Disable/Enable rpm file caching for remote repositories
# - Enter zypper shell and run the lr command | echo lr
# - Check that zypper handles "provides" in a case-sensitive manner
#   https://jira.suse.com/browse/SLE-16271
# -
# Maintainer: Marcelo Martins <mmartins@suse.cz>, Anna Minou <anna.minou@suse.com>
# Tags: poo#51521, poo#49076
#
use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Architectures;
use utils qw(zypper_call);
use version_utils qw(is_sle is_leap is_jeos is_tumbleweed);

sub run {
    select_serial_terminal;

    #Search for a package (star
    zypper_call 'se star';
    zypper_call 'se "sta"';
    zypper_call 'se --match-exact "star"';
    zypper_call 'se -d star';
    zypper_call 'se -u star';

    #Get information about what a package provides:
    zypper_call 'info --provides star';

    #Get information about the requirements of a package:
    zypper_call 'info --requires star';

    #Only download a package for later installation, don't ask for permission:
    zypper_call 'in -d star';

    #Has the RPM actually been downloaded?
    assert_script_run("find /var/cache/zypp/packages/ -name 'star*'");

    # Disable auto-refresh, install star, don't ask for permission:
    zypper_call '--no-refresh in star';

    #Remove star, don't ask for permission:
    zypper_call 'rm star';

    #Install specific version of a package
    my $version = script_output q[zypper se -s star |grep " star " | awk 'END {print $6}'];
    zypper_call "in -f star-$version";

    #Install and remove package combination
    zypper_call "in cmake -star";

    #Cleaning up dependencies of removed packages
    zypper_call "rm --clean-deps cmake";

    #Add a repository
    zypper_call 'ar -p 90 -f --no-gpgcheck http://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Leap_15.1/ packman';
    assert_script_run("zypper lr | grep packman");

    #Install package from a disabled repository
    zypper_call 'mr -d packman';
    zypper_call '--plus-content packman install funny-manpages';

    #Prioritize a repository
    zypper_call 'mr -e -p 20 packman';

    #Rename a repository
    zypper_call 'renamerepo "packman" Packman';

    #Remove a repository
    zypper_call 'rr Packman';

    #Verify whether all dependencies are fulfilled
    zypper_call 'verify';

    #Identify processes and services using deleted files
    # *zypper ps* depends on lsof package, older JeOS images do not have it pre-installed
    zypper_call 'in lsof' if is_jeos && (is_sle("<15-SP2") || is_leap("<15.2"));
    zypper_call 'ps';

    #List all applicable patches:
    zypper_call 'lu -t patch';

    #List applicable patches for all CVE issues, or issues whose number matches the given string:
    zypper_call 'lp --cve=--cve=CVE-2019-1010319';

    #List applicable patches for all Bugzilla issues, or issues whose number matches the given string:
    zypper_call 'lp -b=1129403';

    #List all available released patches, no matter if they are applicable on our system or not:
    zypper_call 'lp -a';

    #Show packages which are without repository:
    zypper_call 'pa --orphaned';
    #There should be one orphan left funny-manpages, let's remove it
    zypper_call 'rm funny-manpages';

    #Show packages which are installed but are not needed:
    zypper_call 'pa --unneeded';

    #List all available patterns:
    zypper_call 'pt';

    #List all available products:
    zypper_call 'pd';

    #List all defined repositories and corresponding URIs:
    zypper_call 'lr -u';

    #Disable a specific repository
    zypper_call 'mr -d 1';
    validate_script_output('zypper lr 1', sub { m/Enabled\s+:\sNo/ });

    #Enable a specific repository
    zypper_call 'mr -e 1';
    validate_script_output('zypper lr 1', sub { m/Enabled\s+:\sYes/ });

    #Forced refresh of repositories
    zypper_call 'refresh -fdb';

    #Autorefresh on repository on/off
    my $refresh = is_sle('=12-sp1') ? '-r' : '-f';
    zypper_call "mr $refresh 1";
    my $autorefresh = is_sle('=12-sp1') ? 'Auto-refresh' : 'Autorefresh';
    validate_script_output('zypper lr 1', sub { m/$autorefresh\s+:\sOn/ });
    my $no_refresh = is_sle('=12-sp1') ? '-R' : '-F';
    zypper_call "mr $no_refresh 1";
    validate_script_output('zypper lr 1', sub { m/$autorefresh\s+:\sOff/ });

    #Disable rpm file caching for all the repositories.
    zypper_call 'mr -Ka';

    #Enable rpm file caching for all the repositories
    zypper_call 'mr -ka';

    #Disable rpm file caching for remote repositories
    zypper_call 'mr -Kt';

    #Disable rpm file caching for remote repositories
    zypper_call 'mr -Kt';

    #Enter zypper shell and run the lr command | echo lr
    assert_script_run('echo lr |zypper shell');

    if (is_x86_64 && !is_jeos && (is_sle('>=15-SP3') || is_leap('>=15.3') || is_tumbleweed())) {
        # We want to check for packages that can be case sensitive, Mesa is a great candidate that
        # is present in the base image of all of the products
        # See https://jira.suse.com/browse/SLE-16271
        zypper_call('search --provides --match-exact Mesa');
        zypper_call('search --provides --match-exact mesa', {exit_code => 104});
    }
}

1;
