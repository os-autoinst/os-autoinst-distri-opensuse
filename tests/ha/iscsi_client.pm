use base "hacluster";
use testapi;

sub run() {
    script_run("yast2 iscsi-client");
    assert_screen "yast2-iscsi-client", 30;
    send_key 'alt-b'; #start iscsi daemon on Boot
    send_key 'alt-i'; #Initiator name
    for ( 1 .. 40 ) { send_key "backspace"; }
    type_string "iqn.1996-04.de.suse:01:" . get_var("HOSTNAME") . "." . get_var("CLUSTERNAME");
    save_screenshot ;
#    assert_screen "yast2-iscsi-client-initiator-name", 30;
    send_key 'alt-v'; #discoVered targets
    assert_screen "yast2-iscsi-client-discovered-targets", 30;
    send_key 'alt-d'; #Discovery
    assert_screen "yast2-iscsi-client-discovery";
    send_key 'alt-i'; #Ip address
    type_string "srv1";
    send_key 'alt-n'; #Next
    assert_screen "yast2-iscsi-client-target-list";
    #select target with internal IP first?
    send_key 'alt-e'; #connEct
    assert_screen "yast2-iscsi-client-target-startup";
    send_key 'alt-s'; #Startup
    send_key 'down';
    send_key 'down'; #select 'automatic'
    assert_screen "yast2-iscsi-client-target-startup-automatic-selected";
    send_key 'ret';
    send_key 'alt-n'; #Next
    assert_screen "yast2-iscsi-client-target-connected";
    send_key 'alt-o'; #Ok
    script_run "echo \"iscsi_luns=`ls -1 /dev/disk/by-path/ip-*-lun-* | wc -l`\" > /dev/$serialdev";
    die "iscsi_client failed" unless wait_serial "iscsi_luns=3", 60;
}

sub test_flags {
    return { milestone => 1, fatal => 1, important => 1 };
}

1;
