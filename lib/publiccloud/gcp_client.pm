# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for google connection and authentication
#
# Maintainer: qa-c team <qa-c@suse.de>

package publiccloud::gcp_client;
use Mojo::Base -base;
use testapi;
use utils;
use version_utils 'is_sle';
use publiccloud::vault;
use publiccloud::utils;
use Mojo::Util qw(b64_decode);
use Mojo::JSON 'decode_json';
use mmapi 'get_current_job_id';

use constant CREDENTIALS_FILE => '/root/google_credentials.json';

has storage_name => sub { get_var('PUBLIC_CLOUD_GOOGLE_STORAGE', 'openqa-storage') };
has project_id => sub { get_var('PUBLIC_CLOUD_GOOGLE_PROJECT_ID') };
has account => sub { get_var('PUBLIC_CLOUD_GOOGLE_ACCOUNT') };
has service_acount_name => sub { get_var('PUBLIC_CLOUD_GOOGLE_SERVICE_ACCOUNT') };
has private_key_id => undef;
has private_key => undef;
has client_id => sub { get_var('PUBLIC_CLOUD_GOOGLE_CLIENT_ID') };
has gcr_zone => sub { get_var('PUBLIC_CLOUD_GCR_ZONE', 'eu.gcr.io') };
has region => sub { get_var('PUBLIC_CLOUD_REGION', 'europe-west1-b') };
has username => sub { get_var('PUBLIC_CLOUD_USER', 'susetest') };
has vault_gcp_role_index => undef;
has vault => undef;

sub init {
    my ($self) = @_;
    # For now we support Vault and the credentials-microservice. Vault will be removed after a certain transition period
    if (get_var('PUBLIC_CLOUD_CREDENTIALS_URL')) {
        my $data = get_credentials(CREDENTIALS_FILE);
        $self->project_id($data->{project_id});
        $self->account($data->{client_id});
    } else {
        $self->vault(publiccloud::vault->new());
        $self->create_credentials_file();
    }
    assert_script_run('source ~/.bashrc');
    (is_sle('=15-SP4')) ? assert_script_run("chronyd -q 'pool time.google.com iburst'") : assert_script_run('ntpdate -s time.google.com');
    assert_script_run('gcloud config set account ' . $self->account);
    assert_script_run(
        'gcloud auth activate-service-account --key-file=' . CREDENTIALS_FILE . ' --project=' . $self->project_id);
}

sub vault_gcp_roles {
    return split(",", get_var('PUBLIC_CLOUD_VAULT_ROLES', 'openqa-role,openqa-role1,openqa-role2,openqa-role3'));
}

=head2

A service account in GCP can only have up to 10 keys assigned. With this we
reach our paralel openqa jobs quite fast.
To have more keys available, we create 4 service accounts and select randomly
one. If this fails, the next call of C<get_next_vault_role()> will retrieve
the next.
=cut

sub get_next_vault_role {
    my ($self) = shift;
    my @known_roles = $self->vault_gcp_roles();
    if (defined($self->vault_gcp_role_index)) {
        $self->vault_gcp_role_index(($self->vault_gcp_role_index + 1) % scalar(@known_roles));
    } else {
        $self->vault_gcp_role_index(int(rand(scalar(@known_roles))));
    }
    return $known_roles[$self->vault_gcp_role_index];
}

sub create_credentials_file {
    my ($self) = @_;
    my $credentials_file;

    if ($self->private_key_id()) {
        $credentials_file = "{" . $/
          . '"type": "service_account", ' . $/
          . '"project_id": "' . $self->project_id . '", ' . $/
          . '"private_key_id": "' . $self->private_key_id . '", ' . $/
          . '"private_key": "' . $self->private_key . '", ' . $/
          . '"client_email": "' . $self->service_acount_name . '@' . $self->project_id . '.iam.gserviceaccount.com", ' . $/
          . '"client_id": "' . $self->client_id . '", ' . $/
          . '"auth_uri": "https://accounts.google.com/o/oauth2/auth", ' . $/
          . '"token_uri": "https://oauth2.googleapis.com/token", ' . $/
          . '"auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs", ' . $/
          . '"client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/' . $self->service_acount_name . '%40' . $self->project_id . '.iam.gserviceaccount.com"' . $/
          . '}';
    } else {
        record_info('INFO', 'Get credentials from VAULT server.');

        my $data = $self->vault->retry(
            sub { $self->vault->get_secrets('/gcp/key/' . $self->get_next_vault_role(), max_tries => 1) },
            name => 'get_secrets(gcp)',
            max_tries => scalar($self->vault_gcp_roles()) * 2,
            sleep_duration => get_var('PUBLIC_CLOUD_VAULT_TIMEOUT', 5));
        $credentials_file = b64_decode($data->{private_key_data});
        my $cf_json = decode_json($credentials_file);
        $self->account($cf_json->{client_email});
        $self->project_id($cf_json->{'project_id'});
    }

    save_tmp_file(CREDENTIALS_FILE, $credentials_file);
    assert_script_run('curl ' . autoinst_url . '/files/' . CREDENTIALS_FILE . ' -o ' . CREDENTIALS_FILE);
}

sub get_credentials_file_name {
    return CREDENTIALS_FILE;
}


=head2 get_container_registry_prefix

Get the full registry prefix URL for any containers image registry of ECR based on the account and region
=cut

sub get_container_registry_prefix {
    my ($self) = @_;
    return $self->gcr_zone . '/' . $self->project_id;
}

=head2 get_container_image_full_name

Get the full name for a container image in ECR registry
=cut

sub get_container_image_full_name {
    my ($self, $tag) = @_;
    my $full_name_prefix = $self->get_container_registry_prefix();
    return "$full_name_prefix/$tag" . get_current_job_id() . ":latest";
}

=head2 configure_podman

Configure the podman to access the cloud provider registry
=cut

sub configure_podman {
    my ($self) = @_;
    assert_script_run('gcloud auth configure-docker --quiet ' . $self->gcr_zone);
}

sub cleanup {
    my ($self) = @_;
    $self->vault->revoke() unless (get_var('PUBLIC_CLOUD_CREDENTIALS_URL'));
}

1;
