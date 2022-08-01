# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-Later
#
# Summary: Test vsftpd with ssl enabled
# Maintainer: shawnhao <weixuan.hao@suse.com>
# Tags: poo#108614, tc#1769978

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $vsftpd_path = '/etc/vsftpd';
    my $key_file = '/etc/vsftpd/vsftpd.key';
    my $cert_file = '/etc/vsftpd/vsftpd.cert';
    my $pem_file = '/etc/vsftpd/vsftpd.pem';
    my $vsftpd_conf = 'vsftpd.conf';
    my $ftp_users_path = '/srv/ftp/users';
    my $ftp_served_dir = 'served';
    my $ftp_received_dir = 'received';
    my $user = 'ftpuser';
    my $pwd = 'susetesting';

    select_console 'root-console';

    # Install vsftpd, expect for Tumbleweed
    zypper_call('in vsftpd expect openssl');

    # Create self-signed certificate
    assert_script_run("mkdir $vsftpd_path && cd $vsftpd_path");
    assert_script_run "expect -c 'spawn openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $key_file -out $cert_file;
expect \"Country Name (2 letter code) \\[AU\\]\"; send \"DE\\r\";
expect \"State or Province Name (full name) \\[Some-State\\]:\"; send \"Nuremberg\\r\";
expect \"Locality Name (eg, city) \\[\\]:\"; send \"Nuremberg\\r\";
expect \"Organization Name (eg, company) \\[Internet Widgits Pty Ltd\\]:\"; send \"SUSE\\r\";
expect \"Organizational Unit Name (eg, section) \\[\\]:\"; send \"QA\\r\";
expect \"Common Name (e.g. server FQDN or YOUR name) \\[\\]:\"; send \"QE Security\\r\";
expect \"Email Address \\[\\]:\"; send \"empty\@suse.com\\r\";
expect {
    \"error\" {
      exit 139
   }
   eof {
       exit 0
   }
}'";
    assert_script_run("cat $key_file $cert_file > $pem_file");

    # Edit vsftpd.conf to enable and force the use of ssl
    assert_script_run("wget --quiet " . data_url("vsftpd/vsftpd.conf") . " -O /etc/vsftpd.conf");

    # Start vsftpd service and check status
    systemctl('start vsftpd');
    validate_script_output('systemctl is-active vsftpd', sub { m/active/ });

    # Create ftp user for later usage
    assert_script_run("mkdir -p $ftp_users_path");
    assert_script_run("useradd -d $ftp_users_path/$user -s /bin/bash $user");
    assert_script_run("echo $user:$pwd | chpasswd");

    # Grant root ownership, create a separate directory for uploading and give it to ftpuser
    assert_script_run("mkdir -p $ftp_users_path/$user/$ftp_served_dir $ftp_users_path/$user/$ftp_received_dir");
    assert_script_run("chown -R $user:users $ftp_users_path/$user");

    # Default permission is 620 and new user is unable to execute command, changed to 666 since ftpuser needs access to ttyS0
    assert_script_run("chmod 666 /dev/$serialdev");

    # Create a file
    assert_script_run("echo 'SUSE Testing' > $ftp_users_path/$user/$ftp_served_dir/f1.txt");
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
