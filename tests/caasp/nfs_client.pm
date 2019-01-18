# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic check for NFSv3/v4 client in CaaSP using NFS_SHARE=nfs://server.somewhere/some/path
# Maintainer: Tomas Hehejik <thehejik@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;

sub chkdir_strip {
    my ($nfs_share_dir) = @_;
    my $script = "";

    $script
      .= "[ \"\$(ls -w1 -A $nfs_share_dir 2> /dev/null | wc -l)\" -gt 0 ] && { echo \"OK, dir $nfs_share_dir not empty\"; true; } || { echo \"FAIL, $nfs_share_dir empty or does not exist\"; false; }\n";

    return $script;
}

sub run {
    my $nfs_uri = get_var('NFS_SHARE');

    # format $nfs_uri for mount command similarly to function bootmenu_network_setup() in bootloader_setup.pm
    $nfs_uri =~ /^nfs:\/\/([\w.-]+)(\/.+)$/;
    my ($nfs_server, $nfs_path) = ($1, $2);
    my $nfs_remotetarget = $nfs_server . ":" . $nfs_path;

    my @nfs_versions = qw(nfs nfs4);

    # Basic remote NFS server checks
    my $script = "";
    $script .= "echo -n \$(rpcinfo -s $nfs_server) | egrep 'nfs.*mountd|mountd.*nfs'\n";
    $script .= "echo -n \$(rpcinfo -u $nfs_server nfs) | egrep 'version 3.*version 4|version 4.*version 3'\n";
    $script .= "echo -n \$(rpcinfo -t $nfs_server nfs) | egrep 'version 3.*version 4|version 4.*version 3'\n";
    $script .= "showmount -e $nfs_server\n";

    print "$script\n";
    script_output($script, 60);

    # TODO as we don't know used NFS_SHARE value we should find some file from the share automatically and copy it to /tmp
    # for eg. by # find /tmp/nfs -type f -size +1M -size -10M -print -quit 2> /dev/null (print path of file >1MB and <10MB and quit)
    # NFSv4 uses different remotetarget with stripped path taken from showmount -e $nfs_server export

    # Autofs NFS test
    foreach my $a (@nfs_versions) {
        my $script = "";
        $script .= "mkdir -p /tmp/$a\n";
        if ($a eq "nfs") {
            $script .= "echo -e \"share\\t$nfs_remotetarget\" > /etc/auto.nfs\n";
        }
        elsif ($a eq "nfs4") {
            $script .= "echo -e \"share\\t-fstype=nfs4\\t$nfs_server:/\" > /etc/auto.nfs\n";
        }
        $script .= "echo -e \"/tmp/$a\\t/etc/auto.nfs\\t--timeout=10\" >> /etc/auto.master\n";
        $script .= "systemctl start autofs\n";
        $script .= chkdir_strip("/tmp/$a/share/");

        # autofs mount should be unmounted after 10 sec automatically
        $script .= "sleep 15\n";
        $script .= "[ \"\$(mount -t $a | wc -l)\" -eq 0 ]\n";
        $script .= "systemctl stop autofs\n";

        # Cleanup
        $script .= "rm /var/lib/overlay/etc/auto.master\n";
        $script .= "rm /var/lib/overlay/etc/auto.nfs\n";
        $script .= "mount -o remount /etc\n";
        $script .= "rm -r /tmp/$a\n";

        print "$script\n";
        script_output($script, 60);
    }

    # Mount command NFS test
    foreach my $a (@nfs_versions) {
        my $script = "";
        $script .= "mkdir -p /tmp/$a\n";
        if ($a eq "nfs") {
            $script .= "mount -t $a $nfs_remotetarget /tmp/$a\n";
        }
        elsif ($a eq "nfs4") {
            $script .= "mount -t $a $nfs_server:/ /tmp/$a\n";
        }
        $script .= chkdir_strip("/tmp/$a");

        # mount should provide at least one line
        $script .= "[ \"\$(mount -t $a | wc -l)\" -gt 0 ]\n";

        # nfsstat has an issue bsc#1017909 - returns 1 all the time
        $script .= "nfsstat -m || true\n";

        # Cleanup
        $script .= "umount /tmp/$a\n";
        $script .= "rm -r /tmp/$a\n";

        print "$script\n";
        script_output($script, 60);
    }

    # Fstab entry NFS test
    foreach my $a (@nfs_versions) {
        my $script = "";
        $script .= "mkdir -p /tmp/$a\n";
        if ($a eq "nfs") {
            $script .= "echo -e \"$nfs_remotetarget\\t/tmp/$a\\t$a\" >> /etc/fstab\n";
        }
        if ($a eq "nfs4") {
            $script .= "echo -e \"$nfs_server:/\\t/tmp/$a\\t$a\" >> /etc/fstab\n";
        }
        $script .= "mount -a -t $a\n";
        $script .= chkdir_strip("/tmp/$a");
        $script .= "umount /tmp/$a\n";

        # Cleanup
        $script .= "rm /var/lib/overlay/etc/fstab\n";
        $script .= "mount -o remount /etc\n";
        $script .= "rm -r /tmp/$a\n";

        print "$script\n";
        script_output($script, 60);
    }
}

1;
