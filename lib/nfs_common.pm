package nfs_common;
use mmapi;
use testapi;
use strict;
use warnings;
use utils qw(systemctl file_content_replace clear_console zypper_call clear_console);
use Utils::Systemd 'disable_and_stop_service';
use mm_network;
use version_utils;
use Utils::Backends qw(is_pvm_hmc is_spvm);

our @ISA = qw(Exporter);
our @EXPORT = qw(server_configure_network try_nfsv2 prepare_exports yast_handle_firewall add_shares
  mount_export client_common_tests check_nfs_ready yast2_server_initial yast2_client_exit check_y2_nfs_func install_service config_service start_service check_service $rw $ro);

our $rw = '/srv/nfs';
our $ro = '/srv/ro';

sub server_configure_network {

    setup_static_mm_network('10.0.2.101/24');

    if (is_sle('15+') || is_opensuse) {
        record_info('bsc#1083486', 'No firewalld service for nfs-kernel-server');
        disable_and_stop_service('firewalld');
    }
}

sub try_nfsv2 {
    # Try that NFSv2 is disabled by default
    systemctl 'start nfs-server';

    # Make sure it exists and also print the content as info.
    assert_script_run 'cat /proc/fs/nfsd/versions', fail_message => 'NFS versions file must exist';

    # It's ok if it's not available in the kernel
    if (script_run("grep -q '[+-]2' /proc/fs/nfsd/versions") == 1) {
        record_info('Info', 'NFSv2 not available in the kernel');
        systemctl 'stop nfs-server';
        return;
    }

    # If available, make sure it's disabled by default
    assert_script_run "cat /proc/fs/nfsd/versions | grep '\\-2'";

    # Stop testing NFSv2 on tumbleweed, support is removed in nfs-utils
    if (is_sle('15+')) {
        file_content_replace("/etc/sysconfig/nfs", "MOUNTD_OPTIONS=.*" => "MOUNTD_OPTIONS=\"-V2\"", "NFSD_OPTIONS=.*" => "NFSD_OPTIONS=\"-V2\"");
        systemctl 'restart nfs-server';
        assert_script_run "cat /proc/fs/nfsd/versions | grep '+2'";

        # Disable NFSv2 again
        file_content_replace("/etc/sysconfig/nfs", "MOUNTD_OPTIONS=.*" => "MOUNTD_OPTIONS=\"\"", "NFSD_OPTIONS=.*" => "NFSD_OPTIONS=\"\"");
    }
    systemctl 'stop nfs-server';
}

sub prepare_exports {
    my ($rw, $ro) = @_;
    my $ne = "/srv/dir/";

    # Create a directory and place a test file in it
    assert_script_run "mkdir ${rw} && echo success > ${rw}/file.txt";

    # Create also hardlink, symlink and do bindmount
    assert_script_run "( mkdir ${ne} ${rw}/bindmounteddir && ln -s ${ne} ${rw}/symlinkeddir && mount --bind ${ne} ${rw}/bindmounteddir )";
    assert_script_run "( echo example > ${ne}/example && ln ${ne}/example ${rw}/hardlinkedfile & ln -s ${ne}example ${rw}/symlinkedfile )";
    assert_script_run "echo secret > ${rw}/secret.txt && chmod 740 ${rw}/secret.txt";

    # Create large file and count its md5sum
    assert_script_run "fallocate -l 1G ${rw}/random";
    assert_script_run "md5sum ${rw}/random | cut -d' ' -f1 > ${rw}/random.md5sum";

    # Create read only directory - this is different between v3 and v4
    assert_script_run "mkdir ${ro} && echo success > ${ro}/file.txt";
}

sub yast_handle_firewall {
    if (is_sle('<15')) {
        send_key 'alt-f';    # Open port in firewall
        assert_screen 'nfs-firewall-open';
    }
    else {
        save_screenshot;
    }
}

sub add_shares {
    my ($rw, $ro, $version) = @_;

    # Add rw share
    send_key 'alt-d';
    assert_screen 'nfs-new-share';
    type_string $rw;
    send_key 'alt-o';

    # Permissions dialog
    assert_screen 'nfs-share-host';
    send_key 'tab';
    # Change 'ro,root_squash' to 'rw,no_root_squash,...'
    # For nfs4 also add fsid=0
    send_key 'home';
    send_key 'delete';
    send_key 'delete';
    send_key 'delete';
    my $options = "rw," . ($version eq '4' ? "fsid=0," : '') . 'no_';
    type_string $options;
    send_key 'alt-o';

    # Saved
    assert_screen 'nfs-share-saved';

    # Add ro share
    send_key 'alt-d';
    assert_screen 'nfs-new-share';
    type_string $ro;
    send_key 'alt-o';

    # Permissions dialog
    assert_screen 'nfs-share-host';
    send_key 'alt-o';

    # Saved
    assert_screen 'nfs-share-saved';
}

sub mount_export {
    script_run 'mount|grep nfs';
    assert_script_run 'cat /etc/fstab | grep nfs';

    # script_run is using bash return logic not perl logic, 0 is true
    if ((script_run('grep "success" /tmp/nfs/client/file.txt', 90)) != 0) {
        record_soft_failure 'boo#1006815 nfs mount is not mounted';
        assert_script_run 'mount /tmp/nfs/client';
        assert_script_run 'grep "success" /tmp/nfs/client/file.txt';
    }
}

sub client_common_tests {
    # remove added nfs from /etc/fstab
    assert_script_run 'sed -i \'/nfs/d\' /etc/fstab';

    # compare saved and current fstab, should be same
    assert_script_run 'diff -b /etc/fstab fstab_before';

    # compare last line, should be not deleted
    assert_script_run 'diff -b <(tail -n1 /etc/fstab) <(tail -n1 fstab_before)';

    # Remote symlinked directory is visible, removable but not accessible
    assert_script_run "ls -la /tmp/nfs/client/symlinkeddir";
    assert_script_run "! ls -la /tmp/nfs/client/symlinkeddir/";
    assert_script_run "! touch /tmp/nfs/client/symlinkeddir/x";
    assert_script_run "rm /tmp/nfs/client/symlinkeddir";

    # Remote bind-mounted directory is visible, accessible but isn't removable
    assert_script_run "ls -la /tmp/nfs/client/bindmounteddir/";
    assert_script_run "touch /tmp/nfs/client/bindmounteddir/x";
    assert_script_run "! rm -rf /tmp/nfs/client/bindmounteddir";

    # Remote hardlinks is visible, accessible and removable
    assert_script_run "ls -la /tmp/nfs/client/hardlinkedfile";
    assert_script_run "cat /tmp/nfs/client/hardlinkedfile";
    assert_script_run "echo x > /tmp/nfs/client/hardlinkedfile";
    assert_script_run "rm /tmp/nfs/client/hardlinkedfile";

    # Remote symlink is visible but not readable, nor writable, nor removable
    assert_script_run "ls -la /tmp/nfs/client/symlinkedfile";
    assert_script_run "! cat /tmp/nfs/client/symlinkedfile";
    assert_script_run "! echo x > /tmp/nfs/client/symlinkedfile";
    assert_script_run "rm /tmp/nfs/client/symlinkedfile";

    # Copy large file from NFS and test it's checksum
    assert_script_run "time cp /tmp/nfs/client/random /var/tmp/", 300;
    assert_script_run "md5sum /var/tmp/random | cut -d' ' -f1 > /var/tmp/random.md5sum";
    assert_script_run "diff /tmp/nfs/client/random.md5sum /var/tmp/random.md5sum";
}

sub check_nfs_ready {
    my ($rw, $ro) = @_;

    assert_script_run "exportfs | grep '${rw}\\|${ro}'";
    assert_script_run "cat /etc/exports | tr -d ' \\t\\r' | grep '${rw}\\*(rw,\\|${ro}\\*(ro,'";
    assert_script_run "cat /proc/fs/nfsd/exports";

    if ((script_run('systemctl is-enabled nfs-server')) != 0) {
        record_info 'disabled', 'The nfs-server unit is disabled';
        systemctl 'enable nfs-server';
    }
    if ((script_run('systemctl is-active nfs-server')) != 0) {
        record_info 'stopped', 'The nfs-server unit is stopped';
        systemctl 'start nfs-server';
    }
}

sub yast2_server_initial {
    do {
        assert_screen([qw(nfs-server-not-installed nfs-firewall nfs-config)], 120);
        # install missing packages as proposed
        if (match_has_tag('nfs-server-not-installed') or match_has_tag('nfs-firewall')) {
            send_key 'alt-i';
        }
    } while (not match_has_tag('nfs-config'));
}

sub yast2_client_exit {
    my $module_name = shift;
    wait_screen_change { send_key 'alt-o' };
    my $expret = "0";
    if (check_screen("cannot-mount-nfs-from-fstab", 10)) {
        send_key 'alt-o';
        record_soft_failure 'bsc#1157892';
        $expret = "{0,16}";
    }
    wait_serial("$module_name-$expret") or die "'yast2 $module_name' didn't finish";
    clear_console;
}

sub install_service {
    # Make sure packages are installed
    zypper_call 'in yast2-nfs-server nfs-kernel-server', timeout => 480;
}

sub config_service {
    my ($rw, $ro) = @_;

    try_nfsv2();

    prepare_exports($rw, $ro);
    my $y2_opts = "";
    $y2_opts = "--ncurses" if (is_pvm_hmc() || is_spvm());
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'nfs-server', yast2_opts => $y2_opts);

    yast2_server_initial();

    # Start server
    send_key 'alt-s';

    # Disable NFSv4
    assert_screen([qw(nfsv4-disabled nfsv4-enabled)], 120);
    if (match_has_tag('nfsv4-enabled')) {
        send_key 'alt-v';
        wait_still_screen 1;
    }

    yast_handle_firewall();

    # Next step
    send_key 'alt-n';

    assert_screen 'nfs-overview';

    add_shares($rw, $ro);

    send_key 'alt-f';
    wait_serial("$module_name-0") or die "'yast2 $module_name' didn't finish";
}

sub start_service {
    my ($rw, $ro) = @_;
    # Back on the console
    clear_console;

    # Server is up and running, client can use it now!
    check_nfs_ready($rw, $ro);
}

sub stop_service {
    systemctl('stop nfs-server');
    systemctl('stop rpcbind');
    systemctl('stop rpcbind.socket');
}

sub check_service {
    my ($rw, $ro) = @_;

    assert_script_run "exportfs | grep '${rw}'";
    assert_script_run "exportfs | grep '${ro}'";
    assert_script_run "cat /etc/exports | tr -d ' \\t\\r' | grep '${rw}\\*(rw,\\|${ro}\\*(ro,'";
    assert_script_run "cat /proc/fs/nfsd/exports";
    assert_script_run('systemctl is-enabled nfs-server');
    assert_script_run('systemctl is-active nfs-server');
}

sub check_y2_nfs_func {
    my (%hash) = @_;
    my $stage = $hash{stage};
    if ($stage eq 'before') {
        install_service();
        config_service($rw, $ro);
        start_service($rw, $ro);
    }
    check_service($rw, $ro);
    stop_service();
    # we need to cleanup the nfs settings after service check was done.
    if ($stage eq 'after') {
        zypper_call 'rm yast2-nfs-server', timeout => 480;
        # remove added nfs entry from /etc/fstab and /etc/exports
        assert_script_run 'sed -i \'/srv/d\' /etc/fstab';
        assert_script_run 'sed -i \'/srv/d\' /etc/exports';
        script_run 'rm -fr /srv/*';
        script_run 'rm -fr /tmp/nfs';
        # we need to restart rpcbind and rpcbind.socket for rpcbind test
        systemctl('restart nfs-server');
        systemctl('is-active nfs-server');
        systemctl('restart rpcbind');
        systemctl('is-active rpcbind');
        systemctl('restart rpcbind.socket', timeout => 120);
        systemctl('is-active rpcbind.socket');
    }
}

1;
