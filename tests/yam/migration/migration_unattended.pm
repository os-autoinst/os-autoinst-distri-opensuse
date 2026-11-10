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
use Utils::Backends qw(is_ipmi);
use Utils::Architectures 'is_s390x';
use Utils::Backends 'is_pvm';
use registration;

sub run {
    my $self = shift;

    select_console('root-console');

    # Only for products in development, not maintenance
    # Online FLAVOR is the only one running migrations for products in development
    my $is_devel_dms_required = sub {
        return get_var('FLAVOR', '') eq 'Online';
    };

    if ($is_devel_dms_required->()) {
        my $repo_server = "https://download.opensuse.org/repositories/devel:/DMS/";
        my $repo_url = $repo_server . "SLE_" . (get_var('VERSION_UPGRADE_FROM') =~ s/-/_/gr);
        zypper_call("ar --refresh -p 90 '$repo_url' devel_DMS");
    }

    assert_script_run('echo migration_product: ' . get_var('AGAMA_PRODUCT_ID') . '/' . get_var('VERSION') . '/'
          . get_var('ARCH') . ' > /etc/sle-migration-service.yml');

    # install the migration image and active it
    my $migration_tool = is_s390x ? 'SLES16-Migration' : 'suse-migration-sle16-activation';
    record_info("installing DMS", script_output("zypper --gpg-auto-import-keys -n in $migration_tool"));

    # deactivate unwanted/unsupported extensions before doing migration
    if (get_var('SCC_SUBTRACTIONS')) {
        foreach my $addon (split(',', get_var('SCC_SUBTRACTIONS'))) {
            my $extension = get_addon_fullname($addon);
            # NVIDIA Compute is not versioned by SP
            remove_suseconnect_product($extension, (($addon eq 'nvidia') ? '15' : ()));
        }
    }

    if ($is_devel_dms_required->()) {
        zypper_call("rr devel_DMS");
    }
    my @media_repos_to_remove_before_migration;
    foreach my $line (split /\n/, script_output('zypper lr -u')) {
        my ($num, $alias, undef, undef, undef, undef, $uri) = split /\s*\|\s*/, $line;
        push @media_repos_to_remove_before_migration, {num => $num, alias => $alias, uri => $uri} if ($uri // '') =~ m{^(cd|dvd|ftp):|openqa[^/]*/assets/repo};
    }
    if (@media_repos_to_remove_before_migration) {
        record_info('remove repos', join("\n", map { "$_->{alias}: $_->{uri}" } @media_repos_to_remove_before_migration));
        zypper_call('rr ' . join(' ', map { $_->{num} } @media_repos_to_remove_before_migration));
    }

    # Add product increment repo
    if (my $repo_increment = get_var('INCREMENT_REPO')) {
        zypper_call("ar --refresh $repo_increment Increment_repo");
    }

    # list repos and check network before migration
    record_info('list repos', script_output('zypper lr -u'));
    record_info('network', script_output('ip a s'));
    record_info('wicked', script_output('wicked ifstatus all'));
    record_info('config', script_output('for i in $(find /etc/sysconfig/network -name ifcfg*); do echo "XXXXXXXXXX $i"; cat $i; done'));

    # upload logs to know system state before migration
    upload_logs("/boot/grub2/grub.cfg", failok => 1);
    upload_folders(folders => '/etc/zypp/repos.d/');

    if (is_s390x) {
        enter_cmd '/usr/sbin/run_migration';
        reset_consoles;
        reconnect_mgmt_console(timeout => 600);
    } else {
        # disable timeout for migration grub menu
        assert_script_run("sed -i 's/set timeout=[0-9]*/set timeout=-1/' /etc/grub.d/99_migration");
        assert_script_run("grub2-mkconfig -o /boot/grub2/grub.cfg");
        power_action('reboot', textmode => 1, keepconsole => 1, first_reboot => 1);
        reconnect_mgmt_console(timeout => 600) if (is_ipmi | is_pvm),;
        assert_screen('grub-menu-migration', is_ipmi ? 600 : 120);
        send_key 'ret';
        assert_screen('migration-running', 60) unless (is_pvm);
        assert_screen('grub2', 1200);
    }
}

sub post_fail_hook {
    assert_screen('grub2', 300);
    send_key "ret";
    select_console 'root-console';
    upload_logs("/var/log/distro_migration.log", failok => 1);
}

1;
