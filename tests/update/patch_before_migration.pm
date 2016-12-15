# Patch SLE11* qcow2 images before migration (offline)
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Patch hdd's images before doing offline migration
# Maintainer: Dumitru Gutu <dgutu@suse.de>

use base "consoletest";
use strict;
use testapi;
use utils;
use registration;

sub patching_sle11() {

    my ($registration, $email, $regcode, $regcode_ha, $regcode_geo) = @_;
    $email       = get_var("SCC_EMAIL");
    $regcode     = get_var("SCC_REGCODE");
    $regcode_ha  = get_var("SCC_REGCODE_HA");
    $regcode_geo = get_var("SCC_REGCODE_GEO");

    # block update process before registration
    script_run("sed -i 's/true/false/g' /etc/PackageKit/PackageKit.conf");

    if (get_var("SCC_REGCODE_GEO")) {
        $registration = script_output("
        suse_register -n -a email=$email -a regcode-sles=$regcode -a regcode-slehae=$regcode_ha -a regcode-slehaegeo=$regcode_geo", 90);
    }
    elsif (get_var("SCC_REGCODE_HA")) {
        $registration = script_output("suse_register -n -a email=$email -a regcode-sles=$regcode -a regcode-slehae=$regcode_ha", 70);
    }
    else {
        $registration = script_output("suse_register -n -a email=$email -a regcode-sles=$regcode", 90);
    }
    die "Unable to register the system, please check logs" unless $registration =~ /Registration finished successfully/;
    save_screenshot;

    #Patch the system
    zypper_call('patch --with-interactive -l', exitcode => [0, 102, 103]);
    assert_script_run('zypper lr -d');
    save_screenshot;
    my $reg_out = script_output("suse_register -E");
    die "Unable to erase system registration data" unless $reg_out =~ /Successfully erased local registration data/;
    save_screenshot;
    script_run("sed -i 's/false/true/g' /etc/PackageKit/PackageKit.conf");
}

sub patching_sle12() {

    # stop packagekit service
    script_run "systemctl mask packagekit.service";
    script_run "systemctl stop packagekit.service";
    assert_script_run("zypper lr && zypper mr --disable --all");
    save_screenshot;
    yast_scc_registration;
    assert_script_run('zypper lr -d');

    if (check_var('HDDVERSION', '12')) {
        zypper_call('patch --with-interactive -l', exitcode => [0, 102, 103]);
        assert_script_run("zypper removeservice `zypper services --sort-by-name | awk {'print\$5'} | tail -1`");
        assert_script_run('rm /etc/zypp/credentials.d/* /etc/SUSEConnect');
        my $output = script_output 'SUSEConnect -s';
        die "System is still registered" unless $output =~ /Not Registered/;
        save_screenshot;
    }
    else {
        zypper_call('patch --updatestack-only -l', exitcode => [0, 102, 103]);
        assert_script_run('SUSEConnect -d');
        my $output = script_output 'SUSEConnect -s';
        die "System is still registered" unless $output =~ /Not Registered/;
        save_screenshot;
    }
    assert_script_run("zypper mr --enable --all");
}

sub run() {

    select_console 'root-console';

    if (get_var('HDDVERSION', '') =~ 'SLES-11') {
        patching_sle11;
    }
    else {
        patching_sle12;
    }
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
