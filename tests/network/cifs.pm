# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: samba samba-client cifs-utils nmap coreutils util-linux
# Summary: Test samba client and CIFS mount
# * Test smbclient directory listing
# * Test mounting a CIFS filesystem (with different versions)
# * Test file access on the CIFS mount (put file, stat, rm file)
# * Test read-only access to CIFS mount
# * force a local samba server (on the test machine) with CIFS_TEST_REMOTE=local
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils;
use registration qw(add_suseconnect_product get_addon_fullname);

# SMB version for mount.cifs to test for
my @versions = qw(2.0 2.1 3 3.0 3.0.2 3.1.1);

sub setup_local_server() {
    # Setup a local samba server with "currywurst" and "filedrop" shares
    zypper_call('in samba');
    assert_script_run("useradd geekotest");
    assert_script_run("mkdir -p /srv/samba/{currywurst,filedrop}");
    assert_script_run('echo -e \'[currywurst]\npath = /srv/samba/currywurst\nread only = yes\nbrowseable = yes\nguest ok = yes\n\n\' >> /etc/samba/smb.conf');
    assert_script_run('echo -e \'[filedrop]\npath = /srv/samba/filedrop\nbrowseable = no\nwrite list = geekotest\ncreate mask = 0644\ndirectory mask = 0755\n\' >> /etc/samba/smb.conf');
    assert_script_run('curl ' . data_url('samba/Currywurst.txt') . ' -o /srv/samba/currywurst/Recipe.txt');
    assert_script_run("chown -R geekotest /srv/samba/{currywurst,filedrop}");
    assert_script_run("chmod -R 0755 /srv/samba/currywurst");
    assert_script_run("chmod -R 0750 /srv/samba/filedrop");
    systemctl("start smb");
    assert_script_run("systemctl status smb | grep 'active (running)'");
    assert_script_run('echo -ne \'nots3cr3t\nnots3cr3t\' | smbpasswd -a -s geekotest');
}

sub run {
    my $self       = shift;
    my $smb_domain = get_var("CIFS_TEST_DOMAIN") // "currywurst";
    my $smb_remote = get_var("CIFS_TEST_REMOTE") // "currywurst.qam.suse.de";
    $self->select_serial_terminal;
    add_suseconnect_product(get_addon_fullname('phub')) if is_sle;    # samba-client requires package hub
    my $ret = zypper_call 'in cifs-utils samba-client nmap';
    # Use local samba server, if defined or if defined SMB server is not accessible
    my $is_local = get_var("CIFS_TEST_REMOTE") eq 'local';
    if ($is_local || script_run("nmap -p 139,445 $smb_remote | grep open") != 0) {
        my $reason = $is_local ? "defined by CIFS_TEST_REMOTE" : "$smb_remote unreachable";
        record_info("local samba server", "Using a local samba server (defined by CIFS_TEST_REMOTE)");
        setup_local_server();
        $smb_remote = "127.0.0.1";
    }
    script_run("smbclient -m SMB2 -L $smb_domain -I $smb_remote -U guest -N");
    assert_script_run("smbclient -m SMB2 -L $smb_domain -I $smb_remote -U guest -N | grep 'Disk' | grep -i 'currywurst'");
    assert_script_run("smbclient -m SMB3 -L $smb_domain -I $smb_remote -U guest -N | grep 'Disk' | grep -i 'currywurst'");
    # Test CIFS mount
    assert_script_run("mkdir -p /mnt/{currywurst,filedrop}");
    my $options = "username=geekotest,password=nots3cr3t";
    # Test mount with the different version types
    if (is_sle(">12-SP3")) {
        foreach my $version (@versions) {
            assert_script_run("mount -t cifs -o $options,vers=$version //$smb_remote/currywurst /mnt/currywurst");
            assert_script_run("umount /mnt/currywurst");
        }
    } else {
        $options .= ",vers=2.1";    # needed for SLES12-SP3 and below
    }
    assert_script_run("mount -t cifs -o $options //$smb_remote/currywurst /mnt/currywurst");
    assert_script_run("mount -t cifs -o $options //$smb_remote/filedrop /mnt/filedrop");
    # Check if test files are there
    assert_script_run("stat /mnt/currywurst/Recipe.txt");
    my $filename = random_string(8);    # random filename to prevent race conditions on the server
    assert_script_run("cp /mnt/currywurst/Recipe.txt /mnt/filedrop/$filename");
    assert_script_run("umount /mnt/currywurst");
    assert_script_run("! stat /mnt/currywurst/Recipe.txt");
    assert_script_run("stat /mnt/filedrop/$filename");
    assert_script_run("md5sum /mnt/filedrop/$filename > Recipe.txt.md5sum");
    # Check if file are in the filedrop after a remount
    assert_script_run("umount /mnt/filedrop");
    assert_script_run("mount -t cifs -o $options,ro //$smb_remote/filedrop /mnt/filedrop");
    assert_script_run("stat /mnt/filedrop/$filename");
    assert_script_run("md5sum -c Recipe.txt.md5sum");
    assert_script_run("! rm /mnt/filedrop/$filename");
    assert_script_run("mount -t cifs -o $options,remount,rw /mnt/filedrop");
    assert_script_run("rm /mnt/filedrop/$filename");
}

sub cleanup() {
    script_run("umount /mnt/{currywurst,filedrop}");
    script_run("rmdir /mnt/{currywurst,filedrop}");
}

sub post_fail_hook {
    my $self = shift;
    cleanup();
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my $self = shift;
    cleanup();
    $self->SUPER::post_run_hook;
}

1;
