package BootLinuxrcSuite {
    use base 'TestSuiteInterface';
    use main_common;
    sub new {
        my ($class, $name) = @_;
        my $self = {};
        $self = $class->SUPER::new($name);
        $self->{variables} = {
            DESKTOP          => 'gnome',
            HDD_1            => 'SLES-%VERSION%-%ARCH%-Build%BUILD%@%MACHINE%-gnome.qcow2',
            LINUXRC_BOOT     => '1',
            START_AFTER_TEST => 'create_hdd_gnome',
            YAML_SCHEDULE    => 'schedule/yast/boot_linuxrc.yaml'
        };
        $self->set_scheduler(
            boot_linuxrc       => sub { loadtest("boot/boot_linuxrc") },
            installer_extended => sub { loadtest("installation/first_boot") }
        );
        bless $self, $class;
        return $self;
    }
}

1;
