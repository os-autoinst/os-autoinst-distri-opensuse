# SUSE's openQA tests
#
# Copyright © 2019-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test public cloud SLES4SAP images
#
# Maintainer: Loic Devulder <ldevulder@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use Mojo::File 'path';
use Mojo::JSON;
use version_utils 'is_sle';

# Global variables
my $crm_mon_cmd = 'crm_mon -R -r -n -N -1';

=head2 upload_ha_sap_logs

    upload_ha_sap_logs($instance):

Upload the HA/SAP logs from instance C<$instance> on the Webui.
=cut
sub upload_ha_sap_logs {
    my ($self, $instance) = @_;
    my @logfiles = qw(provisioning.log salt-deployment.log salt-formula.log salt-pre-installation.log);

    # Upload logs from public cloud VM
    $instance->run_ssh_command(cmd => 'sudo chmod o+r /tmp/*.log');
    foreach my $file (@logfiles) {
        $instance->upload_log("/tmp/$file", log_name => $instance->{instance_id});
    }
}

=head2 wait_until_resources_started

    wait_until_resources_started();

Wait for HA cluster to be started.
=cut
sub wait_until_resources_started {
    my ($self, %args) = @_;
    my @cmds    = ('crm cluster wait_for_startup');
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 60);

    # HANA cluster doesn't restart all resources after fencing in some configurations
    if ($args{cluster_type} ne 'hana') {
        # Some CRM options can only been added on recent versions
        push @cmds, "$crm_mon_cmd | grep -iq no\\ inactive\\ resources" if is_sle '12-sp3+';
    }

    # Execute each comnmand to validate that the cluster is running
    # This can takes time, so a loop is a good idea here
    foreach my $cmd (@cmds) {
        # Each command execution has its own timeout, so we need to reset the counter
        my $starttime = time;

        # Check for cluster/resources status and exit loop when needed
        my $ret;
        while ($ret = $self->{my_instance}->run_ssh_command(cmd => "sudo $cmd", rc_only => 1)) {
            # Otherwise wait a while if timeout is not reached
            if (time - $starttime < $timeout) {
                sleep 5;
            }
            else {
                # Cluster doesn't start properly, show state before dying
                $self->run_cmd(cmd => $crm_mon_cmd);
                die "Cluster/resources did not start within $timeout seconds (cmd='$cmd')";
            }
        }
    }
}

=head2 run_cmd
    run_cmd(cmd => 'command', [timeout => 60]);

Runs a command C<cmd> via ssh in the given VM and log the output.
All commands are executed through C<sudo>.
=cut
sub run_cmd {
    my ($self, %args) = @_;
    die('Argument <cmd> missing') unless ($args{cmd});
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 60);
    my $title   = $args{title} // $args{cmd};
    $title =~ s/[[:blank:]].+// if !defined $args{title};

    my $out = $self->{my_instance}->run_ssh_command(cmd => "sudo $args{cmd}", timeout => $timeout);
    record_info("$title output - $self->{my_instance}->{instance_id}", $out) unless ($timeout == 0);
}

=head2 fence_node

    fence_node([hostname => $hostname], [timeout => 60]);

Fence a HA node using C<systemctl poweroff>.
This command terminates when the node is back.
=cut
sub fence_node {
    my ($self, %args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 60);
    $args{hostname} //= $self->{my_instance}->{instance_id};

    # Do the fencing!
    record_info('Fencing info', 'Fencing done with systemctl poweroff');
    $self->run_cmd(cmd => 'systemctl poweroff --force', timeout => 0);

    # skip the one minute waiting
    sleep 60;
    my $start_time = time();

    # Wait till ssh disappear
    while ((time() - $start_time) < $timeout) {
        last unless (defined($self->{my_instance}->wait_for_ssh(timeout => 1, proceed_on_failure => 1)));
    }
    my $fencing_time = time() - $start_time;
    die("Waiting for fencing failed!") unless ($fencing_time < $timeout);
    record_info('Fencing finished!', "Fencing done in ${fencing_time}s");

    # We have to wait "a little" to ensure that resources are moved to the other node
    sleep $timeout;

    # Wait for the node to restart
    record_info("Restart $args{hostname}", 'Restart done using CSP API');
    $self->{my_instance}->start(timeout => $timeout);

    # Let's time for the resources to came back
    sleep $timeout;
}

sub run {
    my ($self)        = @_;
    my $timeout       = bmwqemu::scale_timeout(60);
    my @cluster_types = split(',', get_required_var('CLUSTER_TYPES'));

    $self->select_serial_terminal;

    my $provider  = $self->provider_factory();
    my @instances = $provider->create_instances(check_connectivity => 1);

    # Upload all TF/SALT logs first!
    foreach my $instance (@instances) {
        $self->upload_ha_sap_logs($instance);
    }

    # Workaround bsc#1170037
    foreach my $instance (@instances) {
        $self->{my_instance} = $instance;

        # Get the hostname of the VM, it contains the cluster type
        my $hostname = $instance->run_ssh_command(cmd => 'uname -n');

        # Only on HA node
        foreach my $cluster_type (@cluster_types) {
            # Wait for HANA sync to be done
            # NOTE: this is done in the 'foreach' section below, but needs to be done before restarting pacemaker
            sleep $timeout * 2 if ($cluster_type eq 'hana');    # A 'sleep' should be enough here
            if ($hostname =~ m/${cluster_type}/) {
                # Check if sbd service is activated
                if ($instance->run_ssh_command(cmd => 'systemctl is-enabled sbd', proceed_on_failure => 1) eq 'disabled') {
                    record_soft_failure("bsc#1170037 - All nodes not shown by sbd list command on node $hostname");
                    $self->run_cmd(cmd => 'sudo systemctl enable sbd');
                    $self->run_cmd(cmd => 'sudo systemctl restart pacemaker');
                    sleep $timeout;                             # We have to wait a little for the cluster to update its stack
                }
            }
        }
    }

    foreach my $instance (@instances) {
        $self->{my_instance} = $instance;

        # Get the hostname of the VM, it contains the cluster type
        my $hostname = $instance->run_ssh_command(cmd => 'uname -n');

        # Actions are done only on the first node of each cluster
        foreach my $cluster_type (@cluster_types) {
            if ($hostname =~ m/${cluster_type}01$/) {
                if ($cluster_type eq 'hana') {
                    # Before doing anything on the cluster we have to wait for the HANA sync to be done
                    $instance->run_ssh_command(cmd => 'sudo sh -c \'until SAPHanaSR-showAttr | grep -q SOK; do sleep 1; done\'', timeout => $timeout * 2);
                    # Show HANA replication state
                    $self->run_cmd(cmd => 'SAPHanaSR-showAttr');
                }

                # Check cluster status
                $self->run_cmd(cmd => $crm_mon_cmd);

                # Fence the node and let time for HA resources to restart
                $self->fence_node(hostname => $hostname);
                $self->wait_until_resources_started(cluster_type => $cluster_type);
                $self->run_cmd(cmd => $crm_mon_cmd);

                # Do the HANA "magic" if needed
                if ($cluster_type eq 'hana') {
                    my $remoteHost = $hostname;
                    $remoteHost =~ s/01/02/;
                    my $hana_cmd = "hdbnsutil -sr_register --name=HDB --remoteHost=$remoteHost --remoteInstance=00 --replicationMode=sync --operationMode=logreplay";
                    $self->run_cmd(cmd => "-i -u prdadm $hana_cmd",                        title => 'HANA register');
                    $self->run_cmd(cmd => '-i crm resource cleanup msl_SAPHana_PRD_HDB00', title => 'Resources cleanup');
                    sleep $timeout;    # We have to wait a little for the cluster to update its stack

                    # Check cluster resources
                    $self->wait_until_resources_started(timeout => 120);
                    $self->run_cmd(cmd => $crm_mon_cmd);
                }

                # We can close the loop now
                last;
            }
        }
    }
}

1;

=head1 Discussion

This module is used to test public cloud SLES4SAP images.
Logs are uploaded at the end.

=head1 Configuration

=head2 PUBLIC_CLOUD_SLES4SAP

If set, this test module is added to the job.

=head2 PUBLIC_CLOUD_VAULT_NAMESPACE

Set the needed namespace, e.g. B<qa-shap>.

=head2 CLUSTER_TYPES

Set the type of cluster that have to be analyzed (example: "drbd hana").

=cut
