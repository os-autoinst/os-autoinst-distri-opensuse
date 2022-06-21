# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Package for cups service tests
#
# Maintainer: Jan Baier <jbaier@suse.cz>, Lemon Li <leli@suse.com>

package services::cups;
use base 'opensusebasetest';
use testapi;
use utils;
use strict;
use warnings;

my $service_type = 'Systemd';

sub install_service {
    zypper_call("in cups", exitcode => [0, 102, 103]);
}

sub config_service {
    my $conf = '/etc/cups/cups-files.conf';
    if ($service_type eq 'Systemd') {
        script_run "echo FileDevice Yes >> $conf";
        validate_script_output 'cupsd -t', sub { m/is OK/ };
    } else {
        $conf = '/etc/cups/cupsd.conf';
        # Allow new printers to be added using device URIs "file:/filename"
        script_run "echo FileDevice Yes >> $conf";
        assert_script_run 'cupsd';
    }

    record_info('cups-files', script_output("cat $conf"));
}

sub enable_service {
    common_service_action 'cups', $service_type, 'enable';
}

sub restart_service {
    common_service_action 'cups', $service_type, 'restart';
}

# check service is running and enabled
sub check_service {
    common_service_action 'cups', $service_type, 'is-enabled';
    common_service_action 'cups', $service_type, 'is-active';
}

# check cups function
sub check_function {
    # if we migrated from sle11sp4, we need to change the configure file.
    # bsc#1180148, cups configure file was not upgraded.
    if ((get_var('ORIGIN_SYSTEM_VERSION') eq '11-SP4') && ($service_type eq 'Systemd')) {
        script_run 'echo FileDevice Yes >> /etc/cups/cups-files.conf';
        validate_script_output 'cupsd -t', sub { m/is OK/ };
        common_service_action 'cups', $service_type, 'restart';
    }
    # Add printers
    record_info "lpadmin", "Try to add printers and enable them";
    validate_script_output('lpstat -p -d -o 2>&1 || test $? -eq 1', sub { m/lpstat: No destinations added/ }, timeout => 120);
    assert_script_run 'lpadmin -p printer_tmp -v file:/tmp/test_cups -m raw -E';
    assert_script_run 'lpadmin -p printer_null -v file:/dev/null -m raw -E';
    assert_script_run 'cupsenable printer_tmp printer_null';
    assert_script_run 'lpoptions -d printer_tmp';
    validate_script_output 'lpstat -p -d -o', sub { m/printer_tmp is idle/ };

    assert_script_run 'curl --fail -s -O -L ' . data_url('console/sample.ps');
    assert_script_run 'curl --fail -s -O -L ' . data_url('console/testpage.pdf');

    # Submit print job to the queue, list them and cancel them
    record_info "lp, lpstat, cancel", "Submitting and canceling jobs";
    foreach my $printer (qw(printer_tmp printer_null)) {
        assert_script_run "cupsdisable $printer";
        assert_script_run "lp -d $printer -o cpi=12 -o lpi=8 sample.ps";
        validate_script_output 'lpstat -o', sub { m/$printer-\d+/ };
        validate_script_output 'ls /var/spool/cups', sub { m/d\d+/ };
        assert_script_run "cancel -a $printer";
    }

    common_service_action 'cups', $service_type, 'restart';
    common_service_action 'cups', $service_type, 'is-active';

    # Do the printing
    record_info "lp, lpq", "Printing jobs";
    foreach my $printer (qw(printer_tmp printer_null)) {
        assert_script_run "cupsenable $printer";
        assert_script_run "lp -d $printer testpage.pdf";
        validate_script_output "lpq $printer", sub { m/is ready/ };
    }

    # Check logs
    record_info "access_log", "Access log should containt successful job submits";
    my $check_str = "Send-Document";
    $check_str = "Print-Job" if ($service_type eq 'SystemV');
    assert_script_run 'grep "$check_str successful-ok" /var/log/cups/access_log';

    # Check error log
    my $error_log = "/var/log/cups/error_log";

    if (script_run("test -s $error_log") == 0) {
        record_info("error log");
        upload_logs($error_log, failok => 1);

        assert_script_run('! grep -q "Unrecoverable error" ' . "$error_log");
    }

    # Remove printers
    record_info "lpadmin -x", "Removing printers";
    assert_script_run "lpadmin -x $_" foreach (qw(printer_tmp printer_null));
    validate_script_output('lpstat -p -d -o 2>&1 || test $? -eq 1', sub { m/No destinations added/ }, timeout => 120);
}

# check apache service before and after migration
# stage is 'before' or 'after' system migration.
sub full_cups_check {
    my (%hash) = @_;
    my ($stage, $type) = ($hash{stage}, $hash{service_type});
    $service_type = $type;
    if ($stage eq 'before') {
        install_service();
        config_service();
        enable_service();
        restart_service();
    }
    check_service();
    check_function();
    check_service();
}

1;
