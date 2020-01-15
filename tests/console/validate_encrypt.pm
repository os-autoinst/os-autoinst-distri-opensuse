# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validation module to check encrypted volumes.
# Scenarios covered:
# - Verify existence and content of '/etc/crypttab';
# - Verify crypted volumes are active;
# - Verify storing and restoring for binary backups of LUKS header and keyslot areas.
#
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use Test::Assert ':all';
use scheduler 'get_test_suite_data';
use Data::Dumper;
use Utils::Backends 'is_pvm';

# Check https://www.freedesktop.org/software/systemd/man/crypttab.html for more info about parsing
sub parse_crypttab {
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
    my $dev    = shift;
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

sub verify_crypttab {
    my (%args) = @_;
    record_info("crypttab", "Verify file existence and number of devices encrypted");
    assert_script_run("test -f /etc/crypttab", fail_message => "No /etc/crypttab found");
    assert_equals($args{num_devices}, scalar keys %{$args{crypttab}},
        "/etc/crypttab contains different number of encrypted devices than expected:\n" .
          Dumper($args{crypttab}));
}

sub verify_cryptsetup_status {
    my (%args) = @_;
    record_info("active volumes", "Verify crypted volumes are active");
    foreach my $dev (sort keys %{$args{crypttab}}) {
        my $status = parse_cryptsetup_status($dev);
        assert_matches(qr/$args{status}->{message}/, $status->{message},
            "Message of cryptsetup status does not match regex for device $dev");
        foreach my $property (sort keys %{$args{status}->{properties}}) {
            assert_equals($args{status}->{properties}->{$property},
                $status->{properties}->{$property},
                "Property of cryptsetup status does not match for device $dev");
        }
    }
}

sub verify_cryptsetup_luks {
    my (%args) = @_;
    record_info("LUKS", "Verify LUKS");
    foreach my $dev (sort keys %{$args{crypttab}}) {
        my $mapped_dev  = $args{crypttab}->{$dev}->{encrypted_device};
        my $backup_path = $args{luks}->{backup_base_path} . '_' . $dev;
        assert_script_run("cryptsetup -v isLuks $mapped_dev");
        assert_script_run("cryptsetup -v luksUUID $mapped_dev");
        assert_script_run("cryptsetup -v luksDump $mapped_dev");
        assert_script_run("cryptsetup -v luksHeaderBackup $mapped_dev" .
              " --header-backup-file $backup_path");
        validate_script_output("file $backup_path", sub { m/$args{luks}->{backup_file_info}/ });
        assert_script_run("cryptsetup -v --batch-mode luksHeaderRestore $mapped_dev" .
              " --header-backup-file $backup_path");
    }
}

sub run {
    select_console 'root-console' unless is_pvm;
    my $test_data = get_test_suite_data();
    my $crypttab  = parse_crypttab();
    verify_crypttab(num_devices => $test_data->{crypttab}->{num_devices_encrypted},
        crypttab => $crypttab);
    verify_cryptsetup_status(status => $test_data->{cryptsetup}->{device_status},
        crypttab => $crypttab);
    verify_cryptsetup_luks(luks => $test_data->{luks}, crypttab => $crypttab);
}

1;
