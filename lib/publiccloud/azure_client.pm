# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for Azure connection and authentication
#
# Maintainer: QE-C team <qa-c@suse.de>

package publiccloud::azure_client;
use Mojo::Base -base;
use testapi;
use utils;
use version_utils qw(is_sle);
use publiccloud::utils;


# Reference to a list of all regions specified via job variable/settings
# At least one region is present from PUBLIC_CLOUD_REGION
has _regions => sub {
    my @list = (get_required_var('PUBLIC_CLOUD_REGION'));
    if (my $alt = get_var('PUBLIC_CLOUD_ALTERNATE_REGIONS')) {
        push @list, split(/\s*,\s*/, $alt);
    }
    return \@list;
};

# List of regions blacklisted by the user during the test execution.
has _blacklisted_regions => sub { {} };

# Setter for the blacklist. The test code can call this function
# to add a region name to the blacklis; it usually happens
# when a terraform deployment fails for a specific error.
sub blacklist_region {
    my ($self, $region) = @_;
    $self->_blacklisted_regions->{$region} = 1;
    return $self;    # allows chaining
}

# Getter, return the first not blacklisted region or die
sub region {
    my ($self) = @_;
    my $blacklist = $self->_blacklisted_regions;
    for my $r (@{$self->_regions}) {
        return $r unless $blacklist->{$r};
    }
    die "No available regions — all blacklisted: " . join(', ', @{$self->_regions});
}

has username => sub { get_var('PUBLIC_CLOUD_USER', 'azureuser') };
has subscription => sub { get_var('PUBLIC_CLOUD_AZURE_SUBSCRIPTION_ID') };
has credentials_file_content => undef;
has container_registry => sub { get_var('PUBLIC_CLOUD_CONTAINER_IMAGES_REGISTRY', 'suseqectesting') };

sub init {
    my ($self, %args) = @_;
    $args{namespace} //= get_required_var('PUBLIC_CLOUD_NAMESPACE');
    my $data = get_credentials(url_suffix => 'azure.json', namespace => $args{namespace});
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
    # Work-around for https://bugzilla.suse.com/show_bug.cgi?id=1270099
    assert_script_run q(sed '/ca-certificates/s,\\\\$,--opt "\\\\--volume /etc/ssl:/etc/ssl:ro" \\\\,' /usr/bin/register_az | bash) if is_sle(">16.0");
    script_run("PILOT_DEBUG=1 az %silent --help") if is_sle(">=16");

    $self->az_login();
    assert_script_run("az account set --subscription \$ARM_SUBSCRIPTION_ID");
}

sub az_login {
    my ($self) = @_;
    my $login_cmd = "while ! az login --service-principal -u \$ARM_CLIENT_ID -p \$ARM_CLIENT_SECRET -t \$ARM_TENANT_ID -o none 1>/dev/null 2>&1; do sleep 10; done";

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

1;
