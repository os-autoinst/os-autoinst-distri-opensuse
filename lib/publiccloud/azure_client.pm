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
use publiccloud::vault;

has key_id => sub { get_var('PUBLIC_CLOUD_KEY_ID') };
has key_secret => sub { get_var('PUBLIC_CLOUD_KEY_SECRET') };
has subscription => sub { get_var('PUBLIC_CLOUD_AZURE_SUBSCRIPTION_ID') };
has tenantid => sub { get_var('PUBLIC_CLOUD_AZURE_TENANT_ID') };
has region => sub { get_var('PUBLIC_CLOUD_REGION', 'westeurope') };
has subscription => sub { get_var('PUBLIC_CLOUD_AZURE_SUBSCRIPTION_ID') };
has username => sub { get_var('PUBLIC_CLOUD_USER', 'azureuser') };

has vault => undef;
has container_registry => sub { get_var('PUBLIC_CLOUD_CONTAINER_IMAGES_REGISTRY', 'suseqectesting') };

sub init {
    my ($self) = @_;
    $self->vault(publiccloud::vault->new());
    $self->vault_create_credentials() unless ($self->key_id);
    $self->az_login();
    assert_script_run("az account set --subscription " . $self->subscription);
    assert_script_run("export ARM_SUBSCRIPTION_ID=" . $self->subscription);
    assert_script_run("export ARM_CLIENT_ID=" . $self->key_id);
    assert_script_run("export ARM_CLIENT_SECRET=" . $self->key_secret);
    assert_script_run('export ARM_TENANT_ID="' . $self->tenantid . '"');
    assert_script_run('export ARM_ENVIRONMENT="public"');
    assert_script_run('export ARM_TEST_LOCATION="' . $self->region . '"');
}

sub az_login {
    my ($self) = @_;
    my $login_cmd = sprintf(q(while ! az login --service-principal -u '%s' -p '%s' -t '%s'; do sleep 10; done),
        $self->key_id, $self->key_secret, $self->tenantid);

    assert_script_run($login_cmd, timeout => 5 * 60);
    #Azure infra need some time to propagate given by Vault credentials
    # Running some verification command does not prove anything because
    # at the beginning failures can happening sporadically
    sleep(get_var('AZURE_LOGIN_WAIT_SECONDS', 0));
}

sub vault_create_credentials {
    my ($self) = @_;

    record_info('INFO', 'Get credentials from VAULT server.');
    my $data = $self->vault->get_secrets('/azure/creds/openqa-role');
    $self->key_id($data->{client_id});
    $self->key_secret($data->{client_secret});

    my $res = $self->vault->api('/v1/' . get_var('PUBLIC_CLOUD_VAULT_NAMESPACE', '') . '/secret/azure/openqa-role', method => 'get');
    $self->tenantid($res->{data}->{tenant_id});
    $self->subscription($res->{data}->{subscription_id});

    for my $i (('key_id', 'key_secret', 'tenantid', 'subscription')) {
        die("Failed to retrieve key - missing $i") unless (defined($self->$i));
    }
}

=head2 configure_podman

Configure the podman to access the cloud provider registry
=cut

sub configure_podman {
    my ($self) = @_;

    my $login_cmd = sprintf(q(while ! az acr login --name '%s' -u '%s' -p '%s'; do sleep 10; done),
        $self->container_registry, $self->key_id, $self->key_secret);
    assert_script_run($login_cmd);
    $login_cmd = sprintf(q(podman login %s.azurecr.io), $self->container_registry);
    assert_script_run($login_cmd);
}

=head2 get_container_registry_prefix

Get the full registry prefix URL (based on the account and region) to push container images on ACR.
=cut

sub get_container_registry_prefix {
    my ($self) = @_;
    return sprintf('%s.azurecr.io', $self->container_registry);
}

=head2 get_container_image_full_name

Returns the full name of the container image in ACR registry
C<tag> Tag of the container
=cut

sub get_container_image_full_name {
    my ($self, $tag) = @_;
    my $full_name_prefix = $self->get_container_registry_prefix();
    return "$full_name_prefix/$tag";
}


sub cleanup {
    my ($self) = @_;
    $self->vault->revoke();
}

1;
