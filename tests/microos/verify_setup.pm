# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic check for ignition/combustion setup
# Test module expects configured image according to
# data/microos/butane/config.fcc either by combustion
# or ignition
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(systemctl);
use YAML::PP;
use File::Basename qw(basename);

my $data;
my $fail = 0;

sub load_test_data {
    my $ypp = YAML::PP->new();
    $data = $ypp->load_file(sprintf("%s/data/microos/butane/config.fcc", get_var('CASEDIR')));
    # remove butane metadata
    delete $data->{version};
    delete $data->{variant};
}

sub get_test_object {
    my ($entry, $test_object) = @_;
    return $data->{$entry}{$test_object};
}

sub print_summary {
    my $tests = shift;
    my (@errors) = @_;

    if (@errors) {
        record_info('Fail', join("\n", @errors), result => 'fail');
        $fail = 1;
    } else {
        record_info("OK", "All $tests passed!");
    }
}

sub systemd_tests {
    my $units = get_test_object('systemd', 'units');
    my @errors = ();

    if ($units) {
        record_info('systemd', 'Checking system setup');
    } else {
        record_info('SKIP', 'Skiping systemd tests!');
        return;
    }

    foreach my $unit (@$units) {
        my $name = $unit->{name};
        systemctl("is-enabled $name", expect_false => !$unit->{enabled});
        systemctl("is-active $name", expect_false => ($name =~ /sshd/) ? 0 : 1);

        if (exists $unit->{contents}) {
            if (script_run("grep 'Just a Test!' /etc/systemd/system/$name") != 0) {
                push @errors, "$units->{name} config file was not created as expected";
            }

            if (script_run('test -e /var/log/flagfile') != 0) {
                push @errors, 'Oneshort test service is missing expected data';
            }
        }
    }

    print_summary('systemd', @errors);
}

sub disk_tests {
    my $disks = get_test_object('storage', 'disks');
    my $filesystems = get_test_object('storage', 'filesystems');
    my $partitions = ();
    my @errors = ();

    if ($disks && $filesystems) {
        record_info('drives & fs', 'Checking filesystem and drives setup');
    } else {
        record_info('SKIP', 'Skipping filesystem and drives setup');
        return;
    }

    foreach my $disk (@$disks) {
        # maps label => partition
        foreach my $p (@{$disk->{partitions}}) {
            $partitions->{$p->{label}} = $disk->{device} . $p->{number};
        }

    }

    foreach my $fs (@$filesystems) {
        if (exists $fs->{device}) {
            delete $fs->{wipe_filesystem};

            my $label = basename($fs->{device});
            if (script_run("readlink -e $fs->{device} | grep $partitions->{$label}")) {
                push @errors, "Partition label $label is assigned to wrong partition or drive";
            }
            delete $fs->{device};

            if (exists $fs->{with_mount_unit} && $fs->{with_mount_unit} == 1 &&
                script_run("systemd-mount --no-legend --no-pager --list | grep $partitions->{$label}")) {
                push @errors, "Partition $partitions->{$label} was not mounted by systemd";
            }
            delete $fs->{with_mount_unit};

            if (exists $fs->{label} && script_run("blkid --label $fs->{label}")) {
                push @errors, "Drive by label $fs->{label} was not found";
            }
            delete $fs->{label};

            my $out = script_output("findmnt --noheadings $partitions->{$label}", proceed_on_failure => 1);
            if ($out !~ $fs->{format}) {
                push @errors, "Partition $partitions->{$label} was not formatted as $fs->{format}";
            }
            if ($out !~ $fs->{path}) {
                push @errors, "Partition $partitions->{$label} was not mounted in $fs->{path}";
            }
        }
    }

    print_summary('drives & fs', @errors);
}

sub user_tests {
    my $users = get_test_object('passwd', 'users');
    my @errors = ();

    if ($users) {
        record_info('users', 'Checking users setup');
    } else {
        record_info('SKIP', 'Skiping users tests!');
        return;
    }

    foreach my $user (@$users) {
        my $home;
        if (exists $user->{home_dir}) {
            $home = $user->{home_dir};
        } elsif ($user->{name} eq 'root') {
            $home = '/root';
        } else {
            $home = sprintf('/home/%s', $user->{name});
        }

        if (script_run("test -d $home") != 0 && !(exists $user->{no_create_home})) {
            push @errors, "$user->{name}'s home directory was wrongly set";
        }

        if (exists $user->{password_hash}) {
            my $match = join(':', $user->{name}, $user->{password_hash});
            if (script_run("grep '$match' /etc/shadow") != 0) {
                push @errors, "$user->{name}'s password is not correct!";
            }
        }

        if (exists $user->{uid} && script_run("id -u $user->{uid} -n | grep $user->{name}") != 0) {
            push @errors, "$user->{name}'s UID is not correct!";
        }

        if (exists $user->{groups}) {
            foreach my $group (@{$user->{groups}}) {
                if (script_run("id $user->{name} -Gn | grep $group") != 0) {
                    push @errors, "$user->{name} is missing $group";
                }
            }
        }

        if (exists $user->{gecos} &&
            script_run("grep -e '^$user->{name}.*$user->{gecos}' /etc/passwd") != 0) {
            push @errors, "$user->{name}'s GECOS is not correct!";
        }
    }

    print_summary('users', @errors);
}

sub group_tests {
    my $groups = get_test_object('passwd', 'groups');
    my $etc_group = script_output('cat /etc/group');
    my @errors = ();

    if ($groups) {
        record_info('groups', 'checking groups setup');
    } else {
        record_info('SKIP', 'Skiping groups tests!');
        return;
    }

    foreach my $group (@$groups) {
        push my @settings, $group->{name};
        push @settings, '.*';
        push @settings, $group->{gid} if exists $group->{gid};

        my $match = join(':', @settings);
        if ($etc_group !~ /$match/) {
            die "Missing group settings for $group->{name}";
        }
    }

    print_summary('groups', @errors);
}

sub directory_tests {
    my $directories = get_test_object('storage', 'directories');
    my @errors = ();

    if ($directories) {
        record_info('directories', 'checking directories setup');
    } else {
        record_info('SKIP', 'Skiping directories tests!');
        return;
    }

    foreach my $dir (@$directories) {
        if (script_run("test -e $dir->{path}") != 0) {
            record_info('Missing', "File $dir->{path} has not been created!", result => 'fail');
            push @errors, "Directory $dir->{path} does not exist";
            next;
        }

        my $dir_data = script_output("stat --format='%F %U %a' $dir->{path}", proceed_on_failure => 1);

        if ($dir_data !~ /directory/) {
            push @errors, "$dir->{path} is not a directory";
        }

        if ($dir_data !~ /$dir->{user}->{name}/) {
            push @errors, "$dir->{path} is not owned by $dir->{user}->{name}";
        }

        if ($dir_data !~ /$dir->{mode}/) {
            push @errors, "$dir->{path}'s permissions are not set to $dir->{mode}";
        }
    }

    print_summary('directories', @errors);
}

sub file_tests {
    my $files = get_test_object('storage', 'files');
    my @errors = ();

    if ($files) {
        record_info('files', 'checking files setup');
    } else {
        record_info('SKIP', 'Skiping files tests!');
        return;
    }

    foreach my $file (@$files) {
        if (script_run("test -e $file->{path}") != 0) {
            record_info('Missing', "File $file->{path} has not been created!", result => 'fail');
            push @errors, "File $file->{path} does not exist";
            next;
        }

        my $file_data = script_output("stat --format='%F %U %a' $file->{path}", proceed_on_failure => 1);

        if ($file_data !~ /regular file/) {
            push @errors, "$file->{path} is not a file";
        }

        if (exists $file->{user} && $file_data !~ /$file->{user}->{name}/) {
            push @errors, "$file->{path} is not owned by $file->{user}->{name}";
        }

        if (exists $file->{mode} && $file_data !~ /$file->{mode}/) {
            push @errors, "$file->{path}'s permissions are not set to $file->{mode}";
        }

        if (exists $file->{contents} &&
            script_run("grep '$file->{contents}->{inline}' $file->{path}")) {
            push @errors, "$file->{path}'s does not contain expected string: $file->{contents}->{inline}";
        }
    }

    print_summary('file_tests', @errors);
}

sub run {
    my $self = shift;
    select_serial_terminal();
    load_test_data();

    systemd_tests();
    user_tests();
    group_tests();
    directory_tests();
    file_tests();
    disk_tests();

    $self->result('failure') if $fail;
}

1;
