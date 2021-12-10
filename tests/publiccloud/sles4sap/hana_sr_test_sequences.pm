
use strict;
use warnings FATAL => 'all';
use diagnostics;
use Data::Dumper;
use testapi;
use Mojo::Base qw(publiccloud::basetest);
use Mojo::JSON;
use Mojo::File qw(path);
use sles4sap_publiccloud;
use publiccloud::utils;

# Global variables
my $crm_mon_cmd = 'crm_mon -R -r -n -N -1';

sub dummy_resources_file(){

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
    my ($self, $run_args) = @_;
    my $timeout = 120;
    my @cluster_types = split(',', get_required_var('CLUSTER_TYPES'));
    $self->select_serial_terminal;
    my $instances = $run_args->{instances};

    foreach my $instance (@$instances) {
        $self->{my_instance} = $instance;
        record_info('single inst', Dumper($instance));

        # Get the hostname of the VM, it contains the cluster type
        my $hostname = $self->run_cmd(cmd => 'uname -n', quiet => 1);

        foreach my $cluster_type (@cluster_types) {
            if ($hostname =~ m/${cluster_type}01$/) {
                                # Check cluster status
                $self->run_cmd(cmd => $crm_mon_cmd);

                # Fence the node and let time for HA resources to restart
                $self->fence_node(hostname => $hostname, timeout => $timeout);
                $self->wait_until_resources_started(cluster_type => $cluster_type, timeout => $timeout);
                $self->run_cmd(cmd => $crm_mon_cmd);
                                # Do the HANA "magic" if needed
                if ($cluster_type eq 'hana') {
                    my $remoteHost = $hostname;
                    $remoteHost =~ s/01/02/;
                    my $hana_cmd = "hdbnsutil -sr_register --name=HDB --remoteHost=$remoteHost --remoteInstance=00 --replicationMode=sync --operationMode=logreplay";
                    $self->run_cmd(cmd => "-i -u prdadm $hana_cmd", title => 'HANA register');
                    $self->run_cmd(cmd => '-i crm resource cleanup msl_SAPHana_PRD_HDB00', title => 'Resources cleanup');

                    # Check cluster resources
                    $self->wait_until_resources_started(timeout => $timeout);
                    $self->run_cmd(cmd => $crm_mon_cmd);
                };
            };
        };
    };
};

1;