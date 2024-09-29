# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: Generic script/ifcfg/test-* runner
#          These test containing config parsing checks.
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;

sub run {
    my ($self, $ctx) = @_;
    my $ifc1 = $ctx->iface;
    my $ifc2 = $ctx->iface2;

    return if $self->skip_by_wicked_version(">=0.6.76");

    if ($self->{name} !~ m/t\d+_ifcfg_(test_\d+_\d+)/) {
        die("Testname doesn't have expected format!");
    }
    my $test = $1;
    $test =~ s/_/-/;
    $test =~ s/_/./g;

    $self->get_from_data('wicked/scripts', '/tmp/');
    assert_script_run('cd /tmp/scripts/ifcfg/' . $test);
    $self->run_test_shell_script($test, "time nicA=$ifc1 nicB=$ifc2 bash ./test.sh -d");
    $self->skip_check_logs_on_post_run();
}

sub test_flags {
    return {always_rollback => 1};
}

1;
