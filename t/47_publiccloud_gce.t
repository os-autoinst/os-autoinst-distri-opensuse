# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Unit tests for publiccloud::gce -- image file->name normalization,
# guest OS feature lookup, image id project prefixing, gcloud describe/state
# helpers and metadata query (gcloud layer mocked).
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;

# Neutralize sleep() process-wide so any state-polling loop does not spend real
# wall-clock seconds during unit tests. Installed in BEGIN so it is in effect
# before the modules under test are compiled.
BEGIN { *CORE::GLOBAL::sleep = sub { }; }

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Exception;
use Test::Warnings;
use testapi 'set_var';

use publiccloud::gce;

subtest '[file2name] normalizes to GCE-allowed name' => sub {
    my $provider = publiccloud::gce->new();
    is($provider->file2name('SLES15-SP6.x86_64-1.0.0-GCE-Build1.1.tar.gz'),
        'sles15-sp6-x8664-1-0-0-gce-build1-1',
        'lowercased, tar.gz stripped, dots to dashes, underscore dropped');
    is($provider->file2name('Foo.Bar.tar.gz'), 'foo-bar', 'dots become dashes');
    is($provider->file2name('UPPER'), 'upper', 'uppercase lowercased');
};

subtest '[get_gcp_guest_os_features] returns feature list' => sub {
    my $provider = publiccloud::gce->new();
    my $feat = $provider->get_gcp_guest_os_features('SLES15-SP6.x86_64.tar.gz');
    like($feat, qr/GVNIC/, 'includes GVNIC');
    like($feat, qr/UEFI_COMPATIBLE/, 'includes UEFI_COMPATIBLE');
    like($feat, qr/TDX_CAPABLE/, 'SP6 includes TDX_CAPABLE');
    is(ref \$feat, 'SCALAR', 'returns a comma-joined string');

    my $sp5 = $provider->get_gcp_guest_os_features('SLES15-SP5-foo');
    unlike($sp5, qr/TDX_CAPABLE/, 'SP5 does not include TDX_CAPABLE');
};

subtest '[get_gcp_guest_os_features] dies on unsupported OS' => sub {
    my $provider = publiccloud::gce->new();
    # the lib interpolates an undef $os_version into the die message; silence that
    local $SIG{__WARN__} = sub { };
    throws_ok { $provider->get_gcp_guest_os_features('UnknownDistro-1') }
    qr/Unsupported OS/, 'dies for OS not in the feature table';
};

subtest '[get_image_id] prefixes with project when set' => sub {
    my $provider = publiccloud::gce->new();
    my $mod = Test::MockModule->new('publiccloud::gce', no_auto => 1);
    # Stub the parent get_image_id via the SUPER:: path
    my $parent = Test::MockModule->new('publiccloud::provider', no_auto => 1);
    $parent->redefine(get_image_id => sub { 'my-image' });

    set_var('PUBLIC_CLOUD_IMAGE_PROJECT', undef);
    is($provider->get_image_id('url'), 'my-image', 'no prefix without project');

    set_var('PUBLIC_CLOUD_IMAGE_PROJECT', 'suse-proj');
    is($provider->get_image_id('url'), 'suse-proj/my-image', 'prefixes project/');

    _unset('PUBLIC_CLOUD_IMAGE_PROJECT');
};

subtest '[describe_instance] composes gcloud + jq' => sub {
    my $provider = publiccloud::gce->new();
    my $mod = Test::MockModule->new('publiccloud::gce', no_auto => 1);
    my $seen;
    $mod->redefine(script_output => sub { $seen = $_[0]; return 'RUNNING' });

    my $res = $provider->describe_instance('vm-1', '.[0].status');
    is($res, 'RUNNING', 'returns script_output');
    like($seen, qr/gcloud compute instances list/, 'uses gcloud instances list');
    like($seen, qr/vm-1/, 'filters by instance id');
    like($seen, qr/\.\[0\]\.status/, 'applies jq query');
};

subtest '[get_state_from_instance] returns status or dies' => sub {
    my $provider = publiccloud::gce->new();
    my $mod = Test::MockModule->new('publiccloud::gce', no_auto => 1);
    my $inst = Test::MockObject->new;
    $inst->mock(instance_id => sub { 'vm-1' });

    $mod->redefine(describe_instance => sub { 'RUNNING' });
    is($provider->get_state_from_instance($inst), 'RUNNING', 'returns status');

    $mod->redefine(describe_instance => sub { '' });
    throws_ok { $provider->get_state_from_instance($inst) } qr/Unable to get status/, 'dies on empty status';
};

subtest '[get_public_ip] returns natIP or dies' => sub {
    my $provider = publiccloud::gce->new();
    my $mod = Test::MockModule->new('publiccloud::gce', no_auto => 1);
    $mod->redefine(get_terraform_output => sub { 'vm-1' });

    $mod->redefine(describe_instance => sub { '203.0.113.20' });
    is($provider->get_public_ip(), '203.0.113.20', 'returns natIP');

    $mod->redefine(describe_instance => sub { '' });
    throws_ok { $provider->get_public_ip() } qr/Unable to get public_ip/, 'dies on empty natIP';
};

subtest '[query_metadata] uses Google metadata flavor header' => sub {
    my $provider = publiccloud::gce->new();
    my $inst = Test::MockObject->new;
    my $seen;
    $inst->mock(ssh_script_output => sub { my ($s, $c) = @_; $seen = $c; return '10.2.3.4' });

    is($provider->query_metadata($inst), '10.2.3.4', 'returns metadata payload');
    like($seen, qr/Metadata-Flavor: Google/, 'uses Google metadata header');
    like($seen, qr{computeMetadata/v1/instance/network-interfaces/0/ip}, 'queries network interface ip path');
};

subtest '[suspend_instance] only when running' => sub {
    my $provider = publiccloud::gce->new();
    my $mod = Test::MockModule->new('publiccloud::gce', no_auto => 1);
    my @asr;
    $mod->redefine(assert_script_run => sub { push @asr, $_[0]; return 0 });

    my $inst = Test::MockObject->new;
    $inst->mock(instance_id => sub { 'vm-1' });
    $inst->mock(wait_for_state => sub { return });

    $mod->redefine(get_state_from_instance => sub { 'RUNNING' });
    lives_ok { $provider->suspend_instance($inst) } 'suspends a running instance';
    ok((grep { /instances suspend vm-1/ } @asr), 'issues gcloud suspend');

    $mod->redefine(get_state_from_instance => sub { 'TERMINATED' });
    throws_ok { $provider->suspend_instance($inst) }
    qr/Cannot suspend instance which is not running/, 'dies when not running';
};

sub _unset { for my $k (@_) { set_var($k, undef) } }

done_testing;
