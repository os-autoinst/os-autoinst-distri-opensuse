# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test boot of a terminal
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

# reboot terminals
# verify that salt keys are preserved
# all image versions are enabled so the terminals boot 6.0.1 - highest available
# terminal with hwtype 'testterm2' is configured to request specific version 6.0.0

# version 6.0.1 is transfered over tftp
# version 6.0.0 is transfered over ftp


use base "sumatest";
use 5.018;
use testapi;
use lockapi;
use mmapi;
use utils 'zypper_call';
use selenium;

sub run {
    my ($self) = @_;
    $self->register_barriers('saltboot_orchestrate_reboot', 'saltboot_orchestrate_reboot_finish');
    if (check_var('SUMA_SALT_MINION', 'branch')) {
        $self->registered_barrier_wait('saltboot_orchestrate_reboot');
        $self->registered_barrier_wait('saltboot_orchestrate_reboot_finish');
    }
    elsif (check_var('SUMA_SALT_MINION', 'terminal')) {
        select_console 'root-console';
        $self->registered_barrier_wait('saltboot_orchestrate_reboot');
        script_output("salt-call pillar.items");

        $self->reboot_terminal;

        assert_script_run('grep 6.0.0 /etc/ImageVersion') if check_var('HWTYPE', 'testterm2');    # version requested
        assert_script_run('grep 6.0.1 /etc/ImageVersion') if check_var('HWTYPE', 'testterm');     # highest active

        $self->registered_barrier_wait('saltboot_orchestrate_reboot_finish');
    }
    else {
        select_console 'root-console';

        # FIXME: this should be configured via forms but the forms have to support Null value first
        # not yet available on SUMA
        for my $hwtype ($self->get_hwtypes) {
            assert_script_run 'echo "
  \'*-' . $hwtype . '-*\':
    - pillar_' . $hwtype . '" >> /srv/pillar/top.sls';

            if ($hwtype eq 'testterm') {
                # terminal-specific pillar is empty for now
                assert_script_run 'echo "" > /srv/pillar/pillar_' . $hwtype . '.sls';
            }
            elsif ($hwtype eq 'testterm2') {
                # Request specific image version 6.0.0 on terminal 2
                assert_script_run 'echo "
partitioning:
    disk1:
        partitions:
            p3:
                image_version: 6.0.0" > /srv/pillar/pillar_' . $hwtype . '.sls';
            }
        }

        # delete inactive flag everywhere so 6.0.1 becomes highest active version
        assert_script_run('sed -i -e "s|inactive.*$||" /srv/pillar/suma_test.sls');

        script_output('cat /srv/pillar/top.sls');
        script_output('cat /srv/pillar/pillar_*.sls');
        script_output('salt "*" pillar.items');

        $self->registered_barrier_wait('saltboot_orchestrate_reboot');
        $self->registered_barrier_wait('saltboot_orchestrate_reboot_finish');

        select_console 'x11', tags => 'suma_welcome_screen';
    }
}

1;
