# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Helper class for Google Cloud Platform
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>
#             Jose Lausuch <jalausuch@suse.de>
#             qa-c team <qa-c@suse.de>

package publiccloud::gcp;
use Mojo::Base 'publiccloud::provider';
use Mojo::Util qw(b64_decode);
use Mojo::JSON 'decode_json';
use testapi;
use utils;

use constant CREDENTIALS_FILE => '/root/google_credentials.json';

has account => undef;
has project_id => undef;
has private_key_id => undef;
has private_key => undef;
has service_acount_name => undef;
has client_id => undef;

sub init {
    my ($self) = @_;
    $self->SUPER::init();

    $self->create_credentials_file();
    assert_script_run('source ~/.bashrc');
    assert_script_run('ntpdate -s time.google.com');
    assert_script_run('gcloud config set account ' . $self->account);
    assert_script_run('gcloud auth activate-service-account --key-file=' . CREDENTIALS_FILE . ' --project=' . $self->project_id);
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
        my $data = $self->vault_get_secrets('/gcp/key/openqa-role');
        $credentials_file = b64_decode($data->{private_key_data});
        my $cf_json = decode_json($credentials_file);
        $self->account($cf_json->{client_email});
        $self->project_id($cf_json->{'project_id'});
    }

    save_tmp_file(CREDENTIALS_FILE, $credentials_file);
    assert_script_run('curl -O ' . autoinst_url . "/files/" . CREDENTIALS_FILE);
}

sub get_credentials_file_name {
    return CREDENTIALS_FILE;
}

1;
