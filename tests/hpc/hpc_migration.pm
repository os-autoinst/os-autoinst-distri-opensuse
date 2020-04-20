# SUSE's openQA tests
#
# Copyright © 2019-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC online migration
#    This test module is aiming at both, rudimentary and multimachine
#    checks of zypper online migration of HPC product.
#    In its simple form it can be run on a single VM to check if:
#    - migration targets are available at all,
#    - available migration target(s) are correct etc.
#    Upon providing 'HPC_MIGRATION' in the test setting, the module
#    can be used for multimachine set-up, so that some HPC functionalities
#    could be checked before and after online zypper migration.
#    See: README.migration
#
# Maintainer: Sebastian Chlad <sebastian.chlad@suse.com>

use base 'hpcbase';
use base 'hpc::migration';
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use power_action_utils 'power_action';
use version_utils 'is_sle';

sub run {
    my $self    = shift;
    my $version = get_required_var("VERSION");
    my @migration_targets;
    my $migration_target;

    if (get_var('MIGRATE_TO_HPC_PRODUCT') and get_var('HPC_PRODUCT_MIGRATION')) {
        die('Test setting MIGRATE_TO_HPC_PRODUCT and HPC_PRODUCT_MIGRATION are exclusive!');
    }

    if (get_var('HPC_PRODUCT_MIGRATION')) {
        # run register_products() as preprepared images might require that
        $self->register_products();
        $self->switch_to_sle_hpc();
    }

    $self->register_products();
    assert_script_run("SUSEConnect --status-text");
    zypper_call('in zypper-migration-plugin');

    #list available migration targets
    script_run('zypper  --no-refresh patch --updatestack-only -y');
    my $migration_query = script_run('zypper migration --query');
    if ($migration_query != 0) {
        $self->migration_err();
        assert_script_run("SUSEConnect --status-text");
        $self->register_products();
    }

    #/2 as @migration_targets lists both, target number and SP version
    @migration_targets = $self->get_migration_targets();
    my $num_of_migration_targets = (scalar(@migration_targets) / 2);

    if ($num_of_migration_targets < 1) {
        record_info('Problem with migration targets! Seems there is none');
        die("No migration targets!");
    }
    record_info('INFO: num_of_migration_targets', "$num_of_migration_targets");

    #check SLE version
    my $current_version = script_output("grep VERSION= /etc/os-release | cut -d'=' -f2 | cut -d' ' -f1 | sed 's/\"//g'");
    record_info('INFO: current version', "$current_version");

    #compare current_version vs get_required_var("VERSION")
    $current_version =~ s/..-SP//;
    $version         =~ s/..-SP//;

    #for sle12/15 SP0 returned value for $current_version is major code version (12/15)
    if ($current_version > 12) {
        $current_version = 0;
    }

    my $diff = $version - $current_version;

    record_info('INFO: migrate-to version', "$version");
    record_info('DEBUG: diff',              "$diff");

    if (get_var('HPC_PRODUCT_MIGRATION')) {
        if ($diff != $num_of_migration_targets) {
            die("Wrong number of migration targets!");
        }
    } else {
        ## warning: temporary change until things are decided
        # new migration targets added: SLE12 Server SPX can migrate to:
        # SLE12 Server SPX+ AND SLE12 HPC SPX+. Thus if $diff = 1, there should be 2
        # migration targets
        if ($diff != $num_of_migration_targets) {
            die("Wrong number of migration targets!");
        }
    }

    ## iterate over the array containing all available migration targets
    ## where starting point is: SLE12 Server SPX
    ## As the scheme of zypper migration --query is:
    # 1 | SUSE Linux Enterprise Server 12 SP5 x86_64
    # 2 | SUSE Linux Enterprise High Performance Computing 12 SP5
    # 3 | SUSE Linux Enterprise Server 12 SP6 x86_64
    # 4 | SUSE Linux Enterprise High Performance Computing 12 SP6
    ## so the array will be:
    # (1, SUSE Linux Enterprise Server 12 SP5 x86_64,
    # 2, SUSE Linux Enterprise High Performance Computing 12 SP5,
    # 3, SUSE Linux Enterprise Server 12 SP6 x86_64,
    # 4, SUSE Linux Enterprise High Performance Computing 12 SP6)
    ## if given element of the array contains $version, set $migration_target
    ## to the preceding element of the array which should be migration
    ## target number
    my $index = 0;
    $version = get_required_var("VERSION");
    $version =~ s/-/ /;

    ##TODO: make it work for sle15
    if (get_var('MIGRATE_TO_HPC_PRODUCT') xor get_var('HPC_PRODUCT_MIGRATION')
        xor is_sle('>15')) {
        foreach (@migration_targets) {
            if ($_ =~ "High Performance Computing $version") {
                $migration_target = $migration_targets[$index - 1];
            }
            $index++;
        }
    } else {
        foreach (@migration_targets) {
            if ($_ =~ "Server $version") {
                $migration_target = $migration_targets[$index - 1];
            }
            $index++;
        }
    }

    if (get_var("HPC_MIGRATION")) {
        barrier_wait('HPC_MIGRATION_START');
    }
    # TODO: https://progress.opensuse.org/issues/57296
    script_run("zypper migration -n --no-recommends --auto-agree-with-licenses --migration $migration_target", 840);

    assert_script_run("SUSEConnect --status-text");

    power_action('reboot', keepconsole => 1, textmode => 0);

    my $status_s = script_output('SUSEConnect --status-text', 180);
    record_info('INFO', "$status_s");
    my $status_l = script_output('SUSEConnect -l', 180);
    record_info('INFO', "$status_l");

    ## SUSEConnect: it is expected that all items shall be registered, since
    ## the migration starts when all items are registered
    if ($status_s =~ "Not Registered") {
        record_info('INFO', "$status_s");
        die('One of the modules or product is not registered!');
    }
    ## correct High Performance Computing or SUSE Linux Enterprise Server should
    ## be there
    if (get_var('MIGRATE_TO_HPC_PRODUCT') xor get_var('HPC_PRODUCT_MIGRATION')
        xor is_sle('>15')) {
        # expected is to have High Performance Computing $version
        if ($status_s !~ "High Performance Computing $version") {
            die('Expected product is not there!');
        }
    } else {
        # expected it to have SUSE Linux Enterprise Server 12 $version
        if ($status_s !~ "SUSE Linux Enterprise Server $version") {
            die('Expected product is not there!');
        }
    }
    ## check for modules, if they are there as expected
    if (($status_s !~ 'HPC Module') or ($status_s !~ 'Web and Scripting Module')) {
        die('One of the expected modules is not there!');
    }
    if (is_sle('>15')) {
        if ($status_s !~ 'Python 2 Module') {
            die('Python 2 module is not listed');
        }
    }

    ## SUSEConnect -l: sanity check in case SUSEConnect -status-text is reporting
    ## incorrectly
    #TODO: add such check

    if (get_var("HPC_MIGRATION")) {
        barrier_wait('HPC_MIGRATION_TESTS');
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    upload_logs('/tmp/migration_targets');
}

1;
