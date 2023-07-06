# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: Rename an interface with udev and call ifreload/ifup
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>
#             qa-c <qa-c@suse.de>

use Mojo::Base 'wickedbase';
use testapi;

sub run {
    my ($self, $ctx) = @_;
    my $ifc = $ctx->iface();
    my $config = '/etc/sysconfig/network/ifcfg-' . $ifc;
    assert_script_run(q(echo -e "STARTMODE='auto'\nBOOTPROTO='static'\nIPADDR='10.0.2.11/15'" > ) . $config);
    $self->get_from_data('wicked/scripts/ifrename-1.sh', '/tmp/ifrename-1.sh', executable => 1);

    script_run('touch /etc/udev/rules.d/70-persistent-net.rules', die_on_timeout => 1);

    $self->run_test_shell_script("ifup dyn0", "time /tmp/ifrename-1.sh --apply ifup '$ifc' 'dyn0'");
    $self->run_test_shell_script("ifup $ifc", "time /tmp/ifrename-1.sh --apply ifup dyn0 '$ifc'");

    $self->run_test_shell_script("y2lan dyn0", "time /tmp/ifrename-1.sh --apply y2lan '$ifc' 'dyn0'");
    $self->run_test_shell_script("y2lan $ifc", "time /tmp/ifrename-1.sh --apply y2lan 'dyn0' '$ifc'");

    $self->skip_check_logs_on_post_run();
}

sub test_flags {
    return {always_rollback => 1};
}

1;
