# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Unit tests for publiccloud::ec2 -- AWS CLI command composition for
# describe/state/keypair/instance-type operations (CLI layer mocked).
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Exception;
use Test::Warnings;
use testapi 'set_var';

use publiccloud::ec2;

subtest '[describe_instance] composes aws describe-instances + jq query' => sub {
    my $provider = publiccloud::ec2->new();
    my $mod = Test::MockModule->new('publiccloud::ec2', no_auto => 1);
    my $seen;
    $mod->redefine(script_output => sub { $seen = $_[0]; return 'i-state' });
    set_var('PUBLIC_CLOUD_REGION', 'eu-central-1');

    my $res = $provider->describe_instance('i-12345', '.State.Name');
    is($res, 'i-state', 'returns script_output verbatim');
    like($seen, qr/aws ec2 describe-instances/, 'uses describe-instances');
    like($seen, qr/Values=i-12345/, 'filters by instance id');
    like($seen, qr/--region eu-central-1/, 'passes region');
    like($seen, qr/\.State\.Name/, 'appends jq query');

    _unset('PUBLIC_CLOUD_REGION');
};

subtest '[get_state_from_instance] queries State.Name' => sub {
    my $provider = publiccloud::ec2->new();
    my $mod = Test::MockModule->new('publiccloud::ec2', no_auto => 1);
    my $seen_query;
    $mod->redefine(describe_instance => sub { my ($s, $id, $q) = @_; $seen_query = $q; return 'running' });

    my $inst = Test::MockObject->new;
    $inst->mock(instance_id => sub { 'i-abc' });
    is($provider->get_state_from_instance($inst), 'running', 'returns the state');
    is($seen_query, '.State.Name', 'queries .State.Name');
};

subtest '[get_public_ip] uses terraform output + describe' => sub {
    my $provider = publiccloud::ec2->new();
    my $mod = Test::MockModule->new('publiccloud::ec2', no_auto => 1);
    $mod->redefine(get_terraform_output => sub { 'i-from-tf' });
    my ($seen_id, $seen_query);
    $mod->redefine(describe_instance => sub { my ($s, $id, $q) = @_; ($seen_id, $seen_query) = ($id, $q); return '203.0.113.10' });

    is($provider->get_public_ip(), '203.0.113.10', 'returns the public ip');
    is($seen_id, 'i-from-tf', 'uses instance id from terraform output');
    is($seen_query, '.PublicIpAddress', 'queries .PublicIpAddress');
};

subtest '[create_keypair] returns early when key file exists' => sub {
    my $provider = publiccloud::ec2->new();
    my $mod = Test::MockModule->new('publiccloud::ec2', no_auto => 1);
    $mod->redefine(script_run => sub { 0 });    # test -s pem succeeds
    is($provider->create_keypair('prefix'), 1, 'returns 1 without creating a new key');
};

subtest '[create_keypair] creates key on first success' => sub {
    my $provider = publiccloud::ec2->new();
    my $mod = Test::MockModule->new('publiccloud::ec2', no_auto => 1);
    my @cmds;
    # First call (test -s) -> file missing (1), subsequent create-key-pair -> success (0)
    my $first = 1;
    $mod->redefine(script_run => sub {
            push @cmds, $_[0];
            return 1 if $first-- > 0;    # test -s fails -> need to create
            return 0;    # create-key-pair succeeds
    });
    $mod->redefine(assert_script_run => sub { push @cmds, $_[0]; return 0 });

    is($provider->create_keypair('mykey'), 1, 'returns 1 on successful create');
    is($provider->ssh_key_pair, 'mykey_0', 'records the created key name');
    ok((grep { /create-key-pair --key-name 'mykey_0'/ } @cmds), 'creates first numbered key');
    ok((grep { /chmod 0400/ } @cmds), 'restricts key file permissions');
};

subtest '[delete_keypair] issues aws delete and clears key' => sub {
    my $provider = publiccloud::ec2->new(ssh_key => 'mykey');
    my $mod = Test::MockModule->new('publiccloud::ec2', no_auto => 1);
    my @asr;
    $mod->redefine(assert_script_run => sub { push @asr, $_[0]; return 0 });

    $provider->delete_keypair('explicit-key');
    ok((grep { /delete-key-pair --key-name explicit-key/ } @asr), 'deletes the named key');

    # no-op when no name and no ssh_key
    my $p2 = publiccloud::ec2->new(ssh_key => undef);
    @asr = ();
    $p2->delete_keypair();
    is(scalar @asr, 0, 'no delete call when no key name available');
};

subtest '[change_instance_type] modifies when different' => sub {
    my $provider = publiccloud::ec2->new();
    my $mod = Test::MockModule->new('publiccloud::ec2', no_auto => 1);
    # describe returns old type first, new type after the modify
    my @types = ('t2.micro', 't3.large');
    $mod->redefine(describe_instance => sub { shift @types });
    my @asr;
    $mod->redefine(assert_script_run => sub { push @asr, $_[0]; return 0 });

    my $inst = Test::MockObject->new;
    $inst->mock(instance_id => sub { 'i-xyz' });
    lives_ok { $provider->change_instance_type($inst, 't3.large') } 'changes type';
    ok((grep { /modify-instance-attribute.*t3\.large/ } @asr), 'issues modify-instance-attribute');
};

subtest '[change_instance_type] dies when already that type' => sub {
    my $provider = publiccloud::ec2->new();
    my $mod = Test::MockModule->new('publiccloud::ec2', no_auto => 1);
    $mod->redefine(describe_instance => sub { 't3.large' });
    my $inst = Test::MockObject->new;
    $inst->mock(instance_id => sub { 'i-xyz' });
    throws_ok { $provider->change_instance_type($inst, 't3.large') }
    qr/already t3\.large/, 'dies when type unchanged';
};

subtest '[query_metadata] fetches IMDSv2 token then ip' => sub {
    my $provider = publiccloud::ec2->new();
    my $mod = Test::MockModule->new('publiccloud::ec2', no_auto => 1);
    $mod->redefine(record_info => sub { });

    my @cmds;
    my $inst = Test::MockObject->new;
    my @outputs = ('TOKEN123', '10.0.0.5');
    $inst->mock(ssh_script_output => sub { my ($s, $c) = @_; push @cmds, $c; return shift @outputs });

    my $ip = $provider->query_metadata($inst, ifNum => 0, addrCount => 0);
    is($ip, '10.0.0.5', 'returns local-ipv4 metadata');
    like($cmds[0], qr{api/token}, 'first fetches the IMDSv2 token');
    like($cmds[1], qr{X-aws-ec2-metadata-token: TOKEN123}, 'uses the token in the metadata query');
    like($cmds[1], qr{local-ipv4}, 'queries local-ipv4');
};

sub _unset { for my $k (@_) { set_var($k, undef) } }

done_testing;
