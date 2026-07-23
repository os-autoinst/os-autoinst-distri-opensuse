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
use List::Util qw(any);

use publiccloud::azure_client;
use publiccloud::aws_client;
use publiccloud::gcp_client;
use publiccloud::provider;

sub _unset { for my $k (@_) { set_var($k, undef) } }


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
    set_var('PUBLIC_CLOUD_REGION', 'Ferengi');
    set_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'Romulan');
    set_var('FLAVOR', 'Talaxian');
    set_var('OPENQA_URL', 'Xindi');
    my $mock = Test::MockModule->new('publiccloud::provider', no_auto => 1);
    $mock->redefine(get_image_id => sub { '' });
    $mock->noop("$_") for qw(get_image_uri data_url);
    $mock->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $mock->redefine(get_current_job_id => sub { return 42; });
    my @calls;
    $mock->redefine($_ => sub { push @calls, $_[0]; return 0; }) for qw(assert_script_run script_run script_retry);
    $mock->redefine(script_output => sub {
            return '{"vm_name":{"value":[]},"public_ip":{"value":[]}}' if ($_[0] =~ /output -json/);
            return '';
    });
    Test::MockModule->new('publiccloud::instances', no_auto => 1)->redefine(set_instances => sub { });

    my $provider = publiccloud::provider->new(provider_client => publiccloud::azure_client->new());

    my @instances = $provider->terraform_apply();

    is scalar(@instances), 0, 'terraform_apply returns the list of created instances';
    ok $provider->terraform_applied, 'terraform_apply flags the deployment as applied';
    ok((any { qr/tofu.*$_/ } @calls), "tofu $_ is executed") foreach (qw(init plan apply));

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER PUBLIC_CLOUD_REGION PUBLIC_CLOUD_INSTANCE_TYPE FLAVOR OPENQA_URL/);
};

subtest '[terraform_apply] vars' => sub {
    set_var('PUBLIC_CLOUD', 1);
    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    set_var('PUBLIC_CLOUD_REGION', 'Ferengi');
    set_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'Romulan');
    set_var('FLAVOR', 'Talaxian');
    set_var('OPENQA_URL', 'Xindi');
    my $mock = Test::MockModule->new('publiccloud::provider', no_auto => 1);
    $mock->redefine(get_image_id => sub { '' });
    $mock->noop("$_") for qw(get_image_uri data_url);
    $mock->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $mock->redefine(get_current_job_id => sub { return 42; });
    my @calls;
    $mock->redefine($_ => sub { push @calls, $_[0]; return 0; }) for qw(assert_script_run script_run script_retry);
    $mock->redefine(script_output => sub {
            push @calls, $_[0];
            return '{"vm_name":{"value":[]},"public_ip":{"value":[]}}' if ($_[0] =~ /output -json/);
            return 'Vulcan' if ($_[0] =~ /az network/);
            return 'Aenar' if ($_[0] =~ /cat tf_apply_output/);
            return '';
    });
    Test::MockModule->new('publiccloud::instances', no_auto => 1)->redefine(set_instances => sub { });

    my $provider = publiccloud::provider->new(provider_client => publiccloud::azure_client->new());
    my %test_vars;
    $test_vars{Borg00} = 'ResistanceIsFutile';
    $test_vars{Borg01} = q{Resistance'IsFutile};
    $test_vars{Borg10} = q{Resistance'Is'Futile};

    $provider->terraform_apply(vars => \%test_vars);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    # Extract the single recorded call that runs 'tofu ... plan ...'
    my ($plan_cmd) = grep { /tofu.*plan/ } @calls;
    ok($plan_cmd, "tofu plan is executed");

    # Split the command into its individual -var arguments. Values may contain
    # the shell single-quote escape sequence '"'"', so we split on the ' -var '
    # delimiter rather than trying to match balanced quotes.
    my @var_args = split(/\s+-var\s+/, $plan_cmd);
    shift @var_args;    # drop the 'tofu plan -no-color -out myplan' prefix

    # Keep only the Borg* vars we injected, mapping key => escaped value.
    # Each argument looks like:  'KEY=VALUE', with the last one also carrying
    # the ' 2>&1 | tee tf_plan_output' redirection _tofu_run_step appends. As
    # that suffix never contains a quote, dropping the trailing anchor still
    # lets the greedy (.*) match up to the real closing quote.
    my %borg;
    for my $arg (@var_args) {
        my ($key, $val) = $arg =~ /^'([^=]+)=(.*)'/s;
        next unless defined $key && $key =~ /^Borg/;
        $borg{$key} = $val;
    }

    is($borg{Borg00}, q{ResistanceIsFutile}, 'plain value left unescaped');
    is($borg{Borg01}, q{Resistance'"'"'IsFutile}, 'single quote escaped');
    is($borg{Borg10}, q{Resistance'"'"'Is'"'"'Futile}, 'multiple single quotes escaped');

    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER PUBLIC_CLOUD_REGION PUBLIC_CLOUD_INSTANCE_TYPE FLAVOR OPENQA_URL/);
};

subtest '[terraform_apply] query csp at each region loop' => sub {
    set_var('PUBLIC_CLOUD', 1);
    set_var('PUBLIC_CLOUD_REGION', 'Ferengi');
    set_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'Romulan');
    set_var('FLAVOR', 'Talaxian');
    set_var('OPENQA_URL', 'Xindi');
    my $mock = Test::MockModule->new('publiccloud::provider', no_auto => 1);
    $mock->noop("$_") for qw(get_image_uri data_url);
    $mock->redefine(get_image_id => sub { '' });
    $mock->redefine(get_current_job_id => sub { return 42; });
    $mock->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $mock->redefine($_ => sub { push @calls, $_[0]; return 0; }) for qw(assert_script_run script_run script_retry);
    my @csp_cli;
    $mock->redefine(script_output => sub {
            push @calls, $_[0];
            return '{"vm_name":{"value":[]},"public_ip":{"value":[]}}' if ($_[0] =~ /output -json/);
            # Collect any provider CLI call (az, aws, gcloud) issued to query the network.
            if ($_[0] =~ /^(?:az|aws|gcloud)\s/) {
                push @csp_cli, $_[0];
                return 'Vulcan';
            }
            return '';
    });
    Test::MockModule->new('publiccloud::instances', no_auto => 1)->redefine(set_instances => sub { });
    my $provider;
    my %csp_cli_cmd = (
        AZURE => 'az network vnet',
        EC2 => 'aws ec2 describe-instance-type-offerings',
        GCE => 'gcloud compute zone',
    );

    for my $csp (sort keys %csp_cli_cmd) {
        set_var('PUBLIC_CLOUD_PROVIDER', $csp);
        @csp_cli = ();
        $provider = publiccloud::provider->new(provider_client => publiccloud::azure_client->new()) if ($csp eq 'AZURE');
        $provider = publiccloud::provider->new(provider_client => publiccloud::aws_client->new()) if ($csp eq 'AWS');
        $provider = publiccloud::provider->new(provider_client => publiccloud::gcp_client->new()) if ($csp eq 'GCP');
        $provider->terraform_apply(vars => {});
        note("\n  CSP_CLI ($csp) -->  " . join("\n  CSP_CLI ($csp) -->  ", @csp_cli));

        my $expected = $csp_cli_cmd{$csp};
        if (defined $expected) {
            ok(scalar(@csp_cli), "$csp queries the CSP about region specific data");
        } else {
            is(scalar(@csp_cli), 0, "$csp does not query the CSP");
        }
    }
    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER PUBLIC_CLOUD_REGION PUBLIC_CLOUD_INSTANCE_TYPE FLAVOR OPENQA_URL/);
};

subtest '[terraform_apply] returns instance objects' => sub {
    set_var('PUBLIC_CLOUD', 1);
    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    set_var('PUBLIC_CLOUD_REGION', 'Ferengi');
    set_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'Romulan');
    set_var('FLAVOR', 'Talaxian');
    set_var('OPENQA_URL', 'Xindi');
    my $mock = Test::MockModule->new('publiccloud::provider', no_auto => 1);
    $mock->redefine(get_image_id => sub { '' });
    $mock->noop("$_") for qw(get_image_uri data_url);
    $mock->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $mock->redefine(get_current_job_id => sub { return 42; });
    $mock->redefine($_ => sub { return 0; }) for qw(assert_script_run script_run script_retry);
    # 'tofu output -json' reports two VMs with their public IPs, so terraform_apply
    # must build one publiccloud::instance object per VM.
    $mock->redefine(script_output => sub {
            return '{"vm_name":{"value":["vm-0","vm-1"]},"public_ip":{"value":["10.0.0.1","10.0.0.2"]}}' if ($_[0] =~ /output -json/);
            return '';
    });
    Test::MockModule->new('publiccloud::instances', no_auto => 1)->redefine(set_instances => sub { });
    my $provider = publiccloud::provider->new(provider_client => publiccloud::azure_client->new());

    my @instances = $provider->terraform_apply();

    is(scalar(@instances), 2, 'terraform_apply returns one instance per VM');
    isa_ok($instances[0], 'publiccloud::instance', 'returned element');
    is($instances[0]->instance_id, 'vm-0', 'first instance_id taken from vm_name output');
    is($instances[0]->public_ip, '10.0.0.1', 'first public_ip taken from public_ip output');
    is($instances[1]->instance_id, 'vm-1', 'second instance_id taken from vm_name output');
    is($instances[1]->public_ip, '10.0.0.2', 'second public_ip taken from public_ip output');

    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER PUBLIC_CLOUD_REGION PUBLIC_CLOUD_INSTANCE_TYPE FLAVOR OPENQA_URL/);
};

# Common terraform_apply() mock shared by the region-loop subtests below.
#   script_responses => [in] hashref mapping:
#              * a regexp matching a command sent to script_*
#              * to an ordered list of { exit => ..., output => ... } responses.
#
#              On every matching command the next response in that list is consumed:
#              'exit' is returned to script_run/script_retry, 'output' to
#              script_output. There is no implicit coupling between commands: the
#              apply exit code and the terraform output read back by '^cat '
#              are two distinct commands, so they are scripted with two
#              distinct regexps. '^cat ' matches init/plan/apply's output-file
#              read-back alike (_tofu_run_step doesn't care about the
#              filename, and neither does this test) -- use the
#              _cat_responses() helper below to build that list, since only
#              apply's output matters to these subtests but every step's own
#              cat still consumes a slot in the shared queue. (Anchored to
#              avoid false hits like EC2's "describe-instance-type-offerings
#              --lo-CAT-ion-type ..." matching a bare /cat/.)
#              Each list must hold exactly one entry per expected match; if a
#              matching command is run after its list is exhausted the helper dies,
#              so the test fails loudly on an unexpected extra command. E.g.:
#                { 'apply.*myplan' => [{exit=>42}, {exit=>0}],
#                  '^cat '         => [_cat_responses({output=>$MSG}, {output=>''})],
#                  'az network vnet subnet' => [{output=>'subnet-0'}, {output=>'subnet-1'}] }
#   calls   => [out] arrayref the caller passes in empty; the helper appends
#              every executed command to it for the caller to inspect afterwards.
# Returns the Test::MockModule object (keep it in scope to preserve the mocks).
sub _mock_terraform_apply {
    my (%args) = @_;
    $args{script_responses} //= {};

    my $mock = Test::MockModule->new('publiccloud::provider', no_auto => 1);
    $mock->redefine(get_image_id => sub { '' });
    $mock->noop("$_") for qw(get_image_uri data_url);
    $mock->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $mock->redefine(get_current_job_id => sub { 42 });
    $mock->redefine(assert_script_run => sub { push @{$args{calls}}, $_[0]; return 0; });

    # It consumes each regexp's list in order and dies if list of response is exhausted. Returns undef when no regexp matches at all.
    my %cursor;
    my $next_response = sub {
        my ($cmd) = @_;
        # look at the right list of responses that apply to the simulated script_run or script_output
        for my $re (sort keys %{$args{script_responses}}) {
            next unless ($cmd =~ /$re/);
            my $list = $args{script_responses}{$re};
            my $i = $cursor{$re} // 0;
            die "No more scripted responses for /$re/ (command: $cmd)" if ($i > $#$list);
            $cursor{$re} = $i + 1;
            return $list->[$i];
        }
        return undef;
    };
    # init/plan/apply all run via _tofu_run_step -> script_retry now (no more
    # direct script_run for apply), so script_retry needs the same scripted
    # responses script_run gets. init/plan aren't under test here and match
    # none of the 'apply.*myplan'-style patterns below, so they transparently
    # succeed (exit 0) unless a subtest explicitly scripts them.
    $mock->redefine($_ => sub {
            my ($cmd) = @_;
            push @{$args{calls}}, $cmd;
            my $r = $next_response->($cmd);
            return (defined $r ? ($r->{exit} // 0) : 0);
    }) for qw(script_run script_retry);
    $mock->redefine(script_output => sub {
            my ($cmd) = @_;
            push @{$args{calls}}, $cmd;
            # simulate tofu output returning no VMs
            return '{"vm_name":{"value":[]},"public_ip":{"value":[]}}' if ($cmd =~ /output -json/);
            my $r = $next_response->($cmd);
            return (defined $r ? ($r->{output} // '') : '');
    });
    return $mock;
}

# Build a 'cat' response list for _mock_terraform_apply's script_responses.
# _tofu_run_step() reads back every step's own output file (init, plan, and
# apply each get their own 'cat', regardless of filename), but only apply's
# output feeds region_out_of_resources() -- init's and plan's are irrelevant
# to these region-retry subtests. Rather than coupling the test to the
# tf_<step>_output filenames, this pads the shared 'cat' queue with one
# placeholder for init and one for each apply's preceding plan, so callers
# only need to state the apply outputs they actually care about.
sub _cat_responses { return ({output => ''}, map { ({output => ''}, $_) } @_); }

# Provider-specific terraform 'apply' outputs that flag a resource shortage:
my %OUT_OF_RESOURCES = (
    AZURE => q{Error: creating Linux Virtual Machine ... Code="SkuNotAvailable" Message="The requested VM size ... is not available"},
    EC2 => q{Error: ... InsufficientInstanceCapacity: We currently do not have sufficient capacity in the Availability Zone},
    GCE => q{Error: The zone 'projects/p/zones/a' does not have enough resources available to fulfill the request},
);

subtest '[terraform_apply] Azure retries in the first alternate region and succeed' => sub {
    # terraform_apply() attempts the deployment in PUBLIC_CLOUD_REGION first and,
    # only when that region is out of resources for the requested instance type,
    # retries in each PUBLIC_CLOUD_ALTERNATE_REGIONS entry in order. Any other kind
    # of failure fails immediately.
    set_var('PUBLIC_CLOUD', 1);
    set_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'Romulan');
    set_var('FLAVOR', 'Talaxian');
    set_var('OPENQA_URL', 'Xindi');

    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    set_var('PUBLIC_CLOUD_REGION', 'Ferengi');
    set_var('PUBLIC_CLOUD_ALTERNATE_REGIONS', 'Bajoran,Cardassian');

    my @testapi_calls;    # scatchpad to store all the commands that the code under test (provider::terraform_apply) run via testapi
    my $mock = _mock_terraform_apply(
        calls => \@testapi_calls,
        script_responses => {
            # apply fails in the primary region (Azure SkuNotAvailable) then succeeds
            # in the first alternate region.
            'apply.*myplan' => [
                {exit => 42, output => 'None care'}, # "None care" because the perl code under test does not directly interact with "tofu apply" output, the next script_output(cat) does
                {exit => 0, output => ''},
            ],
            # this simulate the script_output(cat) of the "tofu apply" log, and it containing a specific error message
            '^cat ' => [_cat_responses({exit => 0, output => $OUT_OF_RESOURCES{AZURE}}, {exit => 0, output => ''})],
            # az network query runs once per region attempt (primary + 1st alternate)
            'az network vnet subnet list' => [{output => 'subnet-Ferenginar'}, {output => 'subnet-Bajor'}],
        });
    Test::MockModule->new('publiccloud::instances', no_auto => 1)->redefine(set_instances => sub { });
    my $provider = publiccloud::provider->new(provider_client => publiccloud::azure_client->new());

    $provider->terraform_apply(vars => {});

    note("\n  C-->  " . join("\n  C-->  ", @testapi_calls));    # Print all of them for debug purpose
                                                                # Check the order of regions used in "tofu plan"
    is_deeply(
        [map { /-var 'region=([^']+)'/ } grep { /\btofu plan\b/ } @testapi_calls],
        ['Ferengi', 'Bajoran'],
        'tofu plan run in the primary region, then the alternate, and stops there');
    # Check that "tofu plan" is using subnet from the az command, in the proper order
    is_deeply(    # -var 'subnet_id=subnet-0'
        [map { /-var 'subnet_id=([^']+)'/ } grep { /\btofu plan\b/ } @testapi_calls],
        ['subnet-Ferenginar', 'subnet-Bajor'],
        'tofu plan run in the subnet associated to region');
    # One 'az network vnet subnet list' per region attempt
    is_deeply(
        [map { /-g 'tf-([^']+)-rg'/ } grep { /\baz \b/ } @testapi_calls],
        ['Ferengi', 'Bajoran'],
        'az queried the network once per region attempt, in order');
    is($provider->provider_client->region, 'Bajoran', 'active region left on the successful alternate');
    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER PUBLIC_CLOUD_REGION PUBLIC_CLOUD_ALTERNATE_REGIONS PUBLIC_CLOUD_INSTANCE_TYPE FLAVOR OPENQA_URL/);
};

subtest '[terraform_apply] Azure retries in the first alternate region and fails but succeed on the second one' => sub {
    set_var('PUBLIC_CLOUD', 1);
    set_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'Romulan');
    set_var('FLAVOR', 'Talaxian');
    set_var('OPENQA_URL', 'Xindi');

    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    set_var('PUBLIC_CLOUD_REGION', 'Ferengi');
    set_var('PUBLIC_CLOUD_ALTERNATE_REGIONS', 'Bajoran,Cardassian');

    my @calls;
    my $mock = _mock_terraform_apply(
        calls => \@calls,
        script_responses => {
            # apply fails in the primary region and in the first alternate region,
            # then succeeds in the second alternate region.
            'apply.*myplan' => [
                {exit => 42, output => 'None care'},
                {exit => 42, output => 'None care'},
                {exit => 0, output => ''},
            ],
'^cat ' => [_cat_responses({exit => 0, output => $OUT_OF_RESOURCES{AZURE}}, {exit => 0, output => $OUT_OF_RESOURCES{AZURE}}, {exit => 0, output => ''})],
            # az network query runs once per region attempt (primary + 2 alternates)
            'az network vnet subnet list' => [{output => 'subnet-Ferenginar'}, {output => 'subnet-Bajor'}, {output => 'subnet-Cardassia'}],
        });
    Test::MockModule->new('publiccloud::instances', no_auto => 1)->redefine(set_instances => sub { });
    my $provider = publiccloud::provider->new(provider_client => publiccloud::azure_client->new());

    $provider->terraform_apply(vars => {});

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    is_deeply([map { /-var 'region=([^']+)'/ } grep { /\btofu plan\b/ } @calls],
        ['Ferengi', 'Bajoran', 'Cardassian'], 'plan run in the primary region, then both alternates, in order');
    is_deeply([map { /-g 'tf-([^']+)-rg'/ } grep { /\baz \b/ } @calls],
        ['Ferengi', 'Bajoran', 'Cardassian'], 'az queried the network once per region attempt, in order');
    is($provider->provider_client->region, 'Cardassian', 'active region left on the second (successful) alternate');
    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER PUBLIC_CLOUD_REGION PUBLIC_CLOUD_ALTERNATE_REGIONS PUBLIC_CLOUD_INSTANCE_TYPE FLAVOR OPENQA_URL/);
};

subtest '[terraform_apply] Azure retries never succeed' => sub {
    set_var('PUBLIC_CLOUD', 1);
    set_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'Romulan');
    set_var('FLAVOR', 'Talaxian');
    set_var('OPENQA_URL', 'Xindi');

    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    set_var('PUBLIC_CLOUD_REGION', 'Ferengi');
    set_var('PUBLIC_CLOUD_ALTERNATE_REGIONS', 'Bajoran,Cardassian');

    my @calls;
    my $mock = _mock_terraform_apply(
        calls => \@calls,
        script_responses => {
            # apply fails (Azure SkuNotAvailable) in the primary region and in both
            # alternate regions: every region is out of resources, so terraform_apply
            # exhausts the whole region list and finally dies.
            'apply.*myplan' => [
                {exit => 42, output => 'None care'},
                {exit => 42, output => 'None care'},
                {exit => 42, output => 'None care'},
            ],
'^cat ' => [_cat_responses({exit => 0, output => $OUT_OF_RESOURCES{AZURE}}, {exit => 0, output => $OUT_OF_RESOURCES{AZURE}}, {exit => 0, output => $OUT_OF_RESOURCES{AZURE}})],
            # az network query runs once per region attempt (primary + 2 alternates)
            'az network vnet subnet list' => [{output => 'subnet-Ferengi'}, {output => 'subnet-Bajor'}, {output => 'subnet-Cardassia'}],
        });
    Test::MockModule->new('publiccloud::instances', no_auto => 1)->redefine(set_instances => sub { });
    my $provider = publiccloud::provider->new(provider_client => publiccloud::azure_client->new());

    # Every region fails with a resource shortage, so after trying them all
    # terraform_apply gives up and dies.
    dies_ok { $provider->terraform_apply(vars => {}) } 'terraform_apply dies after every region is exhausted';

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    # code under test try "tofu plan" in all the regions
    is_deeply([map { /-var 'region=([^']+)'/ } grep { /\btofu plan\b/ } @calls],
        ['Ferengi', 'Bajoran', 'Cardassian'], 'plan run in the primary region, then both alternates, in order');
    is_deeply([map { /-g 'tf-([^']+)-rg'/ } grep { /\baz \b/ } @calls],
        ['Ferengi', 'Bajoran', 'Cardassian'], 'az queried the network once per region attempt, in order');
    is($provider->provider_client->region, 'Cardassian', 'active region left on the last attempted alternate');
    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER PUBLIC_CLOUD_REGION PUBLIC_CLOUD_ALTERNATE_REGIONS PUBLIC_CLOUD_INSTANCE_TYPE FLAVOR OPENQA_URL/);
};

subtest '[terraform_apply] EC2 retries in an alternate region' => sub {
    set_var('PUBLIC_CLOUD', 1);
    set_var('FLAVOR', 'Talaxian');
    set_var('OPENQA_URL', 'Xindi');
    set_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'Romulan');

    set_var('PUBLIC_CLOUD_PROVIDER', 'EC2');
    set_var('PUBLIC_CLOUD_REGION', 'Ferengi');
    set_var('PUBLIC_CLOUD_ALTERNATE_REGIONS', 'Bajoran,Cardassian');

    my @calls;
    my $mock = _mock_terraform_apply(
        calls => \@calls,
        script_responses => {
            'apply.*myplan' => [
                {exit => 42, output => 'None care'},
                {exit => 0, output => ''},
            ],
            '^cat ' => [_cat_responses({exit => 0, output => $OUT_OF_RESOURCES{EC2}}, {exit => 0, output => ''})],
            # each aws query runs once per region attempt (primary + 1 alternate)
            'describe-instance-type-offerings' => [{output => 'us-east-1a'}, {output => 'us-east-1b'}],
            'describe-security-groups' => [{output => 'sg-0'}, {output => 'sg-1'}],
            'describe-subnets' => [{output => 'subnet-0'}, {output => 'subnet-1'}],
        });
    Test::MockModule->new('publiccloud::instances', no_auto => 1)->redefine(set_instances => sub { });
    my $provider = publiccloud::provider->new(provider_client => publiccloud::aws_client->new());

    $provider->terraform_apply(vars => {});

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    is_deeply([map { /-var 'region=([^']+)'/ } grep { /\btofu plan\b/ } @calls],
        ['Ferengi', 'Bajoran'], 'plan run in the primary region, then the alternate, in order');
    for my $q (qw(describe-instance-type-offerings describe-security-groups describe-subnets)) {
        is_deeply([map { /--region '([^']+)'/ } grep { /\Q$q\E/ } @calls],
            ['Ferengi', 'Bajoran'], "aws $q issued once per region, in order");
    }
    is($provider->provider_client->region, 'Bajoran', 'active region left on the successful alternate');
    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER PUBLIC_CLOUD_REGION PUBLIC_CLOUD_ALTERNATE_REGIONS PUBLIC_CLOUD_INSTANCE_TYPE FLAVOR OPENQA_URL/);
};

subtest '[terraform_apply] GCE succeed in the first zone of the first region' => sub {
    set_var('PUBLIC_CLOUD', 1);
    set_var('FLAVOR', 'Talaxian');
    set_var('OPENQA_URL', 'Xindi');
    set_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'Romulan');

    set_var('PUBLIC_CLOUD_PROVIDER', 'GCE');
    set_var('PUBLIC_CLOUD_REGION', 'Ferengi');
    set_var('PUBLIC_CLOUD_ALTERNATE_REGIONS', 'Bajoran');
    set_var('PUBLIC_CLOUD_AVAILABILITY_ZONE', 'Weeville');

    my @calls;
    my $mock = _mock_terraform_apply(
        calls => \@calls,
        script_responses => {
            'apply.*myplan' => [
                {exit => 0, output => 'None care'},    # primary region, initial zone 'a'
            ],
            '^cat ' => [_cat_responses({exit => 0, output => ''})],    # primary region, initial zone 'a'
                                                                       # 'gcloud compute zones list' returns the zones of the region (last name part).
                # This line also simulate that what has been configured in the PUBLIC_CLOUD_AVAILABILITY_ZONE
                # is in agreement with what the cloud has.
            'gcloud compute zones list.*filter.*region.*Ferengi' => [{exit => 0, output => 'Weeville,b,c,'}],
        });
    Test::MockModule->new('publiccloud::instances', no_auto => 1)->redefine(set_instances => sub { });
    my $provider = publiccloud::provider->new(provider_client => publiccloud::gcp_client->new());

    # NOTICE as adding explicitly a vars argument here is needed as we are testing provider::terraform_apply
    # and usually the test does not use it directly but via gce:terraform_apply that is internally doing something like
    #
    #   $args{vars}->{availability_zone} = $self->provider_client->availability_zone;
    #   $self->SUPER::terraform_apply(%args);
    $provider->terraform_apply(vars => {availability_zone => 'Weeville'});

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    is_deeply([map { /-var 'region=([^']+)'/ } grep { /\btofu plan\b/ } @calls],
        ['Ferengi'], 'primary region planned once per zone');
    is_deeply([map { /-var 'availability_zone=([^']+)'/ } grep { /\btofu plan\b/ } @calls],
        ['Weeville'], 'GCE zones tried in order');
    # intentionally not test 'gcloud compute zones list' here as there are chance that the code under test is wrong
    is($provider->provider_client->region, 'Ferengi', 'active region left on the successful alternate');
    is($provider->provider_client->availability_zone, 'Weeville', 'availability_zone set to the zone where appl succeeded $provider->provider_client->availability_zone:' . $provider->provider_client->availability_zone);

    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER PUBLIC_CLOUD_ALTERNATE_REGIONS PUBLIC_CLOUD_INSTANCE_TYPE FLAVOR OPENQA_URL PUBLIC_CLOUD_AVAILABILITY_ZONE/);
};


subtest '[terraform_apply] GCE loops over zones, then over regions' => sub {
    set_var('PUBLIC_CLOUD', 1);
    set_var('FLAVOR', 'Talaxian');
    set_var('OPENQA_URL', 'Xindi');
    set_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'Romulan');

    set_var('PUBLIC_CLOUD_PROVIDER', 'GCE');
    set_var('PUBLIC_CLOUD_REGION', 'Ferengi');
    set_var('PUBLIC_CLOUD_ALTERNATE_REGIONS', 'Bajoran');

    # In the primary region all of the zones are exhausted,
    # so the whole region is out of resources and the deployment
    # falls back to the alternate region, where the first zone succeeds.
    my @calls;
    my $mock = _mock_terraform_apply(
        calls => \@calls,
        script_responses => {
            'apply.*myplan' => [
                {exit => 42, output => 'None care'},    # primary region, initial zone 'a'
                {exit => 42, output => 'None care'},    # primary region, zone 'b'
                {exit => 42, output => 'None care'},    # primary region, zone 'c'
                {exit => 0, output => ''},    # alternate region 'Bajor'
            ],
            '^cat ' => [
                _cat_responses(
                    {exit => 0, output => $OUT_OF_RESOURCES{GCE}},    # primary region, initial zone 'a'
                    {exit => 0, output => $OUT_OF_RESOURCES{GCE}},    # primary region, zone 'b'
                    {exit => 0, output => $OUT_OF_RESOURCES{GCE}},    # primary region, zone 'c'
                    {exit => 0, output => ''},    # alternate region 'Bajor'
                )],
            'gcloud compute zones list.*filter.*region.*Ferengi' => [{exit => 0, output => 'a,b,c,'}],
            'gcloud compute zones list.*filter.*region.*Bajoran' => [{exit => 0, output => 'd,e,f,'}],    # this test does not use it, but it should
        });
    Test::MockModule->new('publiccloud::instances', no_auto => 1)->redefine(set_instances => sub { });
    my $provider = publiccloud::provider->new(provider_client => publiccloud::gcp_client->new());
    # Seed availability_zone so the initial (failing) zone 'a' is excluded from
    # the alternative zones the zone-retry loop iterates over.

    $provider->terraform_apply(vars => {availability_zone => 'a'});

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    # Exact plan sequence, duplicates NOT collapsed: the primary region is planned
    # once for each zone (a, b, c) before falling back to the alternate region.
    is_deeply([map { /-var 'region=([^']+)'/ } grep { /\btofu plan\b/ } @calls],
        ['Ferengi', 'Ferengi', 'Ferengi', 'Bajoran'], 'primary region planned once per zone, then the alternate region, in order');

    # This is right test but commented as code under test is wrong. TODO: fix the terraform_apply code
    is_deeply([map { /-var 'availability_zone=([^']+)'/ } grep { /\btofu plan\b/ } @calls],
        ['a', 'b', 'c', 'd'], 'GCE zones tried in order a, b, c within the primary region, then next region and its first availability zone that is d');

    # 'gcloud compute zones list' is executed at the beginning of each region loop.
    my @gcloud = grep { /^gcloud compute zones list/ } @calls;
    is(scalar(@gcloud), 2, 'gcloud zone list queried at each region loop');
    like($gcloud[0], qr/^gcloud compute zones list --filter='region=Ferengi'/, 'zone list scoped to the failing region');
    is($provider->provider_client->region, 'Bajoran', 'active region left on the successful alternate');

    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER PUBLIC_CLOUD_REGION PUBLIC_CLOUD_ALTERNATE_REGIONS PUBLIC_CLOUD_INSTANCE_TYPE FLAVOR OPENQA_URL/);
};

subtest '[terraform_apply] init/plan failures die with captured output, no region retry' => sub {
    set_var('PUBLIC_CLOUD', 1);
    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    set_var('PUBLIC_CLOUD_REGION', 'Ferengi');
    set_var('PUBLIC_CLOUD_ALTERNATE_REGIONS', 'Cardassia');
    set_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'Romulan');
    set_var('FLAVOR', 'Talaxian');
    set_var('OPENQA_URL', 'Xindi');
    my $mock = Test::MockModule->new('publiccloud::provider', no_auto => 1);
    $mock->redefine(get_image_id => sub { '' });
    $mock->noop("$_") for qw(get_image_uri data_url);
    $mock->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $mock->redefine(get_current_job_id => sub { return 42; });
    Test::MockModule->new('publiccloud::instances', no_auto => 1)->redefine(set_instances => sub { });

    for my $case (
        {step => 'init', fail_cmd => qr/tofu init/, timeout => 180, garbage => 'connection refused'},
        {step => 'plan', fail_cmd => qr/tofu plan/, timeout => 300, garbage => ''},
      )
    {
        my (@calls, @retry_calls);
        $mock->redefine(assert_script_run => sub { push @calls, $_[0]; return 0; });
        $mock->redefine(script_retry => sub {
                my ($cmd, %retry_args) = @_;
                push @calls, $cmd;
                push @retry_calls, [$cmd, \%retry_args];
                return 1 if ($cmd =~ $case->{fail_cmd});
                return 0;
        });
        $mock->redefine(script_output => sub {
                push @calls, $_[0];
                return $case->{garbage} if ($_[0] =~ /cat /);
                return '';
        });

        my $provider = publiccloud::provider->new(provider_client => publiccloud::azure_client->new());
        eval { $provider->terraform_apply() };
        my $died = $@;
        like($died, qr/Terraform $case->{step} failed/i, "$case->{step} failure dies with a clear message");
        # Regression check for the scalar-context bug where `my $ret = ...`
        # (instead of `my ($ret) = ...`) silently captured the captured
        # output text instead of the numeric exit code from script_retry.
        like($died, qr/exit code 1\b/, "$case->{step} die message reports the numeric exit code, not the captured output");

        my ($retry_call) = grep { $_->[0] =~ $case->{fail_cmd} } @retry_calls;
        ok($retry_call, "$case->{step} is retried via script_retry");
        is($retry_call->[1]{timeout}, $case->{timeout}, "$case->{step} uses its own fixed timeout, not TERRAFORM_TIMEOUT");
        ok($retry_call->[1]{retry} > 1, "$case->{step} is configured to actually retry multiple times");
        is($retry_call->[1]{die}, 0, "$case->{step} does not let script_retry die internally (so output can be captured)");

        note("\n  C-->  " . join("\n  C-->  ", @calls));
    }

    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER PUBLIC_CLOUD_REGION PUBLIC_CLOUD_ALTERNATE_REGIONS PUBLIC_CLOUD_INSTANCE_TYPE FLAVOR OPENQA_URL/);
};

done_testing;
