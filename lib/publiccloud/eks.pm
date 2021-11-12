# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for Amazon Elastic Container Registry (ECR)
#
# Maintainer: Ivan Lausuch <ilausuch@suse.de>, qa-c team <qa-c@suse.de>
# Documentation: https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html

package publiccloud::eks;
use Mojo::Base 'publiccloud::aws';
use testapi;
use utils;

has security_token => undef;

sub vault_create_credentials {
    my ($self) = @_;

    record_info('INFO', 'Get credentials from VAULT server for EKS');
    my $path = '/aws/sts/openqa-role-eks';
    my $res = $self->vault->api('/v1/' . get_required_var('PUBLIC_CLOUD_VAULT_NAMESPACE') . $path, method => 'post');
    my $data = $res->{data};

    $self->key_id($data->{access_key});
    $self->key_secret($data->{secret_key});
    $self->security_token($data->{security_token});
    die('Failed to retrieve key')
      unless (defined($self->key_id) && defined($self->key_secret) && defined($self->security_token));

    assert_script_run('export AWS_SESSION_TOKEN="' . $self->security_token . '"');
    assert_script_run("export AWS_ACCESS_KEY_ID=" . $self->key_id);
    assert_script_run("export AWS_SECRET_ACCESS_KEY=" . $self->key_secret);
    assert_script_run('export AWS_DEFAULT_REGION="' . $self->region . '"');
}

sub _check_credentials {
    my ($self) = @_;
    return 1;
}

sub init {
    my ($self, %args) = @_;
    $self->SUPER::init();

    my $cluster = get_required_var("PUBLIC_CLOUD_K8S_CLUSTER");
    assert_script_run("aws eks update-kubeconfig --name $cluster", 120);
}

1;
