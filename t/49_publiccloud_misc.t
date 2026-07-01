# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Unit tests for publiccloud::basetest (provider_factory routing,
# finalize/cleanup) and publiccloud::k8sbasetest (service name mapping).
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Exception;
use Test::Warnings;
use testapi qw(set_var get_var);

use publiccloud::basetest;
use publiccloud::k8sbasetest;
use publiccloud::ssh_interactive;

sub _unset { for my $k (@_) { set_var($k, undef) } }

# ---------------------------------------------------------------------------
# basetest::provider_factory routing
# ---------------------------------------------------------------------------

# Stub init on every concrete provider so no real cloud auth happens, and
# return the class that provider_factory instantiated.
sub _factory_for {
    my ($provider, $service) = @_;
    my @keep;
    for my $cls (qw/publiccloud::ec2 publiccloud::ecr publiccloud::eks
        publiccloud::azure publiccloud::acr publiccloud::aks
        publiccloud::gce publiccloud::gcr publiccloud::gke/) {
        my $m = Test::MockModule->new($cls, no_auto => 1);
        $m->redefine(init => sub { return $_[0] });
        push @keep, $m;
    }
    my $base = publiccloud::basetest->new();
    my %args = (provider => $provider);
    $args{service} = $service if defined $service;
    my $got = $base->provider_factory(%args);
    return ref $got;
}

subtest '[provider_factory] EC2 services' => sub {
    is(_factory_for('EC2'), 'publiccloud::ec2', 'EC2 default -> ec2');
    is(_factory_for('EC2', 'ECR'), 'publiccloud::ecr', 'EC2/ECR -> ecr');
    is(_factory_for('EC2', 'EKS'), 'publiccloud::eks', 'EC2/EKS -> eks');
};

subtest '[provider_factory] AZURE services' => sub {
    is(_factory_for('AZURE'), 'publiccloud::azure', 'AZURE default -> azure');
    is(_factory_for('AZURE', 'AKS'), 'publiccloud::aks', 'AZURE/AKS -> aks');
    is(_factory_for('AZURE', 'ACR'), 'publiccloud::acr', 'AZURE/ACR -> acr');
};

subtest '[provider_factory] GCE services' => sub {
    is(_factory_for('GCE'), 'publiccloud::gce', 'GCE default -> gce');
    is(_factory_for('GCE', 'GCR'), 'publiccloud::gcr', 'GCE/GCR -> gcr');
    is(_factory_for('GCE', 'GKE'), 'publiccloud::gke', 'GCE/GKE -> gke');
};

subtest '[provider_factory] error paths' => sub {
    throws_ok { _factory_for('NOPE') } qr/Unknown PUBLIC_CLOUD_PROVIDER/, 'unknown provider dies';
    throws_ok { _factory_for('EC2', 'BOGUS') } qr/Unknown service given/, 'unknown EC2 service dies';

    # Refuses to re-initialize an already-initialized provider
    my $m = Test::MockModule->new('publiccloud::ec2', no_auto => 1);
    $m->redefine(init => sub { return $_[0] });
    my $base = publiccloud::basetest->new();
    $base->provider_factory(provider => 'EC2');
    throws_ok { $base->provider_factory(provider => 'EC2') }
    qr/Provider already initialized/, 'second factory call dies';
};

# ---------------------------------------------------------------------------
# basetest::finalize / cleanup
# ---------------------------------------------------------------------------
subtest '[finalize] invokes cleanup' => sub {
    my $base = publiccloud::basetest->new();
    my $called = 0;
    my $mod = Test::MockModule->new('publiccloud::basetest', no_auto => 1);
    $mod->redefine(cleanup => sub { $called = 1; return 1 });
    $base->finalize();
    is($called, 1, 'finalize calls cleanup');
};

subtest '[cleanup] default returns true' => sub {
    my $base = publiccloud::basetest->new();
    is($base->cleanup(), 1, 'default cleanup returns 1');
};

# ---------------------------------------------------------------------------
# k8sbasetest service name mapping
# ---------------------------------------------------------------------------
subtest '[get_k8s_service_name] provider mapping' => sub {
    my $k = publiccloud::k8sbasetest->new();
    is($k->get_k8s_service_name('EC2'), 'EKS', 'EC2 -> EKS');
    is($k->get_k8s_service_name('GCE'), 'GKE', 'GCE -> GKE');
    is($k->get_k8s_service_name('AZURE'), 'AKS', 'AZURE -> AKS');
    throws_ok { $k->get_k8s_service_name('FOO') } qr/Unknown provider/, 'unknown provider dies';
};

subtest '[get_container_registry_service_name] provider mapping' => sub {
    my $k = publiccloud::k8sbasetest->new();
    _unset('PUBLIC_CLOUD_REGION');
    is($k->get_container_registry_service_name('EC2'), 'ECR', 'EC2 -> ECR');
    is(get_var('PUBLIC_CLOUD_REGION'), 'eu-central-1', 'EC2 sets default region when unset');

    is($k->get_container_registry_service_name('GCE'), 'GCR', 'GCE -> GCR');

    _unset('PUBLIC_CLOUD_REGION');
    is($k->get_container_registry_service_name('AZURE'), 'ACR', 'AZURE -> ACR');
    is(get_var('PUBLIC_CLOUD_REGION'), 'westeurope', 'AZURE sets default region when unset');

    _unset('PUBLIC_CLOUD_REGION');
};

# ---------------------------------------------------------------------------
# ssh_interactive::select_host_console
# ---------------------------------------------------------------------------
subtest '[select_host_console] non-tunneled selects serial terminal' => sub {
    my $mod = Test::MockModule->new('publiccloud::ssh_interactive', no_auto => 1);
    $mod->redefine(is_tunneled => sub { 0 });
    my %did;
    $mod->redefine(select_serial_terminal => sub { $did{serial} = 1 });
    $mod->redefine(type_string => sub { });
    $mod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $mod->redefine(script_output => sub { 'myhost' });
    $mod->redefine(assert_script_run => sub { $did{health} = 1; return 0 });
    $mod->redefine(select_console => sub { $did{console} = $_[0] });

    set_var('TUNNELED', 0);
    lives_ok { publiccloud::ssh_interactive::select_host_console() } 'runs without tunnel';
    is($did{serial}, 1, 'selects the serial terminal');
    is($did{health}, 1, 'runs the health check');

    _unset('TUNNELED');
};

subtest '[select_host_console] tunneled without force dies' => sub {
    my $mod = Test::MockModule->new('publiccloud::ssh_interactive', no_auto => 1);
    $mod->redefine(is_tunneled => sub { 1 });
    $mod->redefine(select_serial_terminal => sub { });
    $mod->redefine(type_string => sub { });
    $mod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $mod->redefine(select_console => sub { });

    set_var('_SSH_TUNNELS_INITIALIZED', 1);
    throws_ok { publiccloud::ssh_interactive::select_host_console() }
    qr/Called select_host_console but we are in TUNNELED mode/, 'dies in tunneled mode without force';

    _unset('_SSH_TUNNELS_INITIALIZED');
};

done_testing;
