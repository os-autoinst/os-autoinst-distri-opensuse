# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Abstraction layer to operate docker and podman containers through same interfaces
# Maintainer: qac team <qa-c@suse.de>

package containers::runtime;
use Mojo::Base -base;
use testapi;
use Test::Assert 'assert_equals';

has engine   => undef;
has registry => get_var('REGISTRY', 'docker.io');

sub _rt_assert_script_run {
    my ($self, $cmd, @args) = @_;
    assert_script_run($self->engine . " $cmd", @args);
}

sub _rt_script_run {
    my ($self, $cmd, @args) = @_;
    return script_run($self->engine . " $cmd", @args);
}

sub _rt_script_output {
    my ($self, $cmd, @args) = @_;
    return script_output($self->engine . " $cmd", @args);
}

sub _rt_validate_script_output {
    my ($self, $cmd, $func) = @_;
    return validate_script_output($self->engine . " $cmd", $func);
}

=head2 build

Build a container.
C<dockerfile_path> is the directory with the Dockerfile as well as the root of the build context.
C<container_tag> will be the name of the container.

=cut
sub build {
    my ($self, %args) = @_;
    die 'container_tag should be defined ' unless defined($args{container_tag});
    my $container_tag   = ' -t ' . $args{container_tag};
    my $dockerfile_path = '/tmp/' . $container_tag;
    $dockerfile_path = $args{dockerfile_path} if defined($args{dockerfile_path});
    $args{timeout} //= 300;
    #TODO add build with URL https://docs.docker.com/engine/reference/commandline/build/
    record_info("Building $container_tag", "Building $container_tag using " . $self->engine);
    $self->_rt_assert_script_run("build -f $dockerfile_path/Dockerfile $container_tag $dockerfile_path", timeout => $args{timeout});
    record_info "$container_tag created";
}

=head2 up

Run a container.
C<image_name> is required and can be the image id, the name or name with tag.
If C<daemon> is enabled then container will run in the detached mode. Otherwise will be in the
interactive mode.
if C<cmd> found then it will execute the given command into the container.
By default container is removed after exit. If C<keep_container> is 1 the container is not removed after creation.

=cut
sub up {
    my ($self, $image_name, %args) = @_;
    die 'image name or id is required' unless $image_name;
    my $mode           = $args{daemon}         ? '-d'    : '-it';
    my $remote         = $args{cmd}            ? 'sh -c' : '';
    my $keep_container = $args{keep_container} ? ''      : '--rm';
    my $exec_string    = sprintf(qq(run %s %s %s %s '%s'), $keep_container, $mode, $image_name, $remote, $args{cmd});
    my $ret            = $self->_rt_script_run($exec_string);
    record_info "Remote run on $image_name", "options $keep_container $mode $image_name $remote $args{cmd}";
    return $ret;
}

=head2 pull

Pull a container with the given C<image_name>
where C<image_name> can be the name or id of the image.

=cut
sub pull {
    my ($self, $image_name) = @_;
    my $ret = $self->_rt_script_run("pull $image_name");
    return $ret;
}

=head2 enum_images

Return an array ref of the images

=cut
sub enum_images {
    my ($self) = shift;
    my $images_s = $self->_rt_script_output("images -q");
    record_info "Images", $images_s;
    my @images = split /[\n\t]/, $images_s;
    return \@images;
}

=head2 enum_containers

Return an array ref of the containers

=cut
sub enum_containers {
    my ($self, %args) = shift;
    my $containers_s = $self->_rt_script_output("container ls -a" . $args{quiet} ? " -q" : "");
    record_info "Containers", $containers_s;
    my @containers = split /[\n\t]/, $containers_s;
    return \@containers;
}

=head2 info

Assert a C<property> against given expected C<value> if C<value> is given.
Otherwise it prints the output of info.

=cut
sub info {
    my ($self, %args) = shift;
    my $property = $args{property} ? qq(--format '{{.$args{property}}}') : '';
    my $expected = $args{value}    ? qq( | grep $args{value})            : '';
    $self->_rt_assert_script_run(sprintf("info %s %s", $property, $expected));
}

=head2 remove_image

Remove a image from the pool.

=cut
sub remove_image {
    my ($self, $image_name) = @_;
    $self->_rt_assert_script_run("rmi -f $image_name");
}

=head2 cleanup_system_host

Remove containers and then all the images respectively and then make sure that everything was cleaned up.

=cut
sub cleanup_system_host {
    my ($self) = @_;
    if ($self->is_buildah()) {
        $self->_rt_assert_script_run("rm --all");
        $self->_rt_assert_script_run("rmi --all --force");
    }
    $self->_rt_assert_script_run("stop \$($self->{engine} ps -q)", 180) if script_output("$self->{engine} ps -q | wc -l") != '0';
    $self->_rt_assert_script_run("system prune -a -f",             180);
    assert_equals(0, scalar @{$self->enum_containers(quiet => 1)}, "containers have not been removed");
    assert_equals(0, scalar @{$self->enum_images()},               "images have not been removed");
}

sub is_docker {
    my ($self) = @_;
    return $self->engine =~ /docker/;
}

sub is_podman {
    my ($self) = @_;
    return $self->engine =~ /podman/;
}


# TODO: buildah is not a runtime actually so this function and all it's usages should be dropped in the future
sub is_buildah {
    my ($self) = @_;
    return $self->engine =~ /buildah/;
}

sub exec_on_container {
    my ($self, $image, $command, %args) = @_;
    $args{timeout} //= 120;
    $self->_rt_assert_script_run("run --rm $image $command", %args);
}

1;
