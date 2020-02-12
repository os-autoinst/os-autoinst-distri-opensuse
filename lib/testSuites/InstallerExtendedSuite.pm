# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Concrete TestSuite Class to test Extended
# partitioning in YaST Installer

package InstallerExtendedSuite {
    use base 'TestSuiteInterface';
    use main_common;
    sub new {
        my ($class, $name) = @_;
        my $self = {};

        $self = $class->SUPER::new($name);
        $self->{variables} = {
            CHECK_PRESELECTED_MODULES => '1',
            CHECK_RELEASENOTES        => '1',
            EULA_LANGUAGES            => 'korean',
            EXIT_AFTER_START_INSTALL  => '1',
            EXTRABOOTPARAMS           => 'Y2STRICTTEXTDOMAIN=1',
            INSTALLER_EXTENDED_TEST   => "1",
            VALIDATE_CHECKSUM         => "1"
        };
        $self->set_scheduler(
            isosize                   => sub { loadtest("installation/isosize") },
            data_integrity            => sub { loadtest("installation/data_integrity") },
            bootloader                => sub { loadtest("installation/bootloader") },
            welcome                   => sub { loadtest("installation/welcome") },
            accept_license            => sub { loadtest("installation/accept_license") },
            scc_registration          => sub { loadtest("installation/scc_registration") },
            addon_products_sle        => sub { loadtest("installation/addon_products_sle") },
            system_role               => sub { loadtest("installation/system_role") },
            partitioning              => sub { loadtest("installation/partitioning") },
            partitioning_finish       => sub { loadtest("installation/partitioning_finish") },
            releasenotes              => sub { loadtest("installation/releasenotes") },
            installer_timezone        => sub { loadtest("installation/installer_timezone") },
            user_settings             => sub { loadtest("installation/user_settings") },
            user_settings_root        => sub { loadtest("installation/user_settings_root") },
            resolve_dependency_issues => sub { loadtest("installation/resolve_dependency_issues") },
            installation_overview     => sub { loadtest("installation/installation_overview") },
            disable_grub_timeout      => sub { loadtest("installation/disable_grub_timeout") },
            start_install             => sub { loadtest("installation/start_install") }
        );
        bless $self, $class;
        return $self;
    }
}

1;
