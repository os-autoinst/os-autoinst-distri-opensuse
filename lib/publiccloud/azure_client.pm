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
use publiccloud::utils;

has key_id => undef;
has key_secret => undef;
has subscription => sub { get_var('PUBLIC_CLOUD_AZURE_SUBSCRIPTION_ID') };
has tenantid => undef;
has region => sub { get_var('PUBLIC_CLOUD_REGION', 'westeurope') };
has username => sub { get_var('PUBLIC_CLOUD_USER', 'azureuser') };
has service => undef;
has vault => undef;
has container_registry => sub { get_required_var('PUBLIC_CLOUD_CONTAINER_IMAGES_REGISTRY') };

sub init {
    my ($self) = @_;
    if (get_var('PUBLIC_CLOUD_CREDENTIALS_URL')) {
        my $data = get_credentials();
        $self->subscription($data->{subscription_id});
        $self->key_id($data->{client_id});
        $self->key_secret($data->{client_secret});
        $self->tenantid($data->{tenant_id});
    } else {
        $self->vault(publiccloud::vault->new());
        $self->vault_create_credentials() unless ($self->key_id);
    }
    define_secret_variable("ARM_SUBSCRIPTION_ID", $self->subscription);
    define_secret_variable("ARM_CLIENT_ID", $self->key_id);
    define_secret_variable("ARM_CLIENT_SECRET", $self->key_secret);
    define_secret_variable("ARM_TENANT_ID", $self->tenantid);
    define_secret_variable("ARM_TEST_LOCATION", $self->region);
    $self->az_login();
    assert_script_run("az account set --subscription \$ARM_SUBSCRIPTION_ID");
}

sub az_login {
    my ($self) = @_;
    my $login_cmd = sprintf(q(while ! az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET -t $ARM_TENANT_ID; do sleep 10; done),
        $self->key_id, $self->key_secret, $self->tenantid);

    assert_script_run($login_cmd, timeout => 5 * 60);
    #Azure infra need some time to propagate given by Vault credentials
    # Running some verification command does not prove anything because
    # at the beginning failures can happening sporadically
    # not needed with static credentials, this section shall be removed after the account migration
    my $wait_seconds = get_var('AZURE_LOGIN_WAIT_SECONDS');
    if ($wait_seconds && !get_var('PUBLIC_CLOUD_CREDENTIALS_URL')) {
        record_info("WAIT", "Waiting for Azure credential spreading");
        sleep($wait_seconds);
    }
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

=head2 get_container_image_full_name

Returns the full name of the container image in ACR registry
C<tag> Tag of the container
=cut

sub get_container_image_full_name {
    my ($self, $tag) = @_;
    my $full_name_prefix = sprintf('%s.azurecr.io', $self->container_registry);
    return "$full_name_prefix/$tag";
}


sub cleanup {
    my ($self) = @_;
    $self->vault->revoke();
    $self->vault->revoke() unless (get_var('PUBLIC_CLOUD_CREDENTIALS_URL'));
}

1;
