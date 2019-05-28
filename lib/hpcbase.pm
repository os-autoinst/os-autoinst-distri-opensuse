package hpcbase;
use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils 'systemctl';

sub enable_and_start {
    my ($self, $arg) = @_;
    systemctl "enable $arg";
    systemctl "start $arg";
}

sub upload_service_log {
    my ($self, $service_name) = @_;
    script_run("journalctl -u $service_name > /tmp/$service_name");
    script_run("cat /tmp/$service_name");
    upload_logs("/tmp/$service_name", failok => 1);
}

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal;
    script_run("journalctl -o short-precise > /tmp/journal.log");
    script_run('cat /tmp/journal.log');
    upload_logs('/tmp/journal.log', failok => 1);
    upload_service_log('wickedd-dhcp4.service');
}

sub switch_user {
    my ($self, $username) = @_;
    type_string("su - $username\n");
    assert_screen 'user-nobody';
}

sub prepare_slurm_conf {
    # Create proper /etc/hosts and /etc/slurm.conf for each node
    my $nodes = get_required_var("CLUSTER_NODES");

    my $slurm_slave_nodes = "";
    for (my $node = 1; $node < $nodes; $node++) {
        my $node_name = sprintf("slurm-slave%02d", $node);
        $slurm_slave_nodes = "${slurm_slave_nodes},${node_name}";
    }
    my $config = << "EOF";
sed -i "/^ControlMachine.*/c\\ControlMachine=slurm-master" /etc/slurm/slurm.conf
sed -i "/^NodeName.*/c\\NodeName=slurm-master${slurm_slave_nodes} Sockets=1 CoresPerSocket=1 ThreadsPerCore=1 State=unknown" /etc/slurm/slurm.conf
sed -i "/^PartitionName.*/c\\PartitionName=normal Nodes=slurm-master${slurm_slave_nodes} Default=YES MaxTime=24:00:00 State=UP" /etc/slurm/slurm.conf
EOF
    assert_script_run($_) foreach (split /\n/, $config);
}

=head2
    prepare_user_and_group()
  creating slurm user and group with some pre-defined ID
 needed due to https://bugzilla.suse.com/show_bug.cgi?id=1124587
=cut
sub prepare_user_and_group {
    my ($self) = @_;
    assert_script_run('groupadd slurm -g 7777');
    assert_script_run('useradd -u 7777 -g 7777 slurm');
}

1;
