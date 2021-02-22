# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test distribution migration system in public cloud SUSE images
#
# Maintainer: Jesus Bermudez <jesus.bv@suse.com>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use Mojo::File 'path';
use Mojo::JSON;

our $custom                 = get_required_var('CUSTOM');
our $distro_name            = get_required_var('DISTRO_NAME');
our $custom_distro_name     = get_required_var('CUSTOM_DISTRO_NAME');
our $version                = get_required_var('CUSTOM_VERSION');
our $arch                   = get_required_var('ARCH');
our $do_not_migrate         = get_required_var('DO_NOT_MIGRATE');
our $default_target_version = get_required_var('DEFAULT_TARGET_VERSION');
our $default_origin_version = get_required_var('DEFAULT_ORIGIN_VERSION');

sub install_package {
    my ($self, %args) = @_;
    my $instance = $args{instance};

    record_info('INFO', 'Installing distribution migration packages');
    $instance->run_ssh_command(
        cmd      => 'sudo zypper in -y SLES15-Migration',
        no_quote => 0,
        timeout  => 30
    );
    $instance->run_ssh_command(
        cmd      => 'sudo zypper in -y suse-migration-sle15-activation',
        no_quote => 0,
        timeout  => 30
    );
}

sub target_version {
    my ($self, %args) = @_;
    my $instance       = $args{instance};
    my $custom_product = $distro_name . '/' . $version . '/' . $arch;
    record_info('INFO', 'Setting custom product to migrate');
    record_info('INFO', $custom_product);
    # tee works like > # tee -a works like >>
    $instance->run_ssh_command(cmd => 'echo "migration_product: \'' . $custom_product . '\'" | sudo tee -a /etc/sle-migration-service.yml > /dev/null', no_quote => 0);
    my $prod = $instance->run_ssh_command(cmd => 'cat /etc/sle-migration-service.yml', no_quote => 0);
    record_info('INFO', $prod);
    return ($do_not_migrate) ? ($default_origin_version) : $version;
}

sub default_migration {
    my ($self, %args) = @_;
    my $instance       = $args{instance};
    my $target_version = $default_target_version;
    sleep 90;    # wait for a bit for zypper to be available

    defined($self->install_package(instance => $instance));
    if ($custom) {
        $distro_name = $custom_distro_name;
        # user has custom target version for the migration
        $target_version = $self->target_version(instance => $instance);
    }

    # reboot to run migration
    record_info('INFO', 'Rebooting the instance');
    # my ($shutdown_time, $startup_time) = $instance->softreboot(timeout => 1000);
    my $migration_time = ($do_not_migrate) ? 0 : 400;
    my ($shutdown_time, $startup_time) = $instance->softreboot(migration => $migration_time);
    # migration is running and accessible via ssh with migration user

    # migration finished and instance rebooted
    record_info('INFO', 'Checking the migration succeed');
    my $prd_version = $instance->run_ssh_command(cmd => "cat /etc/os-release", no_quote => 0);
    record_info('INFO', $prd_version);
    my $get_version_id_cmd = "grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '\"'";
    my $migrated_version   = $instance->run_ssh_command(cmd => $get_version_id_cmd, no_quote => 0);

    my $get_version      = "grep '^VERSION_ID=' /etc/os-release";
    my $version_expected = $instance->run_ssh_command(cmd => $get_version_id_cmd, no_quote => 0);
    record_info('INFO', $version_expected);

    if ($migrated_version != $target_version) {
        my $message = "Wrong version: expected: " . $target_version . ", got " . $migrated_version;
        record_info('INFO', $message);
        $self->result('fail');
    }
    elsif ($migrated_version == $target_version) {
        $self->result('ok');
    }
}

sub run {
    # my ($self) = @_;
    my $self = shift;
    $self->select_serial_terminal;
    my $provider = $self->provider_factory();
    my $instance = $provider->create_instance();

    record_info('INFO', 'the distro name is ' . $distro_name);
    defined($self->default_migration(
            instance => $instance
    ));
}

1;
