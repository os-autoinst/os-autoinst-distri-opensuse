# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Register base product & extensions with SUSEConnect
# Maintainer: Jiawei Sun <jwsun@suse.com>

package suseconnect_register;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use utils;
use registration;


our @EXPORT = qw(suseconnect_registration command_register is_module assert_module);

sub suseconnect_registration {
    my $product_version = get_required_var('VERSION');

    # register base prodcut
    command_register($product_version);
    my @scc_addons = split(/,/, get_var('SCC_ADDONS', ''));

    # register extensions without reg code
    for my $addon (@scc_addons) {
        next unless is_module($addon);
        command_register($product_version, $addon);
    }
    zypper_call 'lr';
}

sub command_register {
    my ($version, $addon, $addon_regcode) = @_;
    my $arch = get_required_var("ARCH");

    # precompile regexes
    my $zypper_conflict = qr/^Choose from above solutions by number[\s\S,]* \[1/m;
    my $zypper_continue = qr/^Continue\? \[y/m;
    my $zypper_done     = qr/Run.*to list these programs|^ZYPPER-DONE/m;
    my $registered      = qr/Registered*/m;

    if (!$addon) {
        my $reg_code = get_required_var("SCC_REGCODE");
        $version =~ s/\-SP/./;
        script_run("(SUSEConnect -p SLES/$version/$arch --regcode $reg_code) | tee /dev/$serialdev", 0);
        # zdup migration will have conflict or just register a bare system
        my $out = get_var("ZDUP") ? wait_serial($zypper_conflict, 240) : wait_serial($registered);
        #resolve potential conflict by zypper
        if ($out =~ $zypper_conflict) {
            save_screenshot;
            script_run("(zypper --no-refresh install --no-recommends -t product SLES;echo ZYPPER-DONE) | tee /dev/$serialdev", 0);
            $out = wait_serial([$zypper_conflict, $zypper_continue, $zypper_done], 240);
            while ($out) {
                if ($out =~ $zypper_conflict) {
                    send_key '1';
                    send_key 'ret';
                    save_screenshot;
                }
                elsif ($out =~ $zypper_continue) {
                    send_key 'y';
                    send_key 'ret';
                    save_screenshot;
                }
                elsif ($out =~ $zypper_done) {
                    save_screenshot;
                    last;
                }
                $out = wait_serial([$zypper_conflict, $zypper_continue, $zypper_done], 240);
            }
        }
    }

    else {
        my $addon_version = int $version;
        my $addon_name    = get_addon_fullname("$addon");

        # register extension without reg code.
        if (!$addon_regcode) {
            add_suseconnect_product($addon_name, $addon_version);
        }

        # register extension with reg code.
        else {
            add_suseconnect_product($addon_name, $version, $arch, "--regcode $addon_regcode");
        }
    }
    zypper_call 'lr';
}

# check there are modules in the addon list
sub assert_module {
    return 1 if (get_var('SCC_ADDONS', '') =~ /asmm|contm|hpcm|lgm|pcm|tcm|wsm|idu|ids/);
}

# Return 1 if this is a module
sub is_module {
    my ($addon) = @_;
    return 1 if (grep { $addon eq $_ } qw(asmm contm lgm pcm tcm wsm idu ids));
}


1;
