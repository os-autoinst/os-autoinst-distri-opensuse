# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
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

sub run {
    my $self    = shift;
    my $version = get_required_var("VERSION");
    my @migration_targets;
    my $migration_target;

    $self->register_products();
    assert_script_run("SUSEConnect --status-text");
    zypper_call('in zypper-migration-plugin');

    #list available migration targets
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

    my $diff = $version - $current_version;

    record_info('INFO: migrate-to version', "$version");

    if ($diff != $num_of_migration_targets) {
        die("Wrong number of migration targets!");
    }

    ## iterate over the array containing all available migration targets
    ## As the scheme of zypper migration --query is:
    # 1 | SUSE Linux Enterprise Server 12 SP5 x86_64
    # 2 | SUSE Linux Enterprise Server 12 SP6 x86_64
    ## so the array will be:
    # (1, SUSE Linux Enterprise Server 12 SP5 x86_64, 2, SUSE Linux Enterprise Server 12 SP6 x86_64)
    ## if given element of the array contains $version, set $migration_target
    ## to the preceding element of the array which should be migration
    ## target number
    my $index = 0;
    $version = get_required_var("VERSION");
    $version =~ s/-/ /;
    foreach my $i (@migration_targets) {
        if (index($i, $version) != -1) {
            $migration_target = $migration_targets[$index - 1];
        }
        $index++;
    }
    if (get_var("HPC_MIGRATION")) {
        barrier_wait('HPC_MIGRATION_START');
    }
    # TODO: https://progress.opensuse.org/issues/57296
    script_run("zypper migration -n --no-recommends --auto-agree-with-licenses --migration $migration_target", 840);

    assert_script_run("SUSEConnect --status-text");

    power_action('reboot', keepconsole => 1, textmode => 0);
    #reboot and check the status again
    assert_script_run("SUSEConnect --status-text", 180);
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
