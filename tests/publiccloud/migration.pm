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
use version_utils 'is_sle';
use publiccloud::ssh_interactive "select_host_console";
use publiccloud::utils qw(is_ec2 is_gce is_azure registercloudguest register_addons_in_pc);


sub run {
    my ($self, $args) = @_;

    select_host_console();
    my $instance = $args->{my_instance};

    print_os_version($instance);
    if (is_sle('=12-SP5')) {
        # https://bugzilla.suse.com/show_bug.cgi?id=1230009
        # aws-cli and azure-cli break the migration. This is known issue.
        $instance->ssh_script_run("sudo zypper -n rm aws-cli", timeout => 900) if (is_ec2());
        $instance->ssh_script_run("sudo zypper -n rm azure-cli python3-azure-devops python3-azure-nspkg", timeout => 900) if (is_azure());

        # LTSS should be disabled before the migration
        $instance->ssh_assert_script_run("sudo SUSEConnect -d -p SLES-LTSS/12.5/x86_64", timeout => 180);

        $instance->ssh_assert_script_run("sudo zypper -n ar -Gef -p90 " . get_required_var("PUBLIC_CLOUD_DMS_REPO") . "SLE_12_SP5 Migration");
        $instance->ssh_script_run("sudo zypper -n ref", timeout => 1800) if (is_ec2());
        $instance->ssh_assert_script_run("sudo zypper -n in suse-migration-sle15-activation", timeout => 1800);
        $instance->ssh_assert_script_run("sudo zypper -n rr Migration", timeout => 900);
        $instance->ssh_assert_script_run("sudo zypper refresh-services --force", timeout => 180);

        # Reboot to run the migration
        $instance->softreboot(timeout => 3600);
        validate_version($instance);

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

        $instance->ssh_assert_script_run("sudo zypper -n ar -Gef -p90 " . get_required_var("PUBLIC_CLOUD_DMS_REPO") . "SLE_15_SP7 Migration");
        $instance->ssh_script_run("sudo zypper -n ref", timeout => 1800) if (is_ec2());
        $instance->ssh_assert_script_run("sudo zypper -n in suse-migration-sle16-activation", timeout => 1800);
        $instance->ssh_assert_script_run("sudo zypper -n rr Migration", timeout => 900);
        $instance->ssh_assert_script_run("sudo zypper refresh-services --force", timeout => 180);

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
    my $version = get_var('VERSION');
    my $sourced_version = $instance->ssh_script_output('source /etc/os-release && echo $VERSION');
    if ($version ne $sourced_version) {
        record_info("OS-Version", "Current: $sourced_version\nOriginal SUT: $version");
        set_var('VERSION', $sourced_version);
        return 1;
    }
    die("OS-Version ($version) didn't update after the migration");
}

sub cleanup {
    my ($self) = @_;
    unless ($self->{run_args} && $self->{run_args}->{my_instance}) {
        die('cleanup: Either $self->{run_args} or $self->{run_args}->{my_instance} is not available. Maybe the test died before the instance has been created?');
    }
    $self->{run_args}->{my_instance}->upload_log("/var/log/migration_startup.log") if ($self->{run_args}->{my_instance}->ssh_script_run("test -f /var/log/migration_startup.log") == 0);
    $self->{run_args}->{my_instance}->upload_log("/var/log/distro_migration.log") if ($self->{run_args}->{my_instance}->ssh_script_run("test -f /var/log/distro_migration.log") == 0);

    return 1;
}

1;
