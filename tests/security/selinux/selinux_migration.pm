# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
#
# SUSE's openQA tests
# Package: selinux-policy
# Summary: test selinux-policy migration
# Maintainer: Gayane Osipyan <gosipyan@suse.com>

use base 'selinuxtest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle is_microos is_leap is_tumbleweed is_sle_micro has_selinux);
use transactional qw(process_reboot trup_call);
use Utils::Architectures;

sub run {
    select_serial_terminal;

    initial_state();

    check_dir();

    my $rollback_number = create_snapshot();

    update_selinux_policy();

    check_paths();

    check_after_update();

    check_custom_policy();

    check_service();

    rollback_and_verify_state($rollback_number);

    cleanup_test_artifacts();
}

# set up the initial test environment with packages, users, and custom policies
sub initial_state {
    record_info('Verifying SELinux status and installing packages.');
    assert_script_run('sestatus | grep "SELinux status:" | awk "{print $3}" | grep -q "enabled"');
    if (is_microos) {
        validate_script_output('sestatus', sub { m/SELinux status: .*enabled/ && m/Current mode: .*enforcing/ }, fail_message => 'SELinux is NOT enabled and set to enforcing');
        trup_call('pkg install selinux-policy-targeted selinux-policy-targeted-gaming policycoreutils policycoreutils-python-utils setools-console podman');
        process_reboot(trigger => 1);
    }
    else {
        # install selinux packages
        zypper_call('install selinux-policy-targeted selinux-policy-targeted-gaming policycoreutils policycoreutils-python-utils setools-console podman');
    }
    record_info('Creating test user and custom policy.');
    assert_script_run('useradd testselinux');
    assert_script_run('echo testselinux:testpasswd | chpasswd');
    assert_script_run('semanage login -a -s staff_u testselinux');
    assert_script_run('semanage port -a -t http_port_t -p tcp 8888');
    assert_script_run('semanage port -l | grep -E "(^SELinux Port Type|http_port_t).*8888"');
    assert_script_run('podman run -d --name test1 registry.fedoraproject.org/fedora:latest sleep infinity');
    assert_script_run('podman ps --filter name=test1');

    create_custom_module('mycustom', 'httpd_t', 'tcp_socket name_connect', 'allow httpd_t self:tcp_socket name_connect;');
    enable_boolean('httpd_can_network_connect_db');
    capture_current_state();
}

# create a new SELinux module from a template
sub create_custom_module {
    my ($name, $type, $class_perm, $policy_rule) = @_;
    record_info("Creating and installing custom module: $name");
    my $te_content = "module $name 1.0;\n\nrequire {\n    type $type;\n    class $class_perm;\n};\n\n$policy_rule";

    assert_script_run("echo '$te_content' > ${name}.te");
    assert_script_run("checkmodule -M -m -o ${name}.mod ${name}.te");
    assert_script_run("semodule_package -o ${name}.pp -m ${name}.mod");
    assert_script_run("semodule -i ${name}.pp");
    assert_script_run("semodule -l | grep -q '$name'");
}

# enable a specific SELinux boolean
sub enable_boolean {
    my ($boolean_name) = @_;
    record_info("Enabling boolean: $boolean_name");
    assert_script_run("setsebool -P $boolean_name on");
    assert_script_run("getsebool $boolean_name | grep -q 'on'");
}

# save the current system state for later verification
sub capture_current_state {
    record_info('Capturing system state before update.');
    script_run('semodule -l > semodule_list_before_migration.txt');
    script_run('semanage boolean -l > semanage_booleans_before_migration.txt');
    script_run('semanage login -l > semanage_login_before_migration.txt');
    script_run('semanage port -l > semanage_ports_before_migration.txt');
    script_run('semanage fcontext -l > semanage_fcontexts_before_migration.txt');
}

# create a snapper snapshot
sub create_snapshot {
    record_info('Creating snapshot for rollback.');
    my $rollback_number = script_output('snapper create -d "Before SELinux update" -p');
    script_output('snapper list');
    return $rollback_number;
}

# SELinux policy package update
sub update_selinux_policy {
    #TODO update test repo
    zypper_call('ar https://download.opensuse.org/repositories/home:/djz88:/branches:/security:/SELinux/openSUSE_Factory/ selinux-migration');
    record_info('Updating SELinux policy package.');
    zypper_call("--gpg-auto-import-keys ref");
    if (is_microos) {
        validate_script_output('sestatus', sub { m/SELinux status: .*enabled/ && m/Current mode: .*enforcing/ }, fail_message => 'SELinux is NOT enabled and set to enforcing');
        trup_call('dup', timeout => 600);
        process_reboot(trigger => 1);
    }
    else {
        zypper_call('dup --force-resolution  --allow-vendor-change --no-confirm');
    }
    zypper_call('info selinux-policy selinux-policy-targeted selinux-policy-targeted-gaming libsemanage-conf libsemanage2 policycoreutils policycoreutils-python-utils setools-console container-selinux');
    # Verify libsemanage-config store-root path
    #assert_script_run('grep -qx "store-root=/etc/selinux" /etc/selinux/semanage.conf');
    record_info('Adding a second custom module after update.');
    create_custom_module('mycustom2', 'sshd_t', 'process setrlimit', 'allow sshd_t self:process setrlimit;');
}

# check the system state after the update
sub check_after_update {
    record_info('Verifying system state after update.');
    script_run('diff -q semodule_list_before_migration.txt <(semodule -l)');
    script_run('diff -q semanage_booleans_before_migration.txt <(semanage boolean -l)');
    script_run('diff -q semanage_login_before_migration.txt <(semanage login -l)');

    my $module_list = script_output('semodule -l');
    for my $m (qw(mycustom mycustom2)) {
        if ($module_list =~ /^\Q$m\E\b/m) {
            print "$m present";
        } else {
            record_info("Module '$m' not found in semodule -l output\n", result => "fail");
        }
    }
    check_service();
}

# roll back the system to the pre-update state and verify
sub rollback_and_verify_state {
    my ($rollback_number) = @_;
    record_info("Rolling back to snapshot $rollback_number.");
    assert_script_run("snapper rollback $rollback_number");

    record_info('Verifying system state after rollback.');
    my $module_list = script_output('semodule -l');

    # check that 'mycustom' present
    for my $m (qw(mycustom mycustom2)) {
        if ($module_list =~ /^\Q$m\E\b/m) {
            print "$m present";
        } else {
            record_info("Module '$m' not found in semodule -l output\n", result => "fail");
        }
    }


    assert_script_run('semanage boolean -l | grep -q "httpd_can_network_connect_db.* on"');
    assert_script_run('semanage login -l | grep -q "testselinux.*staff_u"');
    assert_script_run('semanage port -l | grep -E "(^SELinux Port Type|http_port_t).*8888"');
    assert_script_run('podman ps --filter name=test1');

    script_output('ps -efZ | grep podman');

}

# test selinux-policy-targeted-gaming boolean
sub check_gaming_boolean {
    record_info('Verify gaming boolean is set');
    zypper_call('in selinux-policy-targeted-gaming');

    my $boolean_list = script_output('getsebool -a');
    for my $boolean (qw(selinuxuser_execstack selinuxuser_execmod)) {
        if ($boolean_list =~ /^\Q$boolean\E\b/m) {
            print "$boolean present";
        } else {
            record_info("Module '$boolean' not found in getsebool -a output\n", result => "fail");
        }
    }
}

# no packages install in  /var/lib/selinux
sub check_paths {
    my @packages = qw(selinux-policy selinux-policy-targeted selinux-policy-targeted-gaming libsemanage-conf libsemanage2 policycoreutils policycoreutils-python-utils setools-console);
    foreach my $package (@packages) {
        if (script_run("rpm -qvl $package | grep -q '/var/lib/selinux'")) {
            record_info("[FAIL]", "$package contain /var/lib/selinux paths", result => "fail");
        }
        else {
            script_run('echo "[PASS] no /var/lib/selinux paths found"');
            record_info("[PASS] no /var/lib/selinux paths found");
        }

    }
}

# check /var/lib/selinux deleted
sub check_dir {

    my $check_snapshot = script_output("grep -rq '/var/lib/selinux/' /.snapshots/* > /dev/null 2>&1");
    if ($check_snapshot == 0) {
        print "/var/lib/selinux exist in old snapshots";
        record_info("[FAIL]", "/var/lib/selinux exist in old snapshots", result => "fail");
    }
    elsif (-d "/var/lib/selinux") {
        print "/var/lib/selinux not delted \n";
        record_info("[FAIL]", "/var/lib/selinux not delted", result => "fail");
    }
    else {
        print "/var/lib/selinux doesnt exist on system\n";
    }
}

# check cleanoldsepoldir.service
sub check_service {
    if (assert_script_run("systemctl list-unit-files --type=service | grep -qw cleanoldsepoldir.service")) {
        my $status = script_output("systemctl is-enabled cleanoldsepoldir.service");
        return $status;
    } else {
        print "cleanoldsepoldir.service service not detected";
        record_info("[FAIL]", "cleanoldsepoldir.service not delted", result => "fail");
    }
}
# add custom modules
sub check_custom_policy {
    script_run("wget --no-check-certificate -O factory-custom-modules.txt https://gitlab.suse.de/selinux/selinux-monitoring/-/raw/main/factory-custom-modules.txt?ref_type=heads");
    my $modules = script_output('zypper -n se -s | awk "{print \$2}" | grep -E -- "-selinux$" | sort -u', timeout => 300);
    my @packages;
    foreach my $module (split /\n/, $modules) {
        next unless $module;
        next if $module eq 'forgejo-selinux';
        next if $module eq 'rke2-selinux';
        record_info("Package $module installing");
        if (is_microos) {
            trup_call("pkg install $module");
        }
        else {
            script_output("zypper -n -i in $module");
        }
        push @packages, $module;
        if (is_microos) {
            process_reboot(trigger => 1);
        }

    }

    check_paths(@packages);
}

# clean up all temporary files, users, and policy modules.
sub cleanup_test_artifacts {
    record_info('Cleaning up test environment.');
    script_run('semodule -r mycustom || true');
    script_run('semodule -r mycustom2 || true');
    script_run('userdel -r testselinux || true');
    script_run('semanage login -d testselinux || true');
    script_run('rm -f mycustom*.{te,mod,pp}');
    script_run('rm -f semodule_list_before_migration.txt semanage_booleans_before_migration.txt semanage_login_before_migration.txt');
    script_run('rm -f semanage_ports_before_migration.txt semanage_fcontexts_before_migration.txt');
    script_run('snapper list | grep "Before SELinux update" | awk "{print \$1}" | xargs -r snapper delete');
}

1;
