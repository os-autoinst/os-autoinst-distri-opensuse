# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Helper class for Google Cloud Platform
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>
#             Jose Lausuch <jalausuch@suse.de>

package publiccloud::gce;
use Mojo::Base 'publiccloud::provider';
use testapi;
use strict;
use utils;

use constant CREDENTIALS_FILE => 'google_credentials.json';

has account             => undef;
has project_id          => undef;
has private_key_id      => undef;
has private_key         => undef;
has service_acount_name => undef;
has client_id           => undef;

sub init {
    my ($self) = @_;
    my $credentials = "{" . $/
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
    save_tmp_file(CREDENTIALS_FILE, $credentials);
    assert_script_run('curl -O ' . autoinst_url . "/files/" . CREDENTIALS_FILE);

    assert_script_run('source ~/.bashrc');
    assert_script_run('ntpdate -s time.google.com');
    assert_script_run('gcloud config set account ' . $self->account);
    assert_script_run('gcloud auth activate-service-account --key-file=' . CREDENTIALS_FILE . ' --project=' . $self->project_id);
}

sub file2name {
    my ($self, $file) = @_;
    my $name = $file;
    $name = lc $file;           # lower case
    $name =~ s/[^a-z0-9]//g;    # only allowed characteres from Google Cloud
    $name =~ s/targz$//;        # removes targz
    return $name;
}

sub find_img {
    my ($self, $name) = @_;
    my $img_name = $self->file2name($name);
    my $out = script_output("gcloud compute images list --filter='name~$img_name'|grep -v NAME", 10, proceed_on_failure => 1);
    return if (!$out || $out =~ m/0 items/);
    my ($image) = $out =~ /(\w+)/;
    return $image;
}

sub upload_img {
    my ($self, $file) = @_;
    my $img_name = $self->file2name($file);
    my $uri      = 'openqa-storage/' . $file;

    assert_script_run("gsutil cp $file gs://$uri",                                     timeout => 60 * 60);
    assert_script_run("gcloud compute images create $img_name --source-uri gs://$uri", timeout => 60 * 10);

    if (!$self->find_img($file)) {
        die("Cannot find image after upload!");
    }
    return $img_name;
}

sub ipa {
    my ($self, %args) = @_;

    $args{credentials_file} = CREDENTIALS_FILE;
    $args{instance_type} //= 'n1-standard-2';
    $args{user}          //= 'susetest';
    $args{provider}      //= 'gce';

    return $self->run_ipa(%args);
}

1;
