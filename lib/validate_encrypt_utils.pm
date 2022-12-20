# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: A set of tools to verify encryption.
#
# Maintainer: QA SLE YaST <qa-sle-yast@suse.de>

package validate_encrypt_utils;
use strict;
use warnings;
use testapi;
use Test::Assert ':all';
use Data::Dumper;
use base "Exporter";
use Exporter;

our @EXPORT = qw(
  parse_devices_in_crypttab
  parse_cryptsetup_status
  verify_crypttab_file_existence
  verify_number_of_encrypted_devices
  verify_cryptsetup_message
  verify_cryptsetup_properties
  verify_restoring_luks_backups
  verify_locked_encrypted_partition
  validate_encrypted_volume_activation
);

=head2 parse_devices_in_crypttab

  parse_devices_in_crypttab();

This sub reads the output of F</etc/crypttab> and returns C<%crypttab> reference with its data.
Check https://www.freedesktop.org/software/systemd/man/crypttab.html for more info about parsing 
=cut

sub parse_devices_in_crypttab {
    my @lines = split(/\n/, script_output("cat /etc/crypttab"));
    my $crypttab = {};
    foreach (@lines) {
        next if /^\s*#.*$/;
        if ($_ =~ /(?<name>.+?)\s+(?<encrypted_device>.+?)($|\s+(?<password>.*?)($|\s+(?<options>.*)))/) {
            $crypttab->{$+{name}} = {
                encrypted_device => $+{encrypted_device},
                password => $+{password},
                options => $+{options}};
        }
    }
    return $crypttab;
}

=head2 parse_cryptsetup_status

  parse_cryptsetup_status($dev);

=over

=item C<$dev>
  The encrypted device name

=back

returns the C<$status> of the encrypted device. If no encrypted device found it returns a reference to an empty anonymous hash.
=cut

sub parse_cryptsetup_status {
    my ($dev) = @_;
    my @lines = split(/\n/, script_output("cryptsetup status $dev", proceed_on_failure => 1));
    my $status = {};
    foreach (@lines) {
        if (!exists $status->{message} && $_ =~ /is (in)?active/) {
            $status->{message} = $_;
        }
        elsif ($_ =~ /\s+(?<param>.*):\s+(?<value>.*)$/) {
            my ($param, $value) = ($+{param}, $+{value});
            $param =~ s/ /_/g;
            $status->{properties}->{$param} = $value;
        }
    }
    return $status;
}

=head2 verify_crypttab_file_existence

  verify_crypttab_file_existence();

Verify the existence of F</etc/crypttab> file.
=cut

sub verify_crypttab_file_existence {
    record_info("crypttab file", "Verify the existence of /etc/crypttab file");
    assert_script_run("test -f /etc/crypttab", fail_message => "No /etc/crypttab found");
}

=head2 verify_number_of_encrypted_devices

  verify_number_of_encrypted_devices($expected_number, $actual_number);

=over

=item C<$expected_number>
  the int number of the expected encrypted devices

=item C<$actual_number>
  the int number of the actual encrypted devices

=back

=cut

sub verify_number_of_encrypted_devices {
    my ($expected_number, $actual_number) = @_;
    record_info("devices number", "Verify number of encrypted devices");
    assert_equals($expected_number, $actual_number,
        "/etc/crypttab contains different number of encrypted devices than expected:\n" .
          Dumper($actual_number));
}

=head2 verify_cryptsetup_message

  verify_cryptsetup_message($expected_message, $actual_message);

=over

=item C<$expected_message>
  A string with the expected status message of a device

=item C<$actual_message>
  A string with the actual status message of a device

=back

=cut

sub verify_cryptsetup_message {
    my ($expected_message, $actual_message) = @_;
    record_info("Assert volumes status", "Verify encrypted volume status based on test_data expectations");
    assert_matches(qr/$expected_message/, $actual_message,
        "Message of cryptsetup status does not match regex");
}

=head2 verify_cryptsetup_properties

  verify_cryptsetup_properties($expected_properties, $actual_properties);

=over

=item C<$expected_properties>
  A hash reference with the expected LUKS properties

=item C<$actual_properties>
  A hash reference with the actual LUKS properties

=back
=cut

sub verify_cryptsetup_properties {
    my ($expected_properties, $actual_properties) = @_;
    record_info("params", "Verify parameters, that are set for encrypted volumes");
    foreach my $property (sort keys %{$expected_properties}) {
        diag("Verifying that expected property $expected_properties->{$property} corresponds to the actual $actual_properties->{$property}");
        assert_equals($expected_properties->{$property}, $actual_properties->{$property},
            "Property of cryptsetup status does not match");
    }
}

=head2 verify_restoring_luks_backups

  verify_restoring_luks_backups(%args);

Where C<%args> expects the following parameters:

=over

=item C<$mapped_device>
  path of encrypted device

=item C<$backup_file_info>
  unique string to match with the info of the backup file

=item C<$backup_path>
  path to a binary file used for backup of the keys

=back

Validates that the device is an encrypted one and tests the backup of the keyslot info.
=cut

sub verify_restoring_luks_backups {
    my (%args) = @_;
    my $mapped_dev_path = $args{encrypted_device_path};
    my $backup_file_info = $args{backup_file_info};
    my $backup_path = $args{backup_path};
    record_info("LUKS", "Verify storing and restoring for binary backups of LUKS header and keyslot areas.");
    assert_script_run("cryptsetup -v isLuks $mapped_dev_path");
    assert_script_run("cryptsetup -v luksUUID $mapped_dev_path");
    assert_script_run("cryptsetup -v luksDump $mapped_dev_path");
    assert_script_run("cryptsetup -v luksHeaderBackup $mapped_dev_path" .
          " --header-backup-file $backup_path");
    validate_script_output("file $backup_path", sub { m/$backup_file_info/ });
    assert_script_run("cryptsetup -v --batch-mode luksHeaderRestore $mapped_dev_path" .
          " --header-backup-file $backup_path");
    assert_script_run("rm -rf $backup_path");
}

=head2 verify_locked_encrypted_partition

  verify_locked_encrypted_partition($enc_disk_part);

=over

=item C<$enc_disk_part>
  block device name of the encrypted disk partition, i.e.: sda1

=back

=cut

sub verify_locked_encrypted_partition {
    my $enc_disk_part = shift;
    my @lines = split(/\n/, script_output("lsblk -l -n /dev/$enc_disk_part"));
    if ((scalar @lines > 1) && (grep { /crypt/ } @lines)) {
        die "partition '/dev/$enc_disk_part' is already unlocked";
    }
    record_info('lock OK', "Encrypted partition '/dev/$enc_disk_part' still locked");
}

sub validate_encrypted_volume_activation {
    my ($args) = @_;
    select_console 'install-shell';
    my $status = parse_cryptsetup_status($args->{mapped_device});
    verify_cryptsetup_message($args->{message}, $status->{message});
    verify_cryptsetup_properties($args->{properties}, $status->{properties});
    select_console 'installation';
}

1;
