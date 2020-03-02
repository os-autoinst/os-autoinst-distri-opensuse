# SUSE's openQA tests
#
# Copyright © 2019-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Base module for HPC migration tests
# Maintainer: Sebastian Chlad <schlad@suse.de>

package hpc::migration;
use strict;
use warnings;
use testapi;
use utils;

## For SLE12 HPC exists as module and product
sub switch_to_sle_hpc {
    my $suseconnect_str = ' -e testing@suse.com -r ';

    zypper_call('in switch_sles_sle-hpc');
    assert_script_run('switch_to_sle-hpc' . $suseconnect_str . get_required_var('SCC_REGCODE_HPC_PRODUCT'), 600);
}

sub register_products {
    my $register = "register_installed_products.pl";
    my $reg_code = get_required_var('SCC_REGCODE');
    my @products_to_register;

    script_run("SUSEConnect --status-text > /tmp/installed_products");
    script_run("wget --quiet " . data_url("hpc/$register") . " -O $register");
    script_run("chmod +x $register");
    my $products = script_output("./$register");

    if ($products =~ 'empty') {
        goto NOREGISTRATION;
    }

    @products_to_register = split(/\|/, $products);
    s{^\s+|\s+$}{}g foreach @products_to_register;

    record_info('Some registration is ongoing');
    my $tmp_hpc_module;
    foreach my $i (@products_to_register) {
        if ($i =~ m/sle-module-hpc/) {
            $tmp_hpc_module = $i;
            next;
        }
        script_run("SUSEConnect -p $i -r $reg_code");
    }
    script_run("SUSEConnect -p $tmp_hpc_module -r $reg_code");

  NOREGISTRATION:
    record_info('All installed products are registered!');
}

## simplistic way of re-trying the migration
## TODO: implement proper error handling
sub migration_err {
    record_info('recording err');
    assert_script_run("SUSEConnect --rollback");
}

## function: get_migration_targets()
## should return the array of available migration targets
## As this is online migration only, it should only contain
## the list of respective Service Packs available for migration
sub get_migration_targets {
    my $pars = "pars_migration.pl";
    my $targets;
    my @migration_targets;

    $targets = script_run('zypper migration --query > /tmp/migration_targets');
    if ($targets != 0) {
        record_info('targets err');
        die('Something went wrong!');
    } else {
        record_info('Available migration targets: ', script_output('cat /tmp/migration_targets'));
    }
    script_run("wget --quiet " . data_url("hpc/$pars") . " -O $pars");
    assert_script_run("chmod +x $pars");

    $targets = script_output("./$pars");

    # script executed on SUT returns scalar with | as a delimiter
    # change scalar to array and trimm the whitespces
    @migration_targets = split(/\|/, $targets);
    s{^\s+|\s+$}{}g foreach @migration_targets;

    return @migration_targets;
}

1;
