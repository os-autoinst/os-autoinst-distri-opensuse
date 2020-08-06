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
);

# Check https://www.freedesktop.org/software/systemd/man/crypttab.html for more info about parsing
sub parse_devices_in_crypttab {
    my @lines    = split(/\n/, script_output("cat /etc/crypttab"));
    my $crypttab = {};
    foreach (@lines) {
        next if /^\s*#.*$/;
        if ($_ =~ /(?<name>.+?)\s+(?<encrypted_device>.+?)($|\s+(?<password>.*?)($|\s+(?<options>.*)))/) {
            $crypttab->{$+{name}} = {
                encrypted_device => $+{encrypted_device},
                password         => $+{password},
                options          => $+{options}};
        }
    }
    return $crypttab;
}

sub parse_cryptsetup_status {
    my ($dev)  = @_;
    my @lines  = split(/\n/, script_output("cryptsetup status $dev"));
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

sub verify_crypttab_file_existence {
    record_info("crypttab file", "Verify the existence of /etc/crypttab file");
    assert_script_run("test -f /etc/crypttab", fail_message => "No /etc/crypttab found");
}

sub verify_number_of_encrypted_devices {
    my ($expected_number, $actual_number) = @_;
    record_info("devices number", "Verify number of encrypted devices");
    assert_equals($expected_number, $actual_number,
        "/etc/crypttab contains different number of encrypted devices than expected:\n" .
          Dumper($actual_number));
}

sub verify_cryptsetup_message {
    my ($expected_message, $actual_message) = @_;
    record_info("active volumes", "Verify crypted volume is active");
    assert_matches(qr/$expected_message/, $actual_message,
        "Message of cryptsetup status does not match regex");
}

sub verify_cryptsetup_properties {
    my ($expected_properties, $actual_properties) = @_;
    record_info("params", "Verify parameters, that are set for crypted volumes");
    foreach my $property (sort keys %{$expected_properties}) {
        diag("Verifying that expected property $expected_properties->{$property} corresponds to the actual $actual_properties->{$property}");
        assert_equals($expected_properties->{$property}, $actual_properties->{$property},
            "Property of cryptsetup status does not match");
    }
}

sub verify_restoring_luks_backups {
    my (%args)           = @_;
    my $mapped_dev       = $args{encrypted_device};
    my $backup_file_info = $args{backup_file_info};
    my $backup_path      = "/root/$mapped_dev";
    record_info("LUKS", "Verify storing and restoring for binary backups of LUKS header and keyslot areas.");
    assert_script_run("cryptsetup -v isLuks $mapped_dev");
    assert_script_run("cryptsetup -v luksUUID $mapped_dev");
    assert_script_run("cryptsetup -v luksDump $mapped_dev");
    assert_script_run("cryptsetup -v luksHeaderBackup $mapped_dev" .
          " --header-backup-file $backup_path");
    validate_script_output("file $backup_path", sub { m/$backup_file_info/ });
    assert_script_run("cryptsetup -v --batch-mode luksHeaderRestore $mapped_dev" .
          " --header-backup-file $backup_path");
}

1;
