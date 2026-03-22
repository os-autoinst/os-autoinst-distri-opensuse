# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>

use strict;
use warnings;
use Test::More;
use Test::MockModule;
use Test::Exception;
use List::Util qw(any);
use sles4sap::gcp_cli;

subtest '[gcp_ncc_spoke_create]' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    my @calls;
    $gcpcli->redefine(assert_script_run => sub { push @calls, $_[0]; return 0; });

    gcp_ncc_spoke_create(
        project => 'flute',
        name => 'my-spoke',
        hub => 'projects/ibsm-project/locations/global/hubs/ibsm-hub',
        network => 'my-network',
        group => 'default'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /gcloud network-connectivity spokes linked-vpc-network create/ } @calls), 'Command linked-vpc-network create');
    ok((any { /--hub.*ibsm-hub/ } @calls), 'hub parameter is in command');
    ok((any { /--global/ } @calls), '--global flag is in command');
    ok((any { /--vpc-network.*my-network/ } @calls) || (any { /--vpc-network my-network/ } @calls), 'vpc-network parameter is in command');
    ok((any { /--project.*flute/ } @calls), 'project parameter is in command');
    ok((any { /--group.*default/ } @calls), '--group default is in command');
};

subtest '[gcp_ncc_spoke_create] missing arguments' => sub {
    dies_ok { gcp_ncc_spoke_create(name => 'n', hub => 'h', network => 'net') } 'Dies without project';
    dies_ok { gcp_ncc_spoke_create(project => 'p', hub => 'h', network => 'net') } 'Dies without name';
    dies_ok { gcp_ncc_spoke_create(project => 'p', name => 'n', network => 'net') } 'Dies without hub';
    dies_ok { gcp_ncc_spoke_create(project => 'p', name => 'n', hub => 'h') } 'Dies without network';
};

subtest '[gcp_ncc_spoke_delete]' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    my @calls;
    $gcpcli->redefine(script_run => sub { push @calls, $_[0]; return 42; });

    my $ret = gcp_ncc_spoke_delete(name => 'my-spoke');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /gcloud network-connectivity spokes delete/ } @calls), 'Command spokes delete');
    ok((any { /--global/ } @calls), '--global flag is in command');
    ok((any { /--quiet/ } @calls), '--quiet flag is in command');
    ok(($ret eq 42), "Return expected 42 get $ret");
};

subtest '[gcp_ncc_spoke_delete] missing arguments' => sub {
    dies_ok { gcp_ncc_spoke_delete() } 'Dies without name';
};

subtest '[gcp_ncc_spoke_wait_active] success' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    my @calls;
    $gcpcli->redefine(script_output => sub { push @calls, $_[0]; return 'ACTIVE'; });

    my $wait_time = gcp_ncc_spoke_wait_active(name => 'my-spoke', timeout => 60);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /gcloud network-connectivity spokes describe/ } @calls), 'Command spokes describe');
    ok((any { /--global/ } @calls), '--global flag is in command');
    ok((any { /--format="?get\(state\)"?/ } @calls), 'format get(state) is in command');
    ok(defined($wait_time), "Wait time is defined: $wait_time");
};

subtest '[gcp_ncc_spoke_wait_active] timeout' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    $gcpcli->redefine(script_output => sub { return 'INACTIVE'; });

    dies_ok {
        gcp_ncc_spoke_wait_active(name => 'my-spoke', timeout => 1);
    } 'Dies on timeout when spoke not ACTIVE';
};

subtest '[gcp_ncc_spoke_wait_active] missing arguments' => sub {
    dies_ok { gcp_ncc_spoke_wait_active() } 'Dies without name';
};

done_testing;
