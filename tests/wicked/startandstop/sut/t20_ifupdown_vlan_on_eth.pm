# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: VLAN on physical interface
#
#          eth1    <-l-    vlan11
#         
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;

sub run {
    my ($self, $ctx) = @_;
    my $ifc = $ctx->iface();

    $self->get_from_data('wicked/scripts/ifupdown', '/tmp/');
    assert_script_run('cd /tmp/ifupdown/test-1.1');
    $self->run_test_shell_script("ifupdown-1.1", "time eth0=$ifc bash ./test.sh");
    $self->skip_check_logs_on_post_run();
}

sub test_flags {
    return {always_rollback => 1};
}

1;
