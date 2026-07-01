# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Unit tests for the publiccloud client/registry helper classes:
# aws_client, azure_client, gcp_client (config getters + container image name
# composition), the instances registry and the k8s_provider service routing
# plus the ACR/ECR/GCR delete_image command composition.
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Exception;
use Test::Warnings;
use testapi 'set_var';

use publiccloud::aws_client;
use publiccloud::azure_client;
use publiccloud::gcp_client;
use publiccloud::instances;
use publiccloud::k8s_provider;
use publiccloud::acr;
use publiccloud::ecr;
use publiccloud::gcr;

sub _unset { for my $k (@_) { set_var($k, undef) } }

# ---------------------------------------------------------------------------
# aws_client
# ---------------------------------------------------------------------------
subtest '[aws_client] config getters' => sub {
    set_var('PUBLIC_CLOUD_REGION', 'us-east-1');
    set_var('PUBLIC_CLOUD_USER', undef);
    set_var('PUBLIC_CLOUD_CONTAINER_IMAGES_REGISTRY', undef);

    my $c = publiccloud::aws_client->new();
    is($c->region, 'us-east-1', 'region from PUBLIC_CLOUD_REGION');
    is($c->username, 'ec2-user', 'username default');
    is($c->container_registry, 'suse-qec-testing', 'container registry default');

    _unset(qw/PUBLIC_CLOUD_REGION PUBLIC_CLOUD_USER PUBLIC_CLOUD_CONTAINER_IMAGES_REGISTRY/);
};

subtest '[aws_client] get_container_image_full_name' => sub {
    set_var('PUBLIC_CLOUD_REGION', 'eu-west-1');
    my $c = publiccloud::aws_client->new(aws_account_id => '123456789012', container_registry => 'myrepo');
    is($c->get_container_image_full_name('v1'),
        '123456789012.dkr.ecr.eu-west-1.amazonaws.com/myrepo:v1',
        'ECR full image name composed');
    _unset('PUBLIC_CLOUD_REGION');
};

# ---------------------------------------------------------------------------
# azure_client
# ---------------------------------------------------------------------------
subtest '[azure_client] config getters and image name' => sub {
    set_var('PUBLIC_CLOUD_REGION', 'westeurope');
    set_var('PUBLIC_CLOUD_USER', undef);
    set_var('PUBLIC_CLOUD_CONTAINER_IMAGES_REGISTRY', undef);

    my $c = publiccloud::azure_client->new();
    is($c->region, 'westeurope', 'region getter');
    is($c->username, 'azureuser', 'username default');
    is($c->container_registry, 'suseqectesting', 'registry default');
    is($c->get_container_image_full_name('tag1'),
        'suseqectesting.azurecr.io/tag1', 'ACR full image name composed');

    _unset(qw/PUBLIC_CLOUD_REGION PUBLIC_CLOUD_USER PUBLIC_CLOUD_CONTAINER_IMAGES_REGISTRY/);
};

# ---------------------------------------------------------------------------
# gcp_client
# ---------------------------------------------------------------------------
subtest '[gcp_client] config getters and registry prefix' => sub {
    set_var('PUBLIC_CLOUD_REGION', 'europe-west1');
    set_var('PUBLIC_CLOUD_AVAILABILITY_ZONE', 'europe-west1-b');
    set_var('PUBLIC_CLOUD_GCR_ZONE', undef);
    set_var('PUBLIC_CLOUD_USER', undef);

    my $c = publiccloud::gcp_client->new(project_id => 'my-proj');
    is($c->region, 'europe-west1', 'region getter');
    is($c->availability_zone, 'europe-west1-b', 'availability zone getter');
    is($c->username, 'susetest', 'username default');
    is($c->gcr_zone, 'eu.gcr.io', 'gcr zone default');
    is($c->get_container_registry_prefix(), 'eu.gcr.io/my-proj', 'registry prefix composed');
    is(publiccloud::gcp_client::get_credentials_file_name(), '/root/google_credentials.json', 'credentials file constant');

    _unset(qw/PUBLIC_CLOUD_REGION PUBLIC_CLOUD_AVAILABILITY_ZONE PUBLIC_CLOUD_GCR_ZONE PUBLIC_CLOUD_USER/);
};

subtest '[gcp_client] get_container_image_full_name includes job id' => sub {
    set_var('PUBLIC_CLOUD_REGION', 'europe-west1');
    set_var('PUBLIC_CLOUD_AVAILABILITY_ZONE', 'europe-west1-b');
    my $mod = Test::MockModule->new('publiccloud::gcp_client', no_auto => 1);
    $mod->redefine(get_current_job_id => sub { 777 });

    my $c = publiccloud::gcp_client->new(project_id => 'p', gcr_zone => 'eu.gcr.io');
    is($c->get_container_image_full_name('img'), 'eu.gcr.io/p/img777:latest', 'image name has job id and :latest');

    _unset(qw/PUBLIC_CLOUD_REGION PUBLIC_CLOUD_AVAILABILITY_ZONE/);
};

# ---------------------------------------------------------------------------
# instances registry
# ---------------------------------------------------------------------------
subtest '[instances] set/get registry' => sub {
    throws_ok { publiccloud::instances::get_instance() } qr/no instances defined/, 'dies when empty';

    my $first = Test::MockObject->new;
    my $second = Test::MockObject->new;
    publiccloud::instances::set_instances($first, $second);
    is(publiccloud::instances::get_instance(), $first, 'returns first instance');

    publiccloud::instances::set_instances();    # reset for hygiene
};

# ---------------------------------------------------------------------------
# k8s_provider service routing
# ---------------------------------------------------------------------------
subtest '[k8s_provider] init routes to correct client class' => sub {
    my $k8s = Test::MockModule->new('publiccloud::k8s_provider', no_auto => 1);
    $k8s->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    # Stub each client's init so we don't perform real auth.
    for my $cls (qw/publiccloud::aws_client publiccloud::gcp_client publiccloud::azure_client/) {
        my $m = Test::MockModule->new($cls, no_auto => 1);
        $m->redefine(init => sub { return $_[0] });
        # keep the mock alive for the duration of the subtest
        no strict 'refs';
        push @{"_keepalive_$cls"}, $m;
    }

    my $p1 = publiccloud::k8s_provider->new();
    $p1->init('EKS');
    isa_ok($p1->provider_client, 'publiccloud::aws_client', 'EKS uses aws_client');

    my $p2 = publiccloud::k8s_provider->new();
    $p2->init('GKE');
    isa_ok($p2->provider_client, 'publiccloud::gcp_client', 'GKE uses gcp_client');

    my $p3 = publiccloud::k8s_provider->new();
    $p3->init('AKS');
    isa_ok($p3->provider_client, 'publiccloud::azure_client', 'AKS uses azure_client');

    throws_ok { publiccloud::k8s_provider->new()->init() } qr/service must be specified/, 'dies without service';
};

# ---------------------------------------------------------------------------
# ACR / ECR / GCR delete_image command composition
# ---------------------------------------------------------------------------
subtest '[ecr] delete_image composes aws batch-delete-image' => sub {
    my $ecr = publiccloud::ecr->new();
    my $client = Test::MockObject->new;
    $client->mock(container_registry => sub { 'myrepo' });
    $ecr->provider_client($client);

    my $mod = Test::MockModule->new('publiccloud::ecr', no_auto => 1);
    my $seen;
    $mod->redefine(assert_script_run => sub { $seen = $_[0]; return 0 });
    $ecr->delete_image('tag42');
    like($seen, qr/aws ecr batch-delete-image --repository-name myrepo --image-ids imageTag=tag42/, 'ECR delete command');
};

subtest '[acr] delete_image composes az acr repository delete' => sub {
    my $acr = publiccloud::acr->new();
    my $client = Test::MockObject->new;
    $client->mock(container_registry => sub { 'myacr' });
    $acr->provider_client($client);

    my $mod = Test::MockModule->new('publiccloud::acr', no_auto => 1);
    $mod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my $seen;
    $mod->redefine(assert_script_run => sub { $seen = $_[0]; return 0 });
    $acr->delete_image('tagA');
    like($seen, qr/az acr repository delete --yes --name myacr --image tagA/, 'ACR delete command');
};

subtest '[gcr] delete_image composes gcloud container images delete' => sub {
    my $gcr = publiccloud::gcr->new();
    my $mod = Test::MockModule->new('publiccloud::gcr', no_auto => 1);
    $mod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $mod->redefine(get_container_image_full_name => sub { 'eu.gcr.io/p/imgX:latest' });
    my $seen;
    $mod->redefine(assert_script_run => sub { $seen = $_[0]; return 0 });
    $gcr->delete_image('imgX');
    like($seen, qr{gcloud container images delete eu\.gcr\.io/p/imgX:latest --quiet}, 'GCR delete command');
};

done_testing;
