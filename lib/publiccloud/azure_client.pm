# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for Azure connection and authentication
#
# Maintainer: qa-c team <qa-c@suse.de>

package publiccloud::azure_client;
use Mojo::Base -base;
use testapi;
use utils;
use publiccloud::vault;

has key_id => undef;
has key_secret => undef;
has subscription => undef;
has tenantid => undef;
has region => undef;
has vault => undef;

=head2 decode_azure_json

    my $json_obj = decode_azure_json($str);

Helper function to decode json string, retrieved from C<az>, into a json
object.
Due to https://github.com/Azure/azure-cli/issues/9903 we need to strip all
color codes from that string first.
=cut
sub decode_azure_json {
    return decode_json(colorstrip(shift));
}

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

1;
