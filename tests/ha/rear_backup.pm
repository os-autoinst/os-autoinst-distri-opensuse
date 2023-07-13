# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-rear rear23a
# Summary: Install ReaR packages and create a ReaR backup on an NFS server
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base 'rear';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(file_content_replace quit_packagekit zypper_call);

sub run {
    my ($self) = @_;
    my $hostname = get_var('HOSTNAME', 'susetest');
    my $arch = get_required_var('ARCH');
    my $backup_url = get_required_var('BACKUP_URL');
    my $timeout = bmwqemu::scale_timeout(600);

    # Disable packagekit and install ReaR
    get_var('USE_YAST_REAR') ? select_console 'root-console' : select_serial_terminal;
    quit_packagekit;
    zypper_call 'in yast2-rear';

    # Configure ReaR by using YaST module
    if (get_var('USE_YAST_REAR')) {
        my $backup_options = get_var('BACKUP_OPTIONS', 'nolock');
        script_run("yast2 rear; echo yast2-rear-status-\$? > /dev/$serialdev", 0);
        assert_screen('yast-rear-modify-config');
        send_key('alt-o');    # Validate the default configuration
        assert_screen('yast-rear-initial-config');
        send_key('alt-l');    # Set location
        type_string($backup_url);
        send_key('alt-p');    # Modify backup options
        send_key_until_needlematch('yast-rear-backup-options-empty', 'backspace');
        type_string($backup_options);
        send_key('alt-s');    # Save configuration and run ReaR backup
        assert_screen('yast-rear-backup-finished', $timeout);
        send_key('alt-l');    # Close the status window
        send_key('alt-o');    # Exit YaST
        wait_serial('yast2-rear-status-0') || die "'yast2 rear' didn't finish";
    } else {
        my $local_conf = '/etc/rear/local.conf';
        assert_script_run("curl -f -v " . data_url('ha/rear_local.conf') . " -o $local_conf");
        file_content_replace("$local_conf", q(%BACKUP_URL%) => $backup_url);
        my $backup_rc = script_run('rear -d -D mkbackup', timeout => $timeout);
        die 'Unexpected error in mkbackup command' unless defined $backup_rc;
        unless ($backup_rc == 0) {
            # Check for bsc#1180946
            my $var_rc = script_run("grep 'MODULES[[:blank:]]*=' $local_conf");
            die 'Unexpected error in grep command' unless defined $var_rc;
            unless ($var_rc == 0) {
                record_soft_failure('bsc#1180946 - [Build 124.5] openQA test fails in rear_backup with "ERROR: unix exists but no module file?"');
                assert_script_run("echo \"MODULES=( 'all_modules' )\" >> $local_conf");
            }
            # Retry the mkbackup command
            assert_script_run('rear -d -D mkbackup', timeout => $timeout);
        }
    }

    # Upload the logs
    $self->upload_rear_logs;

    # Upload ISO image (as a public image)
    my $iso_image = "/var/lib/rear/output/rear-${hostname}";
    assert_script_run("mv ${iso_image}.iso ${iso_image}-${arch}.iso");
    upload_asset("${iso_image}-${arch}.iso", 1);
}

1;
