use base "hacluster";
use testapi;
use autotest;
use lockapi;
use Time::HiRes qw(sleep);

sub run() {
    type_string "SuSEfirewall2 off\n";
    mutex_lock "MUTEX_HA_" . get_var("CLUSTERNAME");
    script_run "ping -c1 " . get_var ("HACLUSTERJOIN");
    script_run "ha-cluster-join -yc " . get_var ("HACLUSTERJOIN");
    sleep 20;
    type_password;
    send_key( "ret", 1 );
    script_run "crm_mon -1";
    save_screenshot ;
    mutex_unlock "MUTEX_HA_" . get_var("CLUSTERNAME"); #should be mutex_lock
}

sub test_flags {
    return { milestone => 1, fatal => 1, important => 1 };
}

1;
