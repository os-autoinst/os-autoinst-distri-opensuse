# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Unit tests for the publiccloud::provider base class -- name
# conversion, terraform tag/output helpers, ssh-key generation and string
# escaping.
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Exception;
use Test::Warnings;
use testapi 'set_var';

use publiccloud::azure_client;
use publiccloud::provider;

sub _unset { for my $k (@_) { set_var($k, undef) } }

subtest '[conv_openqa_tf_name] provider name mapping' => sub {
    set_var('PUBLIC_CLOUD_PROVIDER', 'EC2');
    is(publiccloud::provider::conv_openqa_tf_name(), 'aws', 'EC2 maps to aws');

    set_var('PUBLIC_CLOUD_PROVIDER', 'GCE');
    is(publiccloud::provider::conv_openqa_tf_name(), 'gcp', 'GCE maps to gcp');

    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    is(publiccloud::provider::conv_openqa_tf_name(), 'azure', 'AZURE stays azure (lowercased)');

    _unset('PUBLIC_CLOUD_PROVIDER');
};

subtest '[escape_single_quote] shell-safe single quotes' => sub {
    is(publiccloud::provider::escape_single_quote('plain'), 'plain', 'no quotes unchanged');
    is(publiccloud::provider::escape_single_quote(q{it's}), q{it'"'"'s}, 'single quote escaped');
    is(publiccloud::provider::escape_single_quote(q{a'b'c}), q{a'"'"'b'"'"'c}, 'multiple quotes escaped');
};

subtest '[terraform_param_tags] json tag structure' => sub {
    my $provider = publiccloud::provider->new();
    my $mod = Test::MockModule->new('publiccloud::provider', no_auto => 1);
    $mod->redefine(get_current_job_id => sub { 555 });
    $mod->redefine(calculate_custodian_ttl => sub { '2030-01-01T00:00:00Z' });

    set_var('OPENQA_URL', 'https://openqa.suse.de/');
    set_var('MAX_JOB_TIME', 3600);
    set_var('PUBLIC_CLOUD_TTL_OFFSET', 300);
    set_var('NAME', 'my-job');
    set_var('PUBLIC_CLOUD_PCW_IGNORE', undef);

    my $json = $provider->terraform_param_tags();
    require Mojo::JSON;
    my $tags = Mojo::JSON::decode_json($json);
    is($tags->{openqa_var_job_id}, 555, 'job id tag');
    is($tags->{openqa_var_server}, 'openqa.suse.de', 'server url trimmed of scheme/slash');
    is($tags->{openqa_ttl}, 3900, 'ttl = MAX_JOB_TIME + offset');
    is($tags->{openqa_var_name}, 'my-job', 'name tag');
    is($tags->{custodian_ttl}, '2030-01-01T00:00:00Z', 'custodian ttl from helper');
    ok(!exists $tags->{pcw_ignore}, 'no pcw_ignore by default');

    set_var('PUBLIC_CLOUD_PCW_IGNORE', '1');
    my $tags2 = Mojo::JSON::decode_json($provider->terraform_param_tags());
    is($tags2->{pcw_ignore}, '1', 'pcw_ignore tag when enabled');

    _unset(qw/OPENQA_URL OPENQA_HOSTNAME MAX_JOB_TIME PUBLIC_CLOUD_TTL_OFFSET NAME PUBLIC_CLOUD_PCW_IGNORE/);
};

subtest '[get_terraform_output] returns value, empty on null' => sub {
    my $provider = publiccloud::provider->new();
    my $mod = Test::MockModule->new('publiccloud::provider', no_auto => 1);
    $mod->redefine(script_run => sub { 0 });

    $mod->redefine(script_output => sub { 'my-vm-name' });
    is($provider->get_terraform_output('.vm_name.value[0]'), 'my-vm-name', 'returns jq output');

    $mod->redefine(script_output => sub { 'null' });
    is($provider->get_terraform_output('.missing'), undef, 'jq null mapped to undef');
};

subtest '[create_ssh_key] derives algorithm and generates when absent' => sub {
    my $provider = publiccloud::provider->new(ssh_key => '~/.ssh/id_ed25519');
    my $mod = Test::MockModule->new('publiccloud::provider', no_auto => 1);
    my @info;
    $mod->redefine(record_info => sub { push @info, [@_] });
    $mod->redefine(script_run => sub { 1 });    # key file absent
    my @asr;
    $mod->redefine(assert_script_run => sub { push @asr, $_[0]; return 0 });

    $provider->create_ssh_key();
    ok((grep { /ssh-keygen -t ed25519/ } @asr), 'generates ed25519 key');
    is($info[0][0], 'ed25519', 'algorithm derived from key filename');

    # When key already present, no keygen call
    @asr = ();
    $mod->redefine(script_run => sub { 0 });    # key file exists
    $provider->create_ssh_key();
    ok(!(grep { /ssh-keygen/ } @asr), 'does not regenerate existing key');
};

subtest '[terraform_apply] minimal happy path' => sub {
    set_var('PUBLIC_CLOUD', 1);
    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    set_var('PUBLIC_CLOUD_REGION', 'westeurope');
    set_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'Standard_B1s');
    set_var('FLAVOR', 'DVD');

    my $mock = Test::MockModule->new('publiccloud::provider', no_auto => 1);
    $mock->redefine($_ => sub { }) for qw(record_info assert_script_run script_retry terraform_prepare_env);
    $mock->redefine(get_image_uri => sub { '' });
    $mock->redefine(get_image_id => sub { '' });
    $mock->redefine(conv_openqa_tf_name => sub { 'tf' });
    $mock->redefine(terraform_param_tags => sub { '{}' });
    $mock->redefine(script_run => sub { 0 });
    $mock->redefine(script_output => sub {
            return '{"vm_name":{"value":[]},"public_ip":{"value":[]}}' if ($_[0] =~ /output -json/);
            return '';
    });
    Test::MockModule->new('publiccloud::instances', no_auto => 1)->redefine(set_instances => sub { });

    my $provider = publiccloud::provider->new(provider_client => publiccloud::azure_client->new());
    my @instances = $provider->terraform_apply();

    is scalar(@instances), 0, 'terraform_apply returns the list of created instances';
    ok $provider->terraform_applied, 'terraform_apply flags the deployment as applied';

    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER PUBLIC_CLOUD_REGION PUBLIC_CLOUD_INSTANCE_TYPE FLAVOR/);
};

done_testing;
