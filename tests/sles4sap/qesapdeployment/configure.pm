# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Configuration steps for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use mmapi 'get_current_job_id';
use qesapdeployment;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Init al the PC gears (ssh keys)
    my $provider = $self->provider_factory();

    my $resource_group_postfix = 'qesapval' . get_current_job_id();
    my $qesap_provider = lc get_required_var('PUBLIC_CLOUD_PROVIDER');

    my %variables;
    $variables{PROVIDER} = $qesap_provider;
    $variables{REGION} = $provider->provider_client->region;
    $variables{DEPLOYMENTNAME} = $resource_group_postfix;
    $variables{QESAP_CLUSTER_OS_VER} = get_required_var("QESAP_CLUSTER_OS_VER");
    $variables{SSH_KEY_PRIV} = '/root/.ssh/id_rsa';
    $variables{SSH_KEY_PUB} = '/root/.ssh/id_rsa.pub';
    $variables{SCC_REGCODE_SLES4SAP} = get_required_var('SCC_REGCODE_SLES4SAP');
    $variables{HANA_ACCOUNT} = get_required_var("QESAPDEPLOY_HANA_ACCOUNT");
    $variables{HANA_CONTAINER} = get_required_var("QESAPDEPLOY_HANA_CONTAINER");
    if(get_var("QESAPDEPLOY_HANA_TOKEN")) {
        $variables{HANA_TOKEN} = get_var("QESAPDEPLOY_HANA_TOKEN");
        # something not escaped in file_content_replace()
        $variables{HANA_TOKEN} =~ s/\&/\\\&/g;
    }
    $variables{HANA_SAR} = get_required_var("QESAPDEPLOY_SAPCAR");
    $variables{HANA_CLIENT_SAR} = get_required_var("QESAPDEPLOY_IMDB_SERVER");
    $variables{HANA_SAPCAR} = get_required_var("QESAPDEPLOY_IMDB_CLIENT");
    qesap_prepare_env(openqa_variables => \%variables, provider => $qesap_provider);
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();
    $self->SUPER::post_fail_hook;
}

1;
