use base "installbasetest";
use testapi;
use autotest;
use lockapi;

sub run() {
    if (get_var("HACLUSTERJOIN")) {
        mutex_lock "MUTEX_HA_" . get_var("CLUSTERNAME"); #create OCFS2
        type_string "crm configure primitive dlm ocf:pacemaker:controld op monitor interval=\"60\" timeout=\"60\"\n";
        type_string "crm configure primitive o2cb ocf:ocfs2:o2cb op monitor interval=\"60\" timeout=\"60\"\n";
        type_string "crm configure group base-group dlm o2cb\n";
        type_string "crm configure clone base-clone base-group meta interleave=\"true\"\n";
        script_run "echo \"dlm_controld=`ps -A | grep dlm_controld | wc -l`\" > /dev/$serialdev ", 60;
        die "DLM start failed" unless wait_serial "dlm_controld=1", 60;
        script_run "yes y | mkfs.ocfs2 /dev/disk/by-path/ip-*-lun-2 && echo mkfs.ocfs2=1 > /dev/$serialdev",  60;
        die "mkfs.ocfs2 failed" unless wait_serial "mkfs.ocfs2=1", 60;
        type_string "crm configure primitive ocfs2-1 ocf:heartbeat:Filesystem params device=\"`ls -1 /dev/disk/by-path/ip-*-lun-2`\" directory=\"/srv/ocfs2\" fstype=\"ocfs2\" options=\"acl\" op monitor interval=\"20\" timeout=\"40\"\n";
        script_run "EDITOR='sed -ie \"s/group base-group dlm o2cb/group base-group dlm o2cb ocfs2-1/\"' crm configure edit"; #no other simple way to edit CIB :(
        mutex_unlock "MUTEX_HA_" . get_var("CLUSTERNAME");
        mutex_lock "MUTEX_HA_" . get_var("CLUSTERNAME"); #check content
        script_run "cd /srv/ocfs2/; md5sum -c --quite sums; echo md5sum=\$? > /dev/$serialdev ", 120;
        die "MD5SUM mismatch in OCFS2" unless wait_serial "md5sum=0", 120;
        mutex_unlock "MUTEX_HA_" . get_var("CLUSTERNAME");
    }
    mutex_lock "MUTEX_HA_" . get_var("CLUSTERNAME"); #copy something
    script_run "cp -r /usr/bin/ /srv/ocfs2; cd /srv/ocfs2; find bin/ -type f -exec md5sum {} \\; > sums; echo ocfs2_copy=\$? > /dev/$serialdev", 120;
    die "OCFS2 copy content failed" unless wait_serial "ocfs2_copy=0", 120;
    mutex_unlock "MUTEX_HA_" . get_var("CLUSTERNAME");
}

sub test_flags {
    return { milestone => 1, fatal => 1, important => 1 };
}

1;
