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
use Data::Dumper;

our @EXPORT = qw(
    run_cmd
    wait_until_resources_started
    upload_ha_sap_logs
    is_hana_master
    is_hana_resource_running
    stop_hana
    register_hana
    do_takeover
    get_replication_info
    is_hana_online
);

# Global variables
our $crm_mon_cmd = 'crm_mon -R -r -n -N -1';

=head2 run_cmd
    run_cmd(cmd => 'command', [runas => 'user', timeout => 60]);

Runs a command C<cmd> via ssh in the given VM and log the output.
All commands are executed through C<sudo>.
If 'runas' defined, command will be executed as specified user,
otherwise it will be executed as root.

=cut
sub run_cmd {
    my ($self, %args) = @_;
    die('Argument <cmd> missing') unless ($args{cmd});
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 60);
    my $title = $args{title} // $args{cmd};
    $title =~ s/[[:blank:]].+// unless defined $args{title};
    my $cmd = defined($args{'runas'}) ? "su - $args{'runas'} -c '$args{cmd}'" : "$args{cmd}";

    # Without cleaning up variables SSH commands get executed under wrong user
    delete($args{cmd});
    delete($args{title});
    delete($args{timeout});
    delete($args{runas});

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
    record_info('Cluster type, wait', $args{cluster_type});
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


=head2 is_hana_master
    is_hana_master();

Checks if given VM contains HANA master node.
=cut
sub is_hana_master {
    my ($self) = @_;
    my $hostname = $self->{my_instance}->{instance_id};
    my $resource_output = $self->run_cmd(cmd => "crm resource status msl_SAPHana_PRD_HDB00", quiet => 1);
    my $hana_master_node = grep{/Master/ && /$hostname/} split(/\n/, $resource_output);
    return $hana_master_node;
}

=head2 is_hana_online
    is_hana_online([timeout => 120, wait_for_start => 'false']);

Check if hana DB is online. Define 'wait_for_start' to wait for DB to start.
=cut
sub is_hana_online {
    my ($self, %args) = @_;
    my $wait_for_start = defined($args{wait_for_start}) ? 1 : 0;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 120);
    my $start_time = time;
    my $db_status = 0;

    while ($db_status != 1) {
        record_info( $self->get_replication_info()->{online} );
        $db_status = ($self->get_replication_info()->{online} eq "true") ? 1 : 0;
        last if $wait_for_start == 0;
        last if (time - $start_time > $timeout);
        sleep 30;
    }
    return $db_status;
}


=head2 is_hana_resource_running
    is_hana_resource_running([timeout => 60]);

Checks if resource msl_SAPHana_PRD_HDB00 is running on given node.
=cut
sub is_hana_resource_running {
    my ($self) = @_;
    my $hostname = $self->{my_instance}->{instance_id};

    my $resource_output = $self->run_cmd(cmd => "crm resource status msl_SAPHana_PRD_HDB00", quiet => 1);
    my $node_status = grep{/Masters|Slaves|Started/ && /$hostname/} split(/\n/, $resource_output);
    return $node_status;
}

=head2 stop_hana
    hana_stop_and_wait();

Stops hana database using method specified and waits for resources being stopped.
Default method is 'stop = HDB stop'
Methods available:
  stop = HDB stop
  kill = HDB kill -x
  crash = proc-systrigger

=cut
sub stop_hana {
    my ($self, %args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 300);
    my $method = defined($args{method}) ? $args{method} : 'stop';
        # Running as prdadm via "su - <user> command"
    my $user = "prdadm" if ($method eq "stop" or "kill");
    my %commands = (
        "stop"  => "HDB stop",
        "kill"  => "HDB kill -x",
        "crash" => "proc-sysrq"
    );

    my $cmd = $commands{$method};

    record_info("Stopping HANA", "CMD:$cmd");
    $self->run_cmd(cmd => $cmd, runas=>$user , timeout => $timeout);

    # Wait for resource to stop
    my $start_time = time;
    while ($self->is_hana_resource_running()) {
        if (time - $start_time > $timeout){
            record_info("Cluster status", $self->run_cmd(cmd => $crm_mon_cmd));
            die("DB stop operation timed out($timeout sec).");
        }
        sleep 30;
    }
}

=head2 start_hana
    start_hana([timeout => 60]);

Starts hana database using 'HDB start' and waits for resources being started.

=cut

sub start_hana{
    record_info('Not implemented yet')
}


=head2 do_takeover
    do_takeover();

If 'AUTOMATIC_TAKEOVER' parameter is enabled, subroutine will wait for takeover to finish.
In case parameter is missing there will be an attempt to do the takeover.
=cut
sub do_takeover {
    my ($self) = @_;
    my $primary_hana_status = $self->is_hana_online();
    die("Database is not offline") if ($primary_hana_status == 1);

    return $primary_hana_status;
}

=head2 register_hana
    register_hana();

=cut
sub register_hana {
    my $cmd = "hdbnsutil -sr_register --name=HDB --remoteHost= --remoteInstance=00 --replicationMode=sync --operationMode=logreplay";

}

=head2 get_replication_info
    get_replication_info();
    Parses hdbnsutil command output.
    Returns hash of found values converted to lowercase and replaces spaces to underscores.
=cut
sub get_replication_info {
    my ($self) = @_;
    my $output_cmd = $self->run_cmd(cmd => "hdbnsutil -sr_state| grep -E :[^\^]", runas => "prdadm");

    # Create a hash from hdbnsutil output ,convert to lowercase with underscore instead of space.
    my %out = $output_cmd =~ /^?\s?([\/A-z\s]*\S+):\s(\S+)\n/g;
    %out = map { $_ =~ s/\s/_/g; lc $_} %out;
    record_info('params_hash', Dumper(\%out) );
    return \%out;
}

1;