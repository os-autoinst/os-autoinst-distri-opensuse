# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Unit tests for publiccloud::img_proof helper functions
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Exception;
use Test::Warnings;
use testapi 'set_var';

use publiccloud::img_proof qw(run_img_proof);

sub _unset { for my $k (@_) { set_var($k, undef) } }

sub mock_script_output {
    my ($mock, %args) = @_;
    my $eol = $args{eol} // "\n";
    my $calls = $args{calls};
    my @lines = $args{lines} ? @{$args{lines}} : (
        $args{instance_hdr} // 'ID of instance: i-0123456789abcdef0',
        'IP of instance: 192.168.1.100',
        'Created log file /tmp/img_proof.log',
        'Created results file /tmp/results.json',
        'tests=10|pass=8|skip=1|fail=1|error=0',
    );

    if (defined $args{num_lines}) {
        @lines = @lines[0 .. ($args{num_lines} - 1)];
    }

    $mock->redefine(script_output => sub {
            push @$calls, $_[0] if $calls;
            if ($_[0] =~ /img-proof --version/) {
                return $args{version} // 'img-proof 1.0';
            }
            return join($eol, @lines) . $eol;
    });
}

subtest '[run_img_proof] missing instance argument' => sub {
    my $dummy_provider = Test::MockObject->new();
    dies_ok { run_img_proof($dummy_provider, provider => 'azure') } 'dies when instance argument is missing';
};

subtest '[run_img_proof] parses valid output with LF and CRLF line endings' => sub {
    my @calls;
    for my $eol_test ("\n", "\r\n") {
        @calls = ();
        my $mock = Test::MockModule->new('publiccloud::img_proof', no_auto => 1);
        mock_script_output($mock, calls => \@calls, eol => $eol_test);
        $mock->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
        $mock->redefine(is_ec2 => sub { 0 });
        $mock->redefine(is_gce => sub { 0 });
        $mock->redefine(is_hardened => sub { 0 });

        my $assigned_ip;
        my $instance = Test::MockObject->new();
        $instance->mock('instance_id', sub { 'i-0123456789abcdef0' });
        $instance->mock('public_ip', sub { $assigned_ip = $_[1] if @_ > 1; return $assigned_ip; });

        my $provider_client = Test::MockObject->new();
        $provider_client->mock('region', sub { 'valhalla' });

        my $provider = Test::MockObject->new();
        $provider->mock('provider_client', sub { $provider_client });
        $provider->mock('ssh_key', sub { '/path/to/key' });

        my $res = run_img_proof(
            $provider,
            provider => 'azure',
            instance => $instance,
        );

        note("\n  -->  " . join("\n  -->  ", @calls));
        my $label = ($eol_test eq "\r\n") ? 'CRLF' : 'LF';
        is($assigned_ip, '192.168.1.100', "[$label] assigned instance public IP");
        is($res->{logfile}, '/tmp/img_proof.log', "[$label] parsed logfile path");
        is($res->{results}, '/tmp/results.json', "[$label] parsed results path");
        is($res->{tests}, 10, "[$label] parsed test count");
        is($res->{pass}, 8, "[$label] parsed pass count");
        is($res->{skip}, 1, "[$label] parsed skip count");
        is($res->{fail}, 1, "[$label] parsed fail count");
        is($res->{error}, 0, "[$label] parsed error count");
        ok(!exists $res->{instance_id}, "[$label] instance_id deleted from return hash");
        ok(!exists $res->{ip}, "[$label] ip deleted from return hash");
    }
};

subtest '[run_img_proof] parses alternative Terminating instance output line' => sub {
    my @calls;
    my $mock = Test::MockModule->new('publiccloud::img_proof', no_auto => 1);
    mock_script_output($mock, calls => \@calls, instance_hdr => 'Terminating instance i-99999999');
    $mock->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $mock->redefine(is_ec2 => sub { 0 });
    $mock->redefine(is_gce => sub { 0 });
    $mock->redefine(is_hardened => sub { 0 });

    my $assigned_ip;
    my $instance = Test::MockObject->new();
    $instance->mock('instance_id', sub { 'i-99999999' });
    $instance->mock('public_ip', sub { $assigned_ip = $_[1] if @_ > 1; return $assigned_ip; });

    my $provider_client = Test::MockObject->new();
    $provider_client->mock('region', sub { 'eu-central-1' });

    my $provider = Test::MockObject->new();
    $provider->mock('provider_client', sub { $provider_client });
    $provider->mock('ssh_key', sub { '/path/to/key' });

    my $res = run_img_proof(
        $provider,
        provider => 'azure',
        instance => $instance,
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    is($assigned_ip, '192.168.1.100', 'assigned instance public IP');
    is($res->{pass}, 8, 'parsed pass count');
};

subtest '[run_img_proof] dies on incomplete / unparseable output' => sub {
    my @calls;
    my $mock = Test::MockModule->new('publiccloud::img_proof', no_auto => 1);
    mock_script_output($mock, calls => \@calls, num_lines => 3);
    $mock->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $mock->redefine(is_ec2 => sub { 0 });
    $mock->redefine(is_gce => sub { 0 });
    $mock->redefine(is_hardened => sub { 0 });

    my $instance = Test::MockObject->new();
    $instance->mock('instance_id', sub { 'i-123' });

    my $provider_client = Test::MockObject->new();
    $provider_client->mock('region', sub { 'region1' });

    my $provider = Test::MockObject->new();
    $provider->mock('provider_client', sub { $provider_client });
    $provider->mock('ssh_key', sub { '/path/key' });

    dies_ok {
        run_img_proof(
            $provider,
            provider => 'azure',
            instance => $instance,
        );
    } 'dies when output is missing required parsed fields';
};

subtest '[run_img_proof] EC2 provider command structure & flags' => sub {
    my @calls;
    my $mock = Test::MockModule->new('publiccloud::img_proof', no_auto => 1);
    mock_script_output($mock, calls => \@calls);
    $mock->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $mock->redefine(is_ec2 => sub { 1 });
    $mock->redefine(is_gce => sub { 0 });
    $mock->redefine(is_hardened => sub { 0 });

    my $assigned_ip;
    my $instance = Test::MockObject->new();
    $instance->mock('instance_id', sub { 'i-ec2-123' });
    $instance->mock('public_ip', sub { $assigned_ip = $_[1] if @_ > 1; return $assigned_ip; });

    my $provider_client = Test::MockObject->new();
    $provider_client->mock('region', sub { 'us-east-1' });

    my $provider = Test::MockObject->new();
    $provider->mock('provider_client', sub { $provider_client });
    $provider->mock('ssh_key', sub { '/path/to/key.pem' });

    my $res = run_img_proof(
        $provider,
        provider => 'ec2',
        instance => $instance,
        credentials_file => 'aws_creds.json',
        key_name => 'my_key',
        user => 'ec2-user',
        exclude => 'test_a, test_b',
        beta => 1,
        tests => 'test_security',
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    is($assigned_ip, '192.168.1.100', 'instance public_ip assigned');
    is($res->{pass}, 8, 'result pass count');

    my $cmd = (grep { /img-proof --no-color test ec2/ } @calls)[0];
    ok($cmd, 'img-proof command found');
    ok($cmd =~ /--access-key-id \$AWS_ACCESS_KEY_ID --secret-access-key \$AWS_SECRET_ACCESS_KEY/, 'contains AWS credentials');
    ok($cmd =~ /--service-account-file "aws_creds.json"/, 'contains credentials_file');
    ok($cmd =~ /--ssh-key-name \$\(realpath my_key\)/, 'contains ssh key name');
    ok($cmd =~ /-u ec2-user/, 'contains user');
    ok($cmd =~ /--beta/, 'contains beta flag');
    ok($cmd =~ /--exclude test_a --exclude test_b/, 'contains exclusions');
    ok($cmd =~ /test_security/, 'contains test target');
};

subtest '[run_img_proof] GCE provider region formatting' => sub {
    my @calls;
    my $mock = Test::MockModule->new('publiccloud::img_proof', no_auto => 1);
    mock_script_output($mock, calls => \@calls);
    $mock->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $mock->redefine(is_ec2 => sub { 0 });
    $mock->redefine(is_gce => sub { 1 });
    $mock->redefine(is_hardened => sub { 0 });

    my $instance = Test::MockObject->new();
    $instance->mock('instance_id', sub { 'gce-inst' });
    $instance->mock('public_ip', sub { });

    my $provider_client = Test::MockObject->new();
    $provider_client->mock('region', sub { 'us-central1' });
    $provider_client->mock('availability_zone', sub { 'a' });

    my $provider = Test::MockObject->new();
    $provider->mock('provider_client', sub { $provider_client });
    $provider->mock('ssh_key', sub { '/path/to/key' });

    run_img_proof(
        $provider,
        provider => 'gce',
        instance => $instance,
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    my $cmd = (grep { /img-proof --no-color test gce/ } @calls)[0];
    ok($cmd =~ /--region "us-central1-a"/, 'GCE region includes availability zone');
};

subtest '[run_img_proof] hardened image SCAP_REPORT' => sub {
    my @calls;
    my $mock = Test::MockModule->new('publiccloud::img_proof', no_auto => 1);
    mock_script_output($mock, calls => \@calls);
    $mock->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $mock->redefine(is_ec2 => sub { 0 });
    $mock->redefine(is_gce => sub { 0 });
    $mock->redefine(is_hardened => sub { 1 });

    set_var('SCAP_REPORT', 'full');

    my $instance = Test::MockObject->new();
    $instance->mock('instance_id', sub { 'hard-inst' });
    $instance->mock('public_ip', sub { });

    my $provider_client = Test::MockObject->new();
    $provider_client->mock('region', sub { 'westeurope' });

    my $provider = Test::MockObject->new();
    $provider->mock('provider_client', sub { $provider_client });
    $provider->mock('ssh_key', sub { '/path/to/key' });

    run_img_proof(
        $provider,
        provider => 'azure',
        instance => $instance,
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    my $cmd = (grep { /img-proof --no-color test azure/ } @calls)[0];
    ok($cmd =~ /^SCAP_REPORT=full img-proof/, 'hardened image prefixes command with SCAP_REPORT');

    _unset('SCAP_REPORT');
};

done_testing;
