# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deployment steps for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'sles4sap_publiccloud_basetest';
use testapi;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    $self->import_context($run_args);

    foreach my $instance (@{$self->{instances}}) {
        next if ($instance->{'instance_id'} !~ m/vmhana/);
        record_info("$instance");

        my $repo_host = get_var('REPO_MIRROR_HOST', 'download.suse.de');
        my $ibsm_ip = get_required_var('IBSM_IP');
        $instance->ssh_assert_script_run(cmd => "echo \"$ibsm_ip $repo_host\" | sudo tee -a /etc/hosts", username => 'cloudadmin');
        $instance->ssh_assert_script_run(cmd => 'cat /etc/hosts', username => 'cloudadmin');
    }
}

1;
