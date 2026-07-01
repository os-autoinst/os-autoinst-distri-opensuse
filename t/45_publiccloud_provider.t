# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Unit tests for the publiccloud::provider base class -- name
# conversion, img-proof output parsing, terraform tag/output helpers and
# string escaping.
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Exception;
use Test::Warnings;
use testapi 'set_var';

use publiccloud::provider;

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

subtest '[parse_img_proof_output] complete output' => sub {
    my $provider = publiccloud::provider->new();
    my $out = <<'EOT';
ID of instance: i-12345
IP of instance: 203.0.113.7
Created log file /tmp/img-proof.log
Created results file /tmp/img-proof.results
tests=10|pass=8|skip=1|fail=1|error=0
EOT
    my $res = $provider->parse_img_proof_output($out);
    is(ref $res, 'HASH', 'returns hashref when all fields present');
    is($res->{instance_id}, 'i-12345', 'instance id parsed');
    is($res->{ip}, '203.0.113.7', 'ip parsed');
    is($res->{logfile}, '/tmp/img-proof.log', 'logfile parsed');
    is($res->{results}, '/tmp/img-proof.results', 'results parsed');
    is($res->{tests}, 10, 'tests count parsed');
    is($res->{pass}, 8, 'pass count parsed');
    is($res->{skip}, 1, 'skip count parsed');
    is($res->{fail}, 1, 'fail count parsed');
    is($res->{error}, 0, 'error count parsed');
};

subtest '[parse_img_proof_output] missing fields returns undef' => sub {
    my $provider = publiccloud::provider->new();
    # Missing the tests=... summary line -> incomplete
    my $out = "ID of instance: i-1\nIP of instance: 1.2.3.4\n";
    is($provider->parse_img_proof_output($out), undef, 'undef when required fields missing');
};

subtest '[parse_img_proof_output] terminating line as instance id' => sub {
    my $provider = publiccloud::provider->new();
    my $out = <<'EOT';
Terminating instance i-999
IP of instance: 10.0.0.4
Created log file /tmp/l
Created results file /tmp/r
tests=1|pass=1|skip=0|fail=0|error=0
EOT
    my $res = $provider->parse_img_proof_output($out);
    is($res->{instance_id}, 'i-999', 'instance id taken from Terminating line');
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

# helper used by the provider-name subtest
sub _unset { for my $k (@_) { set_var($k, undef) } }

done_testing;
