# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Start cryptctl server, encrypt partition
# Maintainer: Alexei Tighineanu <atighineanu@suse.de>

use base "sles4sap";
use testapi;
use strict;


sub run {
    my ($self) = @_;
    # List of solutions is different between saptune in x86_64 and in ppc64le
    # Will check whether test is running in ppc64le with the OFW variable
 
    select_console 'root-console';
 
    unless ( script_output "rpm -ql cryptctl" ) {
    	script_run "zypper -n in cryptctl";
    }

    my $timeout          = 7200;
    # precompile regexes
    my $access_password = qr/^Access password.*/m;
    my $confirm_passwd  = qr/^Confirm access password.*/m;
    my $pem             = qr/^PEM.*/m;
    my $hostname        = qr/^Host name.*/m;
    my $ipaddress       = qr/^IP address.*/m;
    my $tcp             = qr/^TCP.*/m;
    my $db              = qr/^Key database.*/m;
    my $client_cert     = qr/^Should clients.*/m;
    my $encryption_key  = qr/^Should encryption.*/m;
    my $smtp            = qr/^SMTP.*/m;
    my $question        = qr/^Would you.*/m;
    my $running         = qr/^Key server is now running.*/m;
    my $proc_cryptctl   = qr/.*\/usr\/sbin\/cryptctl.*/m; 
    my $hstname    	 = qr/.*host name.*/m;
    my $port_num        = qr/.*number \[3737.*/m;
    my $cert_keyserv    = qr/.*PEM-encoded CA certificate.*/m;
    my $certkey2	 = qr/.*PEM-encoded client certificate.*/m;
    my $clientkey	 = qr/.*PEM-encoded client key.*/m;
    my $serv_passwd     = qr/^Enter key server's.*/m;
    my $crypta		 = qr/^Path of dir.*/m;
    my $disk		 = qr/^Path of disk.*/;
    my $how_many	 = qr/^How many.*/m;
    my $ifthekey	 = qr/^If the key.*/m;
    my $doublecheck 	 = qr/^Please double check.*/m;

    #my $HOSTNAME 	 = script_ouptut ('ifconfig | grep \"inet addr\" | grep 10. | cut -d \"\:\" -f2 | cut -d \" \" -f1');
    my $HOSTNAME        = script_output ('ip a | grep "inet 10." | cut -d " " -f6 | cut -d "/" -f1');

    # Start cryptctl_server
    record_info("starting cryptctl init", ">>> cryptctl init-server");
    script_run("(cryptctl init-server) | tee /dev/$serialdev", 0);
    my $cryptctl_server_checks = [
        $access_password, $confirm_passwd, $pem, $hostname, $ipaddress, $tcp,
        $encryption_key,  $client_cert,    $db,  $question, $running,   $smtp
    ];
    my $out = wait_serial($cryptctl_server_checks, $timeout);
    while ($out) {
        if ($out =~ $access_password) {
            type_password "1234554321";
            send_key "ret";
        }
        elsif ($out =~ $confirm_passwd) {
            type_password "1234554321";
            send_key "ret";
        }
        elsif ($out =~ $pem) {
            send_key "ret";
        }
        elsif ($out =~ $hostname) {
            type_string $HOSTNAME ;
            send_key "ret";
        }
        elsif ($out =~ $ipaddress) {
            send_key "ret";
        }
        elsif ($out =~ $tcp) {
            type_string "3737";
            send_key "ret";
        }
        elsif ($out =~$db) {
            # change dir /var/lib/cryptctl/keydb into:
            type_string '/etc/cryptctl/servertls/';
            send_key "ret";
        }
        elsif ($out =~ $client_cert) {
            type_string 'no';
            send_key "ret";
        }
        elsif ($out =~ $encryption_key) {
            type_string 'no';
            send_key "ret";
        }
        elsif ($out =~ $smtp) {
            send_key "ret";
        }
        elsif ($out =~ $question) {
            type_string "yes";
            send_key "ret";
        }
        elsif ($out =~ $running) {
            record_info 'Running', 'Server is up and running';
            last;
        }
        $out = wait_serial($cryptctl_server_checks, $timeout);
    }
 
    script_run("ps -aux | grep cryptctl | tee /dev/$serialdev", 0);
    my $sysctl_running_check = [
        $proc_cryptctl
    ];

    my $out = wait_serial($sysctl_running_check, $timeout);
        if ($out =~ $proc_cryptctl) {
           record_info 'cryptctl-server Running', 'Daemon runs';
        }
    
    script_run("lsblk | tee /dev/$serialdev", 0);

    script_run("dd if=/dev/vda3 of=kukish.img bs=1024 count=300 | tee /dev/$serialdev", 0);

    script_run("losetup loop1 kukish.img | tee /dev/$serialdev", 0);
    script_run("losetup -l | tee /dev/$serialdev", 0);

    script_run("mkdir -p /root/crypta | tee /dev/$serialdev", 0);

    record_info("Encrypting bulk dev", ">>> cryptctl encrypt /dev/<blk>");
    script_run("(cryptctl encrypt /dev/loop1) | tee /dev/$serialdev", 0);
    my $encrypt_check = [
    	$hstname,  $port_num,  $cert_keyserv, $certkey2, $clientkey, $serv_passwd,  $crypta,
       $disk,  $how_many,  $ifthekey,  $doublecheck
    ];	
       
    my $out2 = wait_serial($encrypt_check, $timeout);
    while ($out2) {
        if ($out2 =~ $hstname) {
            type_string $HOSTNAME;
            send_key "ret";
        }
        elsif ($out2 =~ $port_num) {
            type_string "3737";
            send_key "ret";
        } 
  	elsif ($out2 =~ $cert_keyserv) {
            #type_string "/etc/cryptctl/servertls/";
            #type_string $HOSTNAME;
            #type_string ".crt";
            send_key "ret";
        }
        elsif ($out2 =~ $certkey2) {
            type_string "/etc/cryptctl/servertls/";
            type_string $HOSTNAME;
            type_string ".crt";
            send_key "ret";
        }
        elsif ($out2 =~ $clientkey) {
            type_string "/etc/cryptctl/servertls/";
            type_string $HOSTNAME;
            type_string ".key"; 
            send_key "ret";
        }
        elsif ($out2 =~ $serv_passwd) {
            type_password "1234554321";
            send_key "ret";
        }
        elsif ($out2 =~ $crypta) {
            type_string "/root/crypta";
            send_key "ret";
 	}
        elsif ($out2 =~ $disk) {
            type_string "/dev/loop1";
            send_key "ret";
        }
        elsif ($out2 =~ $how_many) {
            send_key "ret";
        }
        elsif ($out2 =~ $ifthekey) {
           send_key "ret";
        }
        elsif ($out2 =~ $doublecheck){
           type_string "yes";
           send_key "ret";
           last;
        }
   	$out2 = wait_serial($encrypt_check, $timeout);
   }
}
  
1;

