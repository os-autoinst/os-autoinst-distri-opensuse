use base "hacluster";
use testapi;
use lockapi;
use Time::HiRes qw(sleep);

sub run() {
    type_string "SuSEfirewall2 off\n";
    #FIXME: I don't like the path here
    my $cluster_init = script_output "ha-cluster-init -y -s /dev/disk/by-path/ip-*-lun-0; echo ha_cluster_init=\$?", 120;
    if ($cluster_init =~ /ha_cluster_init=1/) { #failed to initialize the cluster, trying again
        script_run "ha-cluster-init -y -s /dev/disk/by-path/ip-*-lun-0; echo ha_cluster_init=\$? > /dev/$serialdev", 120;
        upload_logs "/var/log/ha-cluster-bootstrap.log";
        die "ha-cluster-init failed" unless wait_serial "ha_cluster_init=0", 60;
    }
    upload_logs "/var/log/ha-cluster-bootstrap.log";
    type_string "crm_mon -1\n";
    save_screenshot;
    mutex_create "MUTEX_HA_" . get_var("CLUSTERNAME");
    #mutex_unlock "MUTEX_HA_NODE_JOINED_" . get_var("CLUSTERNAME"); # should be mutex_lock
    sleep 60; # mutex_unlock doesn't work in this thread, that's the workaround
    mutex_unlock "MUTEX_HA_" . get_var("CLUSTERNAME"); #should be mutex_lock
    type_string "crm_mon -1\n";
    save_screenshot;
}

sub test_flags {
    return { milestone => 1, fatal => 1, important => 1 };
}

1;
