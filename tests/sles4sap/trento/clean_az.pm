use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use strict;
use testapi;

use constant TRENTO_AZ_PREFIX  => 'openqa-trento';
use constant TRENTO_AZ_ACR_PREFIX  => 'openqatrentoacr';

sub run {
    my ($self, $args) = @_;
    $self->select_serial_terminal;

    ######################
    # az login
    set_var 'PUBLIC_CLOUD_PROVIDER' => 'AZURE';
    my $provider = $self->provider_factory();
    assert_script_run('az group list --query "[].name" -o tsv');
    assert_script_run('for g in $(for l in $(az acr list --query "[].loginServer" -o tsv | grep '.TRENTO_AZ_ACR_PREFIX.'); do az acr show --name ${l} --query resourceGroup -o tsv; done); do az group delete --name ${g} -y; done', 3600);
    assert_script_run('az group list --query "[].name" -o tsv | grep '.TRENTO_AZ_PREFIX);
}

1;
