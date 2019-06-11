package hpcbase;
use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;

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

## Prepare ctl node names, so those names could be reused, for instance
## in config preparation, munge key distribution, etc.
## TODO: make it generic, once it is needed
sub ctl_node_names {
    my $ctl_nodes = get_required_var("CLUSTER_CTL_FAILOVER");
    my @ctl_node_names;

    for (my $node = 0; $node <= $ctl_nodes; $node++) {
        my $name = sprintf("slurm-master%02d", $node);
        push @ctl_node_names, $name;
    }

    return @ctl_node_names;
}

## Prepare compute node names, so those names could be reused, for
## instance in config preparation, munge key distribution, etc.
## TODO: make it generic, once it is needed
sub compute_node_names {
    my $ctl_nodes = get_required_var("CLUSTER_CTL_FAILOVER");
    my $nodes     = get_required_var("CLUSTER_NODES");

    my @compute_node_names;

    #adjust node value, so slurm.conf could account for correct count of slaves
    $nodes = $nodes - $ctl_nodes;
    for (my $node = 1; $node < $nodes; $node++) {
        my $name = sprintf("slurm-slave%02d", $node);
        push @compute_node_names, $name;
    }

    return @compute_node_names;
}

## Prepare all node names, so those names could be reused
sub cluster_names {
    my @cluster_names;

    my @cluster_ctl_nodes     = ctl_node_names();
    my @cluster_compute_nodes = compute_node_names();

    push(@cluster_ctl_nodes, @cluster_compute_nodes);
    @cluster_names = @cluster_ctl_nodes;

    return @cluster_names;
}

sub prepare_slurm_conf {
    my $ctl_nodes = get_required_var("CLUSTER_CTL_FAILOVER");

    my @cluster_ctl_nodes     = ctl_node_names();
    my @cluster_compute_nodes = compute_node_names();
    my $cluster_ctl_nodes     = join(',', @cluster_ctl_nodes);
    my $cluster_compute_nodes = join(',', @cluster_compute_nodes);

    if ($ctl_nodes) {
        my $config = << "EOF";
sed -i "/^ControlMachine.*/c\\ControlMachine=$cluster_ctl_nodes[0]" /etc/slurm/slurm.conf
sed -i "/^#BackupController.*/c\\BackupController=$cluster_ctl_nodes[1]" /etc/slurm/slurm.conf
sed -i "/^StateSaveLocation.*/c\\StateSaveLocation=/shared/slurm/" /etc/slurm/slurm.conf
sed -i "/^NodeName.*/c\\NodeName=$cluster_ctl_nodes,$cluster_compute_nodes Sockets=1 CoresPerSocket=1 ThreadsPerCore=1 State=unknown" /etc/slurm/slurm.conf
sed -i "/^PartitionName.*/c\\PartitionName=normal Nodes=$cluster_ctl_nodes,$cluster_compute_nodes Default=YES MaxTime=24:00:00 State=UP" /etc/slurm/slurm.conf
sed -i "/^SlurmctldTimeout.*/c\\SlurmctldTimeout=15" /etc/slurm/slurm.conf
sed -i "/^SlurmdTimeout.*/c\\SlurmdTimeout=60" /etc/slurm/slurm.conf
EOF
        assert_script_run($_) foreach (split /\n/, $config);
    } else {
        my $config = << "EOF";
sed -i "/^ControlMachine.*/c\\ControlMachine=$cluster_ctl_nodes[0]" /etc/slurm/slurm.conf
sed -i "/^NodeName.*/c\\NodeName=$cluster_ctl_nodes,$cluster_compute_nodes Sockets=1 CoresPerSocket=1 ThreadsPerCore=1 State=unknown" /etc/slurm/slurm.conf
sed -i "/^PartitionName.*/c\\PartitionName=normal Nodes=$cluster_ctl_nodes,$cluster_compute_nodes Default=YES MaxTime=24:00:00 State=UP" /etc/slurm/slurm.conf
EOF
        assert_script_run($_) foreach (split /\n/, $config);
    }
}

sub distribute_munge_key {
    my @cluster_nodes = cluster_names();
    foreach (@cluster_nodes) {
        exec_and_insert_password("scp -o StrictHostKeyChecking=no /etc/munge/munge.key root\@$_:/etc/munge/munge.key");
    }
}

sub distribute_slurm_conf {
    my @cluster_nodes = cluster_names();
    foreach (@cluster_nodes) {
        exec_and_insert_password("scp -o StrictHostKeyChecking=no /etc/slurm/slurm.conf root\@$_:/etc/slurm/slurm.conf");
    }
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
