# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for Azure connection and authentication
#
# Maintainer: qa-c team <qa-c@suse.de>

package publiccloud::azure_client;
use Mojo::Base -base;
use testapi;
use utils;
use publiccloud::utils;

has subscription => sub { get_var('PUBLIC_CLOUD_AZURE_SUBSCRIPTION_ID') };
has region => sub { get_var('PUBLIC_CLOUD_REGION', 'westeurope') };
has username => sub { get_var('PUBLIC_CLOUD_USER', 'azureuser') };
has credentials_file_content => undef;
has container_registry => sub { get_var('PUBLIC_CLOUD_CONTAINER_IMAGES_REGISTRY', 'suseqectesting') };

sub init {
    my ($self) = @_;
    my $data = get_credentials('azure.json');
    $self->subscription($data->{subscription_id});
    define_secret_variable("ARM_SUBSCRIPTION_ID", $self->subscription);
    define_secret_variable("ARM_CLIENT_ID", $data->{client_id});
    define_secret_variable("ARM_CLIENT_SECRET", $data->{client_secret});
    define_secret_variable("ARM_TENANT_ID", $data->{tenant_id});
    define_secret_variable("ARM_TEST_LOCATION", $self->region);
    $self->credentials_file_content("{" . $/
          . '"clientId": "' . $data->{client_id} . '", ' . $/
          . '"clientSecret": "' . $data->{client_secret} . '", ' . $/
          . '"subscriptionId": "' . $self->subscription . '", ' . $/
          . '"tenantId": "' . $data->{tenant_id} . '", ' . $/
          . '"activeDirectoryEndpointUrl": "https://login.microsoftonline.com", ' . $/
          . '"resourceManagerEndpointUrl": "https://management.azure.com/", ' . $/
          . '"activeDirectoryGraphResourceId": "https://graph.windows.net/", ' . $/
          . '"sqlManagementEndpointUrl": "https://management.core.windows.net:8443/", ' . $/
          . '"galleryEndpointUrl": "https://gallery.azure.com/", ' . $/
          . '"managementEndpointUrl": "https://management.core.windows.net/" ' . $/
          . '}');
    $self->az_login();
    assert_script_run("az account set --subscription \$ARM_SUBSCRIPTION_ID");
}

sub az_login {
    my ($self) = @_;
    my $login_cmd = "while ! az login --service-principal -u \$ARM_CLIENT_ID -p \$ARM_CLIENT_SECRET -t \$ARM_TENANT_ID; do sleep 10; done";

    assert_script_run($login_cmd, timeout => 5 * 60);
}

=head2 configure_podman

Configure the podman to access the cloud provider registry
=cut

sub configure_podman {
    my ($self) = @_;

    my $login_cmd = sprintf(q(while ! az acr login --name '%s'; do sleep 10; done),
        $self->container_registry);
    assert_script_run($login_cmd);
}

=head2 get_container_image_full_name

Returns the full name of the container image in ACR registry
C<tag> Tag of the container
=cut

sub get_container_image_full_name {
    my ($self, $tag) = @_;
    my $full_name_prefix = sprintf('%s.azurecr.io', $self->container_registry);
    return "$full_name_prefix/$tag";
}


sub destroy {
    my ($self) = @_;
}

sub cleanup {
    my ($self) = @_;
}

1;
