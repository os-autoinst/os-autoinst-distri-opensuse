use base "installbasetest";
use testapi;
use autotest;

sub run() {
    type_string "zypper -n in yast2-iscsi-client open-iscsi\n";
    sleep 120; # Give it some time to do the install
    type_string "echo '10.0.2.16    node1' >> /etc/hosts\n";
    type_string "echo '10.0.2.17    node2' >> /etc/hosts\n";
    type_string "echo '10.0.2.18    node3' >> /etc/hosts\n";
    #type_string "rm -f /var/lib/pacemaker/cib/*\n";  #might not be needed
    my $iscsiend = 10-$instance;
    type_string "echo 'InitiatorName=iqn.1996-04.de.suse:01:8f4aff8c87$iscsiend' > /etc/iscsi/initiatorname.iscsi\n";
    type_string "echo 'node$instance' > /etc/hostname\n";
    type_string "echo 'node$instance' > /etc/HOSTNAME\n";
    type_string "hostname node$instance\n";
    check_screen "node$instance-conf"; #should be assert
}

1;
