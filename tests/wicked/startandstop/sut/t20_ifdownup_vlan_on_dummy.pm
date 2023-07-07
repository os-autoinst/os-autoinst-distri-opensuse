# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: ifup/ifdown on a vlan which is configured on top of a 
#          dummy interface.
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;

sub run {
    my ($self, $ctx) = @_;
    my $ifc = $ctx->iface();

    $self->get_from_data('wicked/scripts/ifdownup-1.1.sh', '/tmp/ifdownup-1.1.sh', executable => 1);
    $self->run_test_shell_script("ifdownup-1.1.sh", 'time /tmp/ifdownup-1.1.sh ');
    $self->skip_check_logs_on_post_run();
}

sub test_flags {
    return {always_rollback => 1};
}

1;
