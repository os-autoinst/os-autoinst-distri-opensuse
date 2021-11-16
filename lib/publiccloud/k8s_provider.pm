# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for amazon connection and authentication
#
# Maintainer: qa-c team <qa-c@suse.de>

package publiccloud::k8s_provider;
use Mojo::Base -base;
use testapi;
use mmapi 'get_current_job_id';


has region => undef;
has resource_name => sub { get_var('PUBLIC_CLOUD_RESOURCE_NAME', 'openqa-vm') };
has container_registry => sub { get_var("PUBLIC_CLOUD_CONTAINER_IMAGES_REGISTRY", 'suse-qec-testing') };
has provider_client => undef;

sub init {
    my ($self, $service) = @_;
    die('The service must be specified') if (!$service);

    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');

    if ($provider eq 'EC2') {
        $self->provider_client(
            publiccloud::aws_client->new(
                region => $self->region,
                service => $service
            ));
        $self->provider_client->init();
    }
    elsif ($provider eq 'GCE') {
        # TODO
    }
    elsif ($provider eq 'AZURE') {
        # TODO
    }
}

=head2 get_container_registry_prefix
Get the full registry prefix URL (based on the account and region) to push container images on ECR.
=cut
sub get_container_registry_prefix {
    my ($self) = @_;
    my $region = $self->region;
    my $full_name_prefix = sprintf('%s.dkr.ecr.%s.amazonaws.com', $self->provider_client->aws_account_id, $region);
    return $full_name_prefix;
}

=head2 get_container_image_full_name
Get the full name for a container image in ECR registry
=cut
sub get_container_image_full_name {
    my ($self, $tag) = @_;
    my $full_name_prefix = $self->get_container_registry_prefix();
    return "$full_name_prefix/" . $self->container_registry . ":$tag";
}

=head2 get_default_tag
Returns a default tag for container images based of the current job id
=cut
sub get_default_tag {
    my ($self) = @_;
    return join('-', $self->resource_name, get_current_job_id());
}

1;
