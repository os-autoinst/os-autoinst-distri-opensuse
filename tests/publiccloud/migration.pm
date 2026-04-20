# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Migration test from SLE12 SP5 to SLE15 SP7 and to SLE16.
# The migration is currently performed in the offline grub (loopback) mode.
# See https://github.com/SUSE/suse-migration-services for more information.
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use Time::Piece;
use version_utils 'is_sle';
use publiccloud::ssh_interactive "select_host_console";
use publiccloud::utils qw(is_ec2 is_gce is_azure registercloudguest);


sub run {
    my ($self, $args) = @_;

    select_host_console();
    my $instance = $args->{my_instance};

    $instance->ssh_script_run("sudo ls -lah /etc/zypp/repos.d/");

    print_os_version($instance);
    if (is_sle('=12-SP5')) {
        # https://bugzilla.suse.com/show_bug.cgi?id=1230009
        # aws-cli and azure-cli break the migration. This is known issue.
        $instance->ssh_script_run("sudo zypper -n rm aws-cli", timeout => 900) if (is_ec2());
        $instance->ssh_script_run("sudo zypper -n rm azure-cli python3-azure-devops python3-azure-nspkg", timeout => 900) if (is_azure());

        # LTSS should be disabled before the migration
        $instance->ssh_assert_script_run("sudo SUSEConnect -d -p SLES-LTSS/12.5/x86_64", timeout => 180);

        $instance->ssh_assert_script_run("sudo zypper -n -p 110 ar -Gef " . get_required_var("PUBLIC_CLOUD_DMS_REPO") . "SLE_12_SP5 Migration");
        $instance->ssh_script_run("sudo zypper -n ref", timeout => 1800) if (is_ec2());
        $instance->ssh_assert_script_run("sudo zypper -n in SLES15-Migration suse-migration-sle15-activation", timeout => 2400);
        $instance->ssh_assert_script_run("sudo zypper -n rr Migration", timeout => 900);
        $instance->ssh_assert_script_run("sudo zypper refresh-services --force", timeout => 180);

        # Disable maintenance updates for the migration as directory is not available during it
        $instance->ssh_script_run("sudo sudo sed -i 's/^enabled=1/enabled=0/' /etc/zypp/repos.d/SUSE_Maintenance_*");

        # Reboot to run the migration
        $instance->softreboot(timeout => 3600);
        validate_version($instance);

        # Re-enable maintenance updates for the migration
        $instance->ssh_script_run("sudo sudo sed -i 's/^enabled=0/enabled=1/' /etc/zypp/repos.d/SUSE_Maintenance_*");

        # Try to install aws-cli and azure-cli as they were removed for the migration
        $instance->ssh_script_run("sudo zypper -n ref", timeout => 1800) if (is_ec2());
        $instance->ssh_assert_script_run("sudo zypper -n in aws-cli", timeout => 1800) if (is_ec2());
        $instance->ssh_assert_script_run("sudo zypper -n in azure-cli", timeout => 1800) if (is_azure());
    }

    if (is_sle('=15-SP7')) {
        # https://bugzilla.suse.com/show_bug.cgi?id=1258138
        # https://github.com/SUSE/suse-migration-services/pull/458
        # Wicked to NetworkManager migration doesn't work. This is known.
        if (is_gce()) {
            $instance->ssh_assert_script_run(qq(echo -e "network:\\n    wicked2nm-continue-migration: true\\n" | sudo tee -a /etc/sle-migration-service.yml));
        }

        $instance->ssh_assert_script_run("sudo zypper -n -p 110 ar -Gef " . get_required_var("PUBLIC_CLOUD_DMS_REPO") . "SLE_15_SP7 Migration");
        $instance->ssh_script_run("sudo zypper -n ref", timeout => 1800) if (is_ec2());
        $instance->ssh_assert_script_run("sudo zypper -n in SLES16-Migration suse-migration-sle16-activation", timeout => 2400);
        $instance->ssh_assert_script_run("sudo zypper -n rr Migration", timeout => 900);
        $instance->ssh_assert_script_run("sudo zypper refresh-services --force", timeout => 180);

        # Disable maintenance updates for the migration as directory is not available during it
        $instance->ssh_script_run("sudo sudo sed -i 's/^enabled=1/enabled=0/' /etc/zypp/repos.d/SUSE_Maintenance_*");

        my $arch = get_required_var('ARCH');
        $instance->ssh_script_run("echo 'migration_product: SLES/16.0/$arch\\n' | sudo tee -a /etc/sle-migration-service.yml");
        $instance->ssh_script_run("cat /etc/sle-migration-service.yml");

        # Reboot to run the migration
        $instance->softreboot(timeout => 3600);
        validate_version($instance);
    }
}

sub print_os_version {
    my $instance = shift;
    my $os_release = $instance->ssh_script_output("cat /etc/os-release", proceed_on_failure => 1);
    my $zypper_lr = $instance->ssh_script_output("sudo zypper -n lr", proceed_on_failure => 1);
    record_info('VER CHCK', "# ssh sut cat /etc/os-release:\n" . $os_release . "\n\n# ssh sut sudo zypper -n lr:\n" . $zypper_lr);
}

sub validate_version {
    my $instance = shift;
    print_os_version($instance);
    my $version = get_required_var('VERSION');
    my $sourced_version = $instance->ssh_script_output('source /etc/os-release && echo $VERSION');

    fix_sftp_subsystem($instance);

    my $now = Time::Piece::localtime->strftime('%H%M%S');
    $instance->upload_log("/var/log/migration_startup.log", log_name => "migration_startup_${sourced_version}_$now.txt", failok => 1) if ($instance->ssh_script_run("test -f /var/log/migration_startup.log") == 0);
    $instance->upload_log("/var/log/distro_migration.log", log_name => "distro_migration_${sourced_version}_$now.txt", failok => 1) if ($instance->ssh_script_run("test -f /var/log/distro_migration.log") == 0);

    if ($version ne $sourced_version) {
        record_info("OS-Version", "Current: $sourced_version\nOriginal SUT: $version");
        set_var('VERSION', $sourced_version);
        return 1;
    }
    die("OS-Version ($version) didn't update after the migration");
}

sub fix_sftp_subsystem {
    my $instance = shift;

    my $sftp_path;
    if ($instance->ssh_script_run('sudo test -f /usr/lib/ssh/sftp-server') == 0) {
        $sftp_path = '/usr/lib/ssh/sftp-server';
    } elsif ($instance->ssh_script_run('sudo test -f /usr/libexec/ssh/sftp-server') == 0) {
        $sftp_path = '/usr/libexec/ssh/sftp-server';
    } else {
        die('The sftp-server location is not known.');
    }
    record_info('SFTP', "The sftp-server is in $sftp_path");

    if ($instance->ssh_script_run("sudo sshd -T | grep $sftp_path") != 0) {
        record_soft_failure('bsc#1261036 - sshd sftp misconfiguration in sles16.0 migrated from sles15-sp7');
        $instance->ssh_script_run('sudo sed -i "/sftp-server/d" /etc/ssh/sshd_config');
        $instance->ssh_script_run("echo 'subsystem sftp $sftp_path' | sudo tee /etc/ssh/sshd_config.d/60-sftp.conf", timeout => 600);
        if ($instance->ssh_script_run('sudo test -f /etc/ssh/sshd_config') == 0) {
            $instance->ssh_script_run('sudo mkdir -p /etc/ssh/sshd_config.d');
            $instance->ssh_script_run("echo 'Include /etc/ssh/sshd_config.d/*.conf' | sudo tee -a /etc/ssh/sshd_config");
        }
        $instance->ssh_script_run("sudo systemctl restart sshd", timeout => 600);
        script_run('ssh -O exit ' . $instance->username . '@' . $instance->public_ip);
        record_info('SSHD SFTP', $instance->ssh_script_output('sudo sshd -T | grep sftp'));
    } else {
        record_info('SSHD SFTP', $instance->ssh_script_output('sudo sshd -T | grep sftp'));
    }
}

1;
