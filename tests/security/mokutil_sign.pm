# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test mokutil signing function - Create necessary key pairs,
#          sign the kernel, import cert and boot with signed kernel.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#45701

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';
use registration 'add_suseconnect_product';
use power_action_utils "power_action";


sub run {
    my ($self) = @_;

    select_console 'root-console';

    if (is_sle('>=15')) {
        add_suseconnect_product("sle-module-desktop-applications");
        add_suseconnect_product("sle-module-development-tools");
    }

    zypper_call('in pesign mozilla-nss-tools');

    my $work_dir = "/root/certs";
    my $key_pw = "suse";    # Private key password
    my $cdb_pw = "openSUSE";    # Certificate database password
    my $mok_pw = "novell";    # Mokutil password
    my $cert_cfg = "$work_dir/self_signed.conf";
    my $pri_key = "$work_dir/key.asc";
    my $cert_pem = "$work_dir/cert.asc";
    my $cert_p12 = "$work_dir/cert.p12";
    my $cert_der = "$work_dir/ima_cert.der";

    assert_script_run("mkdir -p $work_dir");

    my $cert_pemdata = get_var("MOK_CERTCONF") // "openssl/gencert_conf/mok_cert.conf";
    assert_script_run "wget --quiet " . data_url($cert_pemdata) . " -O $cert_cfg";

    # Use default expiration days (1 month)
    assert_script_run("openssl req -new -x509 -newkey rsa -keyout $pri_key -out $cert_pem -nodes -config $cert_cfg");
    assert_script_run("openssl pkcs12 -export -inkey $pri_key -in $cert_pem -name kernel_cert -out $cert_p12 -passout pass:$key_pw");
    assert_script_run("openssl x509 -in $cert_pem -outform der -out $cert_der");

    # certutil -N does not support password in command argument, so the
    # interactive mode have to be applied here
    script_run_interactive(
        "certutil -d $work_dir -N",
        [
            {
                prompt => qr/Enter new password/m,
                string => "$cdb_pw\n",
            },
            {
                prompt => qr/Re-enter password/m,
                string => "$cdb_pw\n",
            },
        ],
        20
    );
    assert_script_run("pk12util -d $work_dir -i $cert_p12 -K $cdb_pw -W $key_pw");
    assert_script_run("ls $work_dir | tee /dev/$serialdev");

    my $kern = script_output("ls /boot/vmlinuz-*-default");

    # Remove existing signature and sign with new one to ensure it will boot
    # with MOK signed kernel
    assert_script_run("pesign -S -i $kern | tee /dev/$serialdev");
    assert_script_run("pesign -r -u 0 -i $kern -o /tmp/kerntmp");
    assert_script_run("mv /tmp/kerntmp $kern");
    validate_script_output "pesign -S -i $kern", sub { m/No signatures found/ };

    # The interactive mode have to be applied here
    script_run_interactive(
        "pesign -n $work_dir -c kernel_cert -i $kern -o /tmp/kerntmp -s",
        [
            {
                prompt => qr/Enter Password or Pin/m,
                string => "$cdb_pw\n",
            },
        ],
        20
    );

    assert_script_run("mv /tmp/kerntmp $kern");
    validate_script_output "pesign -S -i $kern", sub { m/certs.*included/ };

    # Import MOK certificate, with the interactive mode
    script_run_interactive(
        "mokutil --import $cert_der",
        [
            {
                prompt => qr/input password/m,
                string => "$mok_pw\n",
            },
            {
                prompt => qr/input password again/m,
                string => "$mok_pw\n",
            },
        ],
        20
    );

    validate_script_output "mokutil --list-new", sub { m/Certificate:/ };

    # Save certificate fingerprint for the later matching
    script_output("openssl x509 -noout -fingerprint -in $cert_pem |cut -d= -f2 |sed 's/:/ /g'");


    # Reboot to enroll MOK certificate in MokManger
    power_action('reboot', keepconsole => 1, textmode => 1);

    wait_serial "Press any key to perform MOK management", 60;
    save_screenshot;

    send_key 'ret';
    wait_serial "Continue boot.*Enroll MOK.*key.*hash", 10;
    save_screenshot;

    send_key 'down';
    send_key 'ret';    # "Enroll MOK"
    wait_serial "View key.*Continue", 10;
    save_screenshot;

    send_key 'ret';    # "View key 0"
    wait_serial "[Fingerprint]", 10;
    save_screenshot;

    send_key 'esc';
    wait_serial "View key.*Continue", 10;
    save_screenshot;

    send_key 'down';
    send_key 'ret';    # "Continue"
    wait_serial "Enroll the key\(s\)\?", 10;
    save_screenshot;

    send_key 'down';
    send_key 'ret';    # "Yes"
    wait_serial "Password:", 10;
    save_screenshot;

    type_password "$mok_pw\n";

    wait_serial "Reboot.*key.*hash", 10;
    save_screenshot;
    send_key 'ret';    # "Reboot"

    $self->wait_boot(textmode => 1, bootloader_time => 300, ready_time => 600);
    select_console "root-console";

}

sub test_flags {
    return {fatal => 1};
}

1;
