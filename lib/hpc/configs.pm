package hpc::configs;
use base hpcbase;
use strict;
use warnings;
use testapi;
use utils;

our @EXPORT = qw(
  prepare_slurm_conf
  prepare_slurmdb_conf
);

## TODO: improve this ever-growing sub, so that it will be easier to
## maintain and expand if needed as well as there will be less duplications
sub prepare_slurm_conf {
    my ($self) = @_;
    my $slurm_conf = get_required_var("SLURM_CONF");

    my @cluster_ctl_nodes     = $self->master_node_names();
    my @cluster_compute_nodes = $self->slave_node_names();
    my $cluster_ctl_nodes     = join(',', @cluster_ctl_nodes);
    my $cluster_compute_nodes = join(',', @cluster_compute_nodes);

    if ($slurm_conf eq "basic") {
        my $config = << "EOF";
sed -i "/^ControlMachine.*/c\\ControlMachine=$cluster_ctl_nodes[0]" /etc/slurm/slurm.conf
sed -i "/^NodeName.*/c\\NodeName=$cluster_ctl_nodes,$cluster_compute_nodes Sockets=1 CoresPerSocket=1 ThreadsPerCore=1 State=unknown" /etc/slurm/slurm.conf
sed -i "/^PartitionName.*/c\\PartitionName=normal Nodes=$cluster_ctl_nodes,$cluster_compute_nodes Default=YES MaxTime=24:00:00 State=UP" /etc/slurm/slurm.conf
EOF
        assert_script_run($_) foreach (split /\n/, $config);
    } elsif ($slurm_conf eq "accounting") {
        my $config = << "EOF";
sed -i "/^ControlMachine.*/c\\ControlMachine=$cluster_ctl_nodes[0]" /etc/slurm/slurm.conf
sed -i "/^NodeName.*/c\\NodeName=$cluster_ctl_nodes,$cluster_compute_nodes Sockets=1 CoresPerSocket=1 ThreadsPerCore=1 State=unknown" /etc/slurm/slurm.conf
sed -i "/^PartitionName.*/c\\PartitionName=normal Nodes=$cluster_ctl_nodes,$cluster_compute_nodes Default=YES MaxTime=24:00:00 State=UP" /etc/slurm/slurm.conf
sed -i "/^#JobAcctGatherType.*/c\\JobAcctGatherType=jobacct_gather/linux" /etc/slurm/slurm.conf
sed -i "/^#JobAcctGatherFrequency.*/c\\JobAcctGatherFrequency=12" /etc/slurm/slurm.conf
sed -i "/^#AccountingStorageType.*/c\\AccountingStorageType=accounting_storage/slurmdbd" /etc/slurm/slurm.conf
sed -i "/^#AccountingStorageHost.*/c\\AccountingStorageHost=$cluster_compute_nodes[-1]" /etc/slurm/slurm.conf
sed -i "/^#AccountingStorageUser.*/c\\AccountingStoragePort=20088" /etc/slurm/slurm.conf
EOF
        assert_script_run($_) foreach (split /\n/, $config);
    } elsif ($slurm_conf eq "ha") {
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
    } elsif ($slurm_conf eq "nfs_db") {
        my $config = << "EOF";
sed -i "/^ControlMachine.*/c\\ControlMachine=$cluster_ctl_nodes[0]" /etc/slurm/slurm.conf
sed -i "/^#BackupController.*/c\\BackupController=$cluster_ctl_nodes[1]" /etc/slurm/slurm.conf
sed -i "/^StateSaveLocation.*/c\\StateSaveLocation=/shared/slurm/" /etc/slurm/slurm.conf
sed -i "/^NodeName.*/c\\NodeName=$cluster_ctl_nodes,$cluster_compute_nodes Sockets=1 CoresPerSocket=1 ThreadsPerCore=1 State=unknown" /etc/slurm/slurm.conf
sed -i "/^PartitionName.*/c\\PartitionName=normal Nodes=$cluster_ctl_nodes,$cluster_compute_nodes Default=YES MaxTime=24:00:00 State=UP" /etc/slurm/slurm.conf
sed -i "/^SlurmctldTimeout.*/c\\SlurmctldTimeout=15" /etc/slurm/slurm.conf
sed -i "/^SlurmdTimeout.*/c\\SlurmdTimeout=60" /etc/slurm/slurm.conf
sed -i "/^#JobAcctGatherType.*/c\\JobAcctGatherType=jobacct_gather/linux" /etc/slurm/slurm.conf
sed -i "/^#JobAcctGatherFrequency.*/c\\JobAcctGatherFrequency=12" /etc/slurm/slurm.conf
sed -i "/^#AccountingStorageType.*/c\\AccountingStorageType=accounting_storage/slurmdbd" /etc/slurm/slurm.conf
sed -i "/^#AccountingStorageHost.*/c\\AccountingStorageHost=$cluster_compute_nodes[-1]" /etc/slurm/slurm.conf
sed -i "/^#AccountingStorageUser.*/c\\AccountingStoragePort=20088" /etc/slurm/slurm.conf
EOF
        assert_script_run($_) foreach (split /\n/, $config);
    } else {
        die "Unsupported value of SLURM_CONF test setting!";
    }
}

sub prepare_slurmdb_conf {
    my ($self) = @_;
    my @cluster_compute_nodes = $self->slave_node_names();

    my $config = << "EOF";
sed -i "/^DbdAddr.*/c\\#DbdAddr" /etc/slurm/slurmdbd.conf
sed -i "/^DbdHost.*/c\\DbdHost=$cluster_compute_nodes[-1]" /etc/slurm/slurmdbd.conf
sed -i "/^#StorageHost.*/c\\StorageHost=$cluster_compute_nodes[-1]" /etc/slurm/slurmdbd.conf
sed -i "/^#StorageLoc.*/c\\StorageLoc=slurm_acct_db" /etc/slurm/slurmdbd.conf
sed -i "/^#DbdPort.*/c\\DbdPort=20088" /etc/slurm/slurmdbd.conf
EOF
    assert_script_run($_) foreach (split /\n/, $config);
}

1;
