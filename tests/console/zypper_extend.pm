#SUSE"s openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: This is a zypper extend regression tests. poo#51521.
#   This test is based on https://gitlab.suse.de/ONalmpantis/scripts/blob/master/zypper_regression_test.sh.
# - Search for a package (star)
# - Get information about what a package provides
# - Get information about the requirements of a package
# - Only download a package for later installation, don't ask for permission
# - Check if the RPM actually been downloaded
# - Disable auto-refresh, install star, don't ask for permission
# - Remove star, don't ask for permission
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
# - Disable/Enable rpm file caching for all the repositories.
# - Disable/Enable rpm file caching for remote repositories
# - Enter zypper shell and run the lr command | echo lr
# Maintainer: Marcelo Martins <mmartins@suse.cz>
# Tags: poo#51521
#
use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    select_console 'root-console';


    #Search for a package (star
    zypper_call 'se star';

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

}

1;
