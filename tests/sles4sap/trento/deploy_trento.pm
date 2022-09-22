# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deploy a Trento server
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use testapi;
use base 'trento';

sub run {
    my ($self) = @_;
    if (get_var('TRENTO_EXT_DEPLOY_IP')) {
        return;
    }
    die "Only AZURE deployment supported for the moment" unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    $self->select_serial_terminal;

    my $resource_group = $self->get_resource_group;
    my $acr_name = $self->get_acr_name;

    my $basedir = '/root/test';
    enter_cmd "cd $basedir";

    $self->deploy_vm();

    my $script_run = 'set -o pipefail ; ./';
    my $script_id = 'trento_acr_azure';
    record_info($script_id);
    my $trento_registry_chart = get_var(TRENTO_REGISTRY_CHART => 'registry.suse.com/trento/trento-server');
    my $cfg_json = 'config_images_gen.json';
    my @imgs = qw(WEB RUNNER);
    # take care of TRENTO_VERSION variable too
    if (get_var("TRENTO_REGISTRY_IMAGE_$imgs[0]") || get_var("TRENTO_REGISTRY_IMAGE_$imgs[1]")) {
        my $cfg_helper_cmd = './trento_deploy/config_helper.py' .
          " -o $cfg_json" .
          " --chart $trento_registry_chart";
        if (get_var('TRENTO_REGISTRY_CHART_VERSION')) {
            $cfg_helper_cmd .= ' --chart-version ' . get_var('TRENTO_REGISTRY_CHART_VERSION');
        }
        foreach my $img (@imgs) {
            if (get_var("TRENTO_REGISTRY_IMAGE_$img")) {
                $cfg_helper_cmd .= ' --' . lc($img) . ' ' . get_var("TRENTO_REGISTRY_IMAGE_$img") .
                  ' --' . lc($img) . '-version ';
                if (get_var("TRENTO_REGISTRY_IMAGE_${img}_VERSION")) {
                    $cfg_helper_cmd .= get_var("TRENTO_REGISTRY_IMAGE_${img}_VERSION");
                }
                else {
                    $cfg_helper_cmd .= 'latest';
                }
            }
        }
        assert_script_run($cfg_helper_cmd);
        upload_logs($cfg_json);
        $trento_registry_chart = $cfg_json;
    }
    my $deploy_script_log = "script_$script_id.log.txt";
    my $trento_cluster_install = "${basedir}/trento_cluster_install.sh";
    my $trento_acr_azure_timeout = 360;
    my $cmd = $script_run . $script_id . '.sh' .
      " -g $resource_group" .
      " -n $acr_name" .
      " -r $trento_registry_chart";
    if (get_var("TRENTO_REGISTRY_IMAGE_$imgs[0]") || get_var("TRENTO_REGISTRY_IMAGE_$imgs[1]")) {
        $trento_acr_azure_timeout += 240;
        $cmd .= " -o $basedir";
    }
    $cmd .= " -v 2>&1|tee $deploy_script_log";
    assert_script_run($cmd, $trento_acr_azure_timeout);
    upload_logs($deploy_script_log);
    if (get_var("TRENTO_REGISTRY_IMAGE_$imgs[0]") || get_var("TRENTO_REGISTRY_IMAGE_$imgs[1]")) {
        upload_logs($trento_cluster_install);
    }

    my $machine_ip = $self->get_trento_ip;
    my $acr_server = script_output("az acr list -g $resource_group --query \"[0].loginServer\" -o tsv");
    my $acr_username = script_output("az acr credential show -n $acr_name --query username -o tsv");
    my $acr_secret = script_output("az acr credential show -n $acr_name --query 'passwords[0].value' -o tsv");

    # Check what registry has been created by trento_acr_azure
    assert_script_run("az acr repository list -n $acr_name");

    $script_id = '01.010';
    record_info($script_id);
    $deploy_script_log = "script_$script_id.log.txt";
    $cmd = $script_run . $script_id . '-trento_server_installation_premium_v.sh ' .
      " -i $machine_ip " .
      ' -k ' . $self->SSH_KEY .
      ' -u ' . $self->VM_USER;
    if (get_var('TRENTO_REGISTRY_CHART_VERSION')) {
        $cmd .= ' -c ' . get_var('TRENTO_REGISTRY_CHART_VERSION');
    }
    if (get_var("TRENTO_REGISTRY_IMAGE_$imgs[0]") || get_var("TRENTO_REGISTRY_IMAGE_$imgs[1]")) {
        $cmd .= " -x $trento_cluster_install";
    }
    if (get_var('TRENTO_WEB_PASSWORD')) {
        $cmd .= " -t" . get_var('TRENTO_WEB_PASSWORD');
    }
    $cmd .= ' -p $(pwd) ' .
      " -r $acr_server/trento/trento-server " .
      "-s $acr_username " .
      '-w $(az acr credential show -n ' . $acr_name . " --query 'passwords[0].value' -o tsv) " .
      "-v 2>&1|tee $deploy_script_log";
    assert_script_run($cmd, 600);
    upload_logs($deploy_script_log);
    trento::k8s_logs(qw(web runner));
}

sub post_fail_hook {
    my ($self) = @_;

    my $find_cmd = 'find . -type f -iname "*.log.txt"';
    upload_logs("$_") for split(/\n/, script_output($find_cmd));

    trento::k8s_logs(qw(web runner));
    $self->az_delete_group;

    $self->SUPER::post_fail_hook;
}

1;
