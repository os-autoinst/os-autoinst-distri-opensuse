# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Functions for SAP tests

package sles4sap_publiccloud;

use parent 'Exporter';
use strict;
use warnings FATAL => 'all';
use Mojo::Base 'publiccloud::basetest';
use version_utils 'is_sle';
use publiccloud::utils;
use testapi;

our @EXPORT = qw(run_cmd wait_until_resources_started upload_ha_sap_logs);

# Global variables
my $crm_mon_cmd = 'crm_mon -R -r -n -N -1';

=head2 run_cmd
    run_cmd(cmd => 'command', [timeout => 60]);

Runs a command C<cmd> via ssh in the given VM and log the output.
All commands are executed through C<sudo>.
=cut
sub run_cmd {
    my ($self, %args) = @_;
    die('Argument <cmd> missing') unless ($args{cmd});
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 60);
    my $title = $args{title} // $args{cmd};
    $title =~ s/[[:blank:]].+// unless defined $args{title};
    my $cmd = $args{cmd};

    delete($args{cmd});
    delete($args{title});
    delete($args{timeout});
    my $out = $self->{my_instance}->run_ssh_command(cmd => "sudo $cmd", timeout => $timeout, %args);
    record_info("$title output - $self->{my_instance}->{instance_id}", $out) unless ($timeout == 0 or $args{quiet} or $args{rc_only});
    return $out;
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
    my @cmds = ('crm cluster wait_for_startup');
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
        while ($self->run_cmd(cmd => "$cmd", rc_only => 1)) {
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
        $instance->upload_log("/var/log/$file", log_name => "$instance->{instance_id}-$file");
    }
}

1;