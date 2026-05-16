# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Migration activation then reboot to perform migration.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use power_action_utils 'power_action';
use utils qw(zypper_call reconnect_mgmt_console upload_folders);
use Utils::Architectures 'is_s390x';
use registration;

sub run {
    my $self = shift;

    select_console('root-console');

    # Add repo for devel:DMS when using proxy
    if ((get_var('SCC_URL', "") =~ /proxy/)) {
        my $repo_server = "https://download.opensuse.org/repositories/devel:/DMS/";
        my $repo_url = $repo_server . "SLE_" . (get_var('VERSION_UPGRADE_FROM') =~ s/-/_/gr);
        zypper_call("ar --refresh -p 90 '$repo_url' Migration");
    }

    # install the migration image and active it
    my $migration_tool = is_s390x ? 'SLES16-Migration' : 'suse-migration-sle16-activation';
    zypper_call("--gpg-auto-import-keys -n in $migration_tool");

    # deactivate unwanted/unsupported extensions before doing migration
    if (get_var('SCC_SUBTRACTIONS')) {
        foreach my $addon (split(',', get_var('SCC_SUBTRACTIONS'))) {
            my $extension = get_addon_fullname($addon);
            # NVIDIA Compute is not versioned by SP
            remove_suseconnect_product($extension, (($addon eq 'nvidia') ? '15' : ()));
        }
    }

    # clean migration repo and configure SUSEConnect when using proxy
    if ((get_var('SCC_URL', "") =~ /proxy/)) {
        zypper_call("rr Migration");
        assert_script_run("echo 'url: " . get_var('SCC_URL') . "' > /etc/SUSEConnect");
    }

    # Add product increment repo
    if (my $repo_increment = get_var('INCREMENT_REPO')) {
        $repo_increment .= '/repo/' . (get_var('PRODUCT')) . '-' . (get_var('VERSION')) . '-' . (get_var('ARCH'));
        zypper_call("ar --refresh $repo_increment Increment_repo");
    }

    # upload logs to know system state before migration
    upload_logs("/boot/grub2/grub.cfg", failok => 1);
    upload_folders(folders => '/etc/zypp/repos.d/');

    if (is_s390x) {
        enter_cmd '/usr/sbin/run_migration';
        reset_consoles;
        reconnect_mgmt_console(timeout => 600);
    } else {
        # disable timeout for migration grub menu
        assert_script_run("test -f /etc/grub.d/99_migration", fail_message => 'Migration grub script not found, suse-migration-sle16-activation may not have been activated');
        assert_script_run("sed -i 's/set timeout=[0-9]*/set timeout=-1/' /etc/grub.d/99_migration");
        assert_script_run("grub2-mkconfig -o /boot/grub2/grub.cfg");
        # Verify migration entry was added
        assert_script_run("grep -i migration /boot/grub2/grub.cfg", fail_message => 'Migration entry not found in grub.cfg');
        # Workaround: remove iso-scan hook from migration initramfs to prevent it from
        # occupying NVMe root partition on bare metal (bsc#XXXXXXX)
        # dracut --rebuild is not usable here as migration initramfs lacks build-parameter.txt;
        # unpack/delete/repack is the only safe approach that preserves migration-specific content.
        my $migration_initrd = script_output('grep -i migration /boot/grub2/grub.cfg | grep initrd | head -1 | awk \'{print $2}\'', proceed_on_failure => 1);
        $migration_initrd =~ s/^\s+|\s+$//g if $migration_initrd;
        if ($migration_initrd && script_run("lsinitrd $migration_initrd | grep -q iso-scan") == 0) {
            assert_script_run("mkdir -p /tmp/mig-initrd && cd /tmp/mig-initrd && lsinitrd --unpack $migration_initrd", timeout => 120);
            script_run("rm -f /tmp/mig-initrd/usr/lib/dracut/hooks/initqueue/settled/*iso-scan* /tmp/mig-initrd/sbin/iso-scan");
            assert_script_run("cd /tmp/mig-initrd && find . | cpio -o -H newc | gzip > $migration_initrd && cd / && rm -rf /tmp/mig-initrd", timeout => 120);
            record_info('iso-scan excluded', "Removed iso-scan from migration initramfs: $migration_initrd");
        } else {
            record_info('iso-scan check', $migration_initrd ? "iso-scan not present in $migration_initrd" : 'Could not detect migration initrd path from grub.cfg');
        }
        # Log current system state before reboot
        record_info('Pre-migration', script_output('cat /etc/os-release', proceed_on_failure => 1));
        record_info('Grub cfg', script_output('grep -A2 -i migration /boot/grub2/grub.cfg', proceed_on_failure => 1));
        record_info('Rebooting', 'Rebooting into migration environment');
        power_action('reboot', textmode => 1, keepconsole => 1, first_reboot => 1);
        # IPMI KVM video is continuous; SOL needed for send_key after grub appears
        reset_consoles;
        select_console 'sol', await_console => 0;
        record_info('Waiting for grub', 'Waiting for migration grub menu (timeout: 360s)');
        assert_screen('grub-menu-migration', 360);
        save_screenshot;
        send_key 'ret';
        record_info('Migration started', 'Selected migration entry, waiting for migration to complete');
        assert_screen('migration-running', 360);
        save_screenshot;
        record_info('Migration running', 'Migration in progress, waiting for reboot (timeout: 1200s)');
        # Migration environment reboots the system when done; reconnect SOL for send_key
        reset_consoles;
        select_console 'sol', await_console => 0;
        assert_screen('grub2', 1200);
        save_screenshot;
        record_info('Migration done', 'Migration completed, system at grub2');
    }
}

sub post_fail_hook {
    save_screenshot;
    assert_screen('grub2', 300);
    send_key "ret";
    select_console 'root-console';
    upload_logs("/var/log/distro_migration.log", failok => 1);
    upload_logs("/var/log/migration.log", failok => 1);
    script_run('journalctl -b --no-pager -o short-precise | tail -200 > /tmp/journal_tail.log && '
             . 'journalctl -b -1 --no-pager -o short-precise | tail -200 >> /tmp/journal_tail.log');
    upload_logs("/tmp/journal_tail.log", failok => 1);
}

1;
