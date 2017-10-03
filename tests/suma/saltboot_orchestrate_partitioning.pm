# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test various partitioning schemes
# # Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base "sumatest";
use 5.018;
use testapi;
use lockapi;
use mmapi;
use selenium;

sub toggle_formula_for_hwtype {
    my $self   = shift;
    my $hwtype = shift;

    my $driver = selenium_driver();

    $self->suma_menu('Systems', 'System Groups');

    wait_for_link("hwtype_$hwtype")->click();
    wait_for_page_to_load;
    save_screenshot;

    $driver->find_element('Formulas', 'link_text')->click();
    wait_for_page_to_load;
    wait_for_xpath("//a[\@id='saltboot']")->click();
    wait_for_page_to_load;
    wait_for_xpath("//button[\@id='save-btn']")->click();
    wait_for_page_to_load;
    sleep 5;
    save_screenshot;
    wait_for_xpath("//a[\@href='/']")->click();
    wait_for_page_to_load;
}


sub run {
    my ($self) = @_;
    my @partitioning_tests = qw( 01_raid_degraded  02_raid_full  03_raid_degraded2  04_raid_full2  05_normal );

    my @barriers = map { ("partitioning_$_", "partitioning_${_}_finish") } @partitioning_tests;

    if (check_var('SUMA_SALT_MINION', 'branch')) {
        $self->register_barriers('saltboot_orchestrate_partitioning', 'saltboot_orchestrate_partitioning_finish');
        $self->registered_barrier_wait('saltboot_orchestrate_partitioning');
        $self->registered_barrier_wait('saltboot_orchestrate_partitioning_finish');
    }
    elsif (check_var('SUMA_SALT_MINION', 'terminal')) {
        $self->register_barriers('saltboot_orchestrate_partitioning', @barriers, 'saltboot_orchestrate_partitioning_finish');
        $self->registered_barrier_wait('saltboot_orchestrate_partitioning');

        for my $partitioning (@partitioning_tests) {
            $self->registered_barrier_wait("partitioning_$partitioning");
            select_console 'root-console';
            script_output("salt-call pillar.items");

            $self->reboot_terminal;

            select_console 'root-console';

            # minor number of raid partition seems to be random
            script_output('lsblk | sed -e "s|259:.|259:0|" | tee part_exist');
            assert_script_run "curl -f -v " . autoinst_url . "/data/suma/$partitioning.expected > part_expected";
            assert_script_run "diff -w -u part_expected part_exist";

            $self->registered_barrier_wait("partitioning_${partitioning}_finish");
        }

        $self->registered_barrier_wait('saltboot_orchestrate_partitioning_finish');
    }
    else {
        for my $barrier (@barriers) {
            barrier_create($barrier, get_var('NUMBER_OF_TERMINALS', 0) + 1);
        }
        $self->register_barriers('saltboot_orchestrate_partitioning', @barriers, 'saltboot_orchestrate_partitioning_finish');
        $self->registered_barrier_wait('saltboot_orchestrate_partitioning');

        for my $hwtype ($self->get_hwtypes) {
            $self->toggle_formula_for_hwtype($hwtype);
        }

        select_console 'root-console';
        for my $partitioning (@partitioning_tests) {
            for my $hwtype ($self->get_hwtypes) {
                assert_script_run "curl -f -v " . autoinst_url . "/data/suma/$partitioning.sls > /srv/pillar/pillar_$hwtype.sls";
            }

            $self->registered_barrier_wait("partitioning_$partitioning");
            $self->registered_barrier_wait("partitioning_${partitioning}_finish");
        }

        for my $hwtype ($self->get_hwtypes) {
            assert_script_run "echo '' > /srv/pillar/pillar_$hwtype.sls";
        }

        select_console 'x11', tags => 'suma_welcome_screen';
        for my $hwtype ($self->get_hwtypes) {
            $self->toggle_formula_for_hwtype($hwtype);
        }
        $self->registered_barrier_wait('saltboot_orchestrate_partitioning_finish');
    }
}

1;
