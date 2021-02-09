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
use publiccloud::utils;

# Global variables
my $crm_mon_cmd = 'crm_mon -R -r -n -N -1';

=head2 upload_ha_sap_logs

    upload_ha_sap_logs($instance):

Upload the HA/SAP logs from instance C<$instance> on the Webui.
=cut
sub upload_ha_sap_logs {
    my ($self, $instance) = @_;
    my @logfiles = qw(salt-deployment.log salt-os-setup.log salt-pre-deployment.log salt-result.log);

    # Upload logs from public cloud VM
    $instance->run_ssh_command(cmd => 'sudo chmod o+r /var/log/salt-*');
    foreach my $file (@logfiles) {
        $instance->upload_log("/var/log/$file", log_name => $instance->{instance_id});
    }
}

=head2 wait_until_resources_started

    wait_until_resources_started( [ timeout => $timeout ] );

Wait for resources to be started. Runs C<crm cluster wait_for_startup> in SUT as well
as other verifications on newer versions of SLES (12-SP3+), for up to B<$timeout> seconds
for each command. Timeout must be specified by the named argument B<timeout> (defaults
to 120 seconds). This timeout is scaled by the factor specified in the B<TIMEOUT_SCALE>
setting. Croaks on timeout.
=cut
sub wait_until_resources_started {
    my ($self, %args) = @_;
    my @cmds    = ('crm cluster wait_for_startup');
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 60);

    # At least one node needs to be online
    push @cmds, "$crm_mon_cmd | grep -q Node\\ .*\\ online:";

    # HANA cluster doesn't restart all resources after fencing in some configurations
    if ($args{cluster_type} ne 'hana') {
        # Some CRM options can only been added on recent versions
        push @cmds, "$crm_mon_cmd | grep -iq no\\ inactive\\ resources" if is_sle '12-sp3+';
        # This code is a little bit complicated, but we have to invert the RC for the while loop
        push @cmds, "$crm_mon_cmd | grep -iq starting && RC=false || RC=true; eval \$RC";
    }

    # Execute each comnmand to validate that the cluster is running
    # This can takes time, so a loop is a good idea here
    foreach my $cmd (@cmds) {
        # Each command execution has its own timeout, so we need to reset the counter
        my $start_time = time;

        # Check for cluster/resources status and exit loop when needed
        while ($self->{my_instance}->run_ssh_command(cmd => "sudo $cmd", rc_only => 1)) {
            # Otherwise wait a while if timeout is not reached
            if (time - $start_time < $timeout) {
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
    $title =~ s/[[:blank:]].+// unless defined $args{title};
    my $cmd = $args{cmd};

    delete($args{cmd});
    delete($args{title});
    delete($args{timeout});
    my $out = $self->{my_instance}->run_ssh_command(cmd => "sudo $cmd", timeout => $timeout, %args);
    record_info("$title output - $self->{my_instance}->{instance_id}", $out) unless ($timeout == 0 or $args{quiet} or $args{rc_only});
    return $out;
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
    if (check_var('USE_FENCING', 'poweroff')) {
        record_info('Fencing info', 'Fencing done with systemctl poweroff');
        $self->run_cmd(cmd => 'systemctl poweroff --force', timeout => 0, quiet => 1);
    } else {    # Default fencing uses CRM
        record_info('Fencing info', 'Fencing done with crm');
        $self->run_cmd(cmd => "crm -F node fence $args{hostname}", quiet => 1);
    }

    # Wait till ssh disappear
    my $start_time = time;
    while ((time - $start_time) < $timeout) {
        last unless (defined($self->{my_instance}->wait_for_ssh(timeout => 1, proceed_on_failure => 1, quiet => 1)));
    }
    my $fencing_time = time - $start_time;
    die("Waiting for fencing failed!") unless ($fencing_time < $timeout);
    record_info('Fencing finished!', "Fencing done in ${fencing_time}s");

    # We need to be sure that the server is stopped (if applicable)
    if (is_ec2) {
        my $start_time = time;
        while ($self->{my_instance}->get_state ne 'stopped') {
            if (time - $start_time < $timeout * 2) {
                sleep 5;
            } else {
                # VM takes to much time to shutdown
                die "Server $args{hostname} takes too much time to shutdown!";
            }
        }
    }

    # We have to wait "a little" to ensure that resources are moved to the other node
    sleep $timeout / 2;

    # Wait for the node to restart
    if (is_ec2) {
        record_info("Restart $args{hostname}", 'Restart done using CSP API');
        $self->{my_instance}->start(timeout => $timeout);
    }
    else {
        record_info("Restart $args{hostname}", 'Restart done using Fencing Agent');
        $self->{my_instance}->wait_for_ssh(timeout => $timeout);
    }
}

sub run {
    my ($self)        = @_;
    my $timeout       = 120;
    my @cluster_types = split(',', get_required_var('CLUSTER_TYPES'));

    $self->select_serial_terminal;

    my $provider  = $self->provider_factory();
    my @instances = $provider->create_instances(check_connectivity => 1);

    # Upload all TF/SALT logs first!
    foreach my $instance (@instances) {
        $self->upload_ha_sap_logs($instance);
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
                    $instance->run_ssh_command(cmd => 'sudo sh -c \'until SAPHanaSR-showAttr | grep -q SOK; do sleep 1; done\'', timeout => $timeout);
                    # Show HANA replication state
                    $self->run_cmd(cmd => 'SAPHanaSR-showAttr');
                }

                # Workaround bsc#1179529 on DRBD cluster (only for GCP)
                if (is_gce and $cluster_type eq 'drbd' and $hostname =~ m/${cluster_type}01$/) {
                    record_soft_failure 'bsc#1179529 - [ha-sap-terraform-deployments_v6] DRBD resource fails after reboot on GCE';
                    # Get the UUID of DRBD device
                    my $drbd_conf_file = '/etc/drbd.d/sapdata.res';
                    my $drbd_device = $self->run_cmd(cmd => "awk '/[[:blank:]]+disk[[:blank:]]+/ { print \$NF }' $drbd_conf_file | sed -n '/\\/dev\\//s/;//p'", quiet => 1);
                    die "DRBD device can't be found!" unless defined $drbd_device;
                    my $drbd_uuid_device = $self->run_cmd(cmd => "blkid -o export $drbd_device | awk -F'=' '/^UUID=/ { print \$NF }'", quiet => 1);
                    die "DRBD UUID can't be found!" unless defined $drbd_uuid_device;

                    # Replace current device name by its UUID in config file and sync cluster conf
                    $self->run_cmd(cmd => "sed -i '/[[:blank:]]*disk[[:blank:]]*\\/dev\\//s;\\(^[[:blank:]]*\\).*;\\1disk /dev/disk/by-uuid/${drbd_uuid_device}\\;;' $drbd_conf_file", quiet => 1);
                    $self->run_cmd(cmd => 'csync2 -xF', quiet => 1);

                    # Cleanup DRBD resource
                    $self->run_cmd(cmd => 'crm resource cleanup drbd-sapdata', quiet => 1);
                }

                # Workaround bsc#1179782 - Check if STONITH is disabled
                unless ($instance->run_ssh_command(cmd => 'sudo sh -c \'crm configure show\' | grep -q stonith-enabled=false', rc_only => 1)) {
                    record_soft_failure 'bsc#1179782 - [ha-sap-terraform-deployments_v6] stonith-enabled is set to false instead of true';
                    $self->run_cmd(cmd => 'crm configure property stonith-enabled=true', quiet => 1);
                }

                # Check cluster status
                $self->run_cmd(cmd => $crm_mon_cmd);

                # Fence the node and let time for HA resources to restart
                $self->wait_until_resources_started(cluster_type => $cluster_type, timeout => $timeout); # We need to be sure that the cluster is OK before a fencing test
                $self->fence_node(hostname => $hostname, timeout => $timeout);

                # Workaround bsc#1179838 on GCP - Pacemaker doesn't start correctly after a STONITH
                unless ($instance->run_ssh_command(cmd => 'systemctl --no-pager status pacemaker | grep -iq \'Active: inactive (dead)\'', rc_only => 1)) {
                    record_soft_failure 'bsc#1179838 - [ha-sap-terraform-deployments_v6] Pacemaker doesn\'t start correctly after a STONITH';
                    $self->run_cmd(cmd => 'systemctl --no-pager restart pacemaker', quiet => 1);
                    sleep 30;                                                                            # We need to wait a "little" before
                }

                $self->wait_until_resources_started(cluster_type => $cluster_type, timeout => $timeout);
                $self->run_cmd(cmd => $crm_mon_cmd);

                # Do the HANA "magic" if needed
                if ($cluster_type eq 'hana') {
                    my $remoteHost = $hostname;
                    $remoteHost =~ s/01/02/;
                    my $hana_cmd = "hdbnsutil -sr_register --name=HDB --remoteHost=$remoteHost --remoteInstance=00 --replicationMode=sync --operationMode=logreplay";
                    $self->run_cmd(cmd => "-i -u prdadm $hana_cmd",                        title => 'HANA register');
                    $self->run_cmd(cmd => '-i crm resource cleanup msl_SAPHana_PRD_HDB00', title => 'Resources cleanup');

                    # Check cluster resources
                    $self->wait_until_resources_started(timeout => $timeout);
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
