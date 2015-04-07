use base "installbasetest";
use testapi;
use autotest;

sub run() {
    if (check_var("WORKER_CLASS", "ha_master")) {
        type_string "sleha-init -y -s /dev/disk/by-id/scsi-1LIO-ORG.FILEIO:348cfd84-58a1-426e-9797-e22f04cf207f\n";
        assert_screen 'cluster-init',60;
        type_string "crm status\n";
        assert_screen 'cluster-status';
        send_key 'ctrl-l';
        mutex_create('cluster-init');
    }
    else {
    mutex_unlock('cluster-init');
    type_string "sleha-join -y -c 10.0.2.16\n";
    assert_screen 'cluster-join-password';
    type_string "nots3cr3t\n";
    if ( !check_screen('cluster-join-finished',60) ) {
        type_string "hb_report -f 00:00 hbreport\n";
        upload_logs "/root/hbreport.tar.bz2";
        type_string "tailf /var/log/messages\n"; # Probably redundant, remove if not needed
        save_screenshot();
    }
    type_string "crm status\n";
    if ( !check_screen('cluster-status') ) {
        type_string "hb_report -f 00:00 hbreport\n";
        upload_logs "/root/hbreport.tar.bz2";
        type_string "tailf /var/log/messages\n"; # Probably redundant, remove if not needed
        save_screenshot();
    }
    send_key 'ctrl-l';
    }
}

1;
