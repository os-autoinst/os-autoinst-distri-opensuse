# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
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
use containers::utils qw(registry_url);
use utils qw(systemctl file_content_replace);

has runtime => undef;

sub _rt_assert_script_run {
    my ($self, $cmd, @args) = @_;
    assert_script_run($self->runtime . " " . $cmd, @args);
}

sub _rt_script_run {
    my ($self, $cmd, @args) = @_;
    return script_run($self->runtime . " " . $cmd, @args);
}

sub _rt_script_output {
    my ($self, $cmd, @args) = @_;
    return script_output($self->runtime . " " . $cmd, @args);
}

=head2 create_container($image, $name, [%args])

Creates a container.
C<image> the name of the image we create the container from.
C<name> is the given name of the created container.
C<args> can be anything you want to run in the container, similar to C<run>. for 
instance: C<docker create -it tumbleweed bash>

=cut
sub create_container {
    my ($self, $image, $name, $args) = @_;
    die 'wrong number of arguments' if @_ < 3;
    $self->_rt_assert_script_run("container create --name $name $image $args", 300);
    record_info "$name container created", "";
}

=head2 start_container($image_name)

Starts container named C<image_name>.

=cut
sub start_container {
    my ($self, $image_name) = @_;
    die 'wrong number of arguments' if @_ < 2;
    $self->_rt_assert_script_run("container start $image_name");
    record_info "$image_name container started", "";
}

=head2 halt_container($container_name)

Blocks a container until exits.
C<container_name> which runs. 
https://docs.docker.com/engine/reference/commandline/wait/

=cut
sub halt_container {
    my ($self, $container_name) = @_;
    die 'wrong number of arguments' if @_ < 2;
    $self->_rt_assert_script_run("wait $container_name");
    record_info "$container_name container is blocked.", "";
}


=head2 build($dockerfile_path, $container_tag, [%args])

Build a container from a Dockerfil.
C<dockerfile_path> is the directory with the Dockerfile as well as the root of the build context.
C<container_tag> will be the name of the container.
Give C<timeout> if you want to change the timeout passed to C<assert_script_run>. Default for containers is 300.

=cut
sub build {
    my ($self, $dockerfile_path, $container_tag, %args) = @_;
    die 'wrong number of arguments' if @_ < 3;
    unless ($self->runtime eq 'buildah') {
        #TODO add build with URL https://docs.docker.com/engine/reference/commandline/build/
        $self->_rt_assert_script_run("build -f $dockerfile_path/Dockerfile -t $container_tag $dockerfile_path", $args{timeout} // 300);
    }
    else {
        $self->_rt_assert_script_run("bud -t $container_tag $dockerfile_path", $args{timeout} // 300);
    }
    record_info "$container_tag created", "";
}

=head2 up($image_name, [mode, remote, keep_container, timeout])

Run a container.
C<image_name> is required and can be the image id, the name or name with tag.
If C<daemon> is enabled then container will run in the detached mode. Otherwise will be in the 
interactive mode.
if C<cmd> found then it will execute the given command into the container.
The container is always removed after exit.
if C<keep_container> is 1 the container is not removed after creation. Default to get removed
when it exits or when the daemon exits

=cut
sub up {
    my ($self, $image_name, %args) = @_;
    die 'image name or id is required' unless $image_name;
    my $mode           = $args{daemon}         ? '-d'    : '-it';
    my $remote         = $args{cmd}            ? 'sh -c' : '';
    my $keep_container = $args{keep_container} ? ''      : '--rm';
    my $ret = $self->_rt_script_run(sprintf qq(run %s %s %s %s '%s'), $keep_container, $mode, $image_name, $remote, $args{cmd}, timeout => $args{timeout});
    record_info "Remote run on $image_name", "options $keep_container $mode $image_name $remote $args{cmd}";
    return $ret;
}

=head2 pull($image_name, [%args])

Pull a container with the given C<image_name>
where C<image_name> can be the name or id of the image.
C<args> passes parameters to C<script_run>

=cut
sub pull {
    my ($self, $image_name, %args) = @_;
    my $ret = $self->_rt_script_run("pull $image_name", timeout => $args{timeout} // 300);
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

=head2 enum_images

Return an array ref of the containers

=cut
sub enum_containers {
    my ($self) = shift;
    my $containers_s = $self->_rt_script_output("container ls -q");
    record_info "Containers", $containers_s;
    my @containers = split /[\n\t]/, $containers_s;
    return \@containers;
}

=head2 get_images_by_repo_name

Returns an array ref with the names of the images.

=cut
sub get_images_by_repo_name {
    my ($self) = @_;
    my $repo_images;

    $repo_images = $self->_rt_script_output("images --format '{{.Repository}}'");

    my @images = split /[\n\t ]/, $repo_images;
    return \@images;
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

=head2 get_container_logs($container)

Request container's logs.
C<container> the running container.
C<logs> returns a string. 

=cut
sub get_container_logs {
    my ($self, $container) = @_;
    my $logs = $self->_rt_script_output("container logs $container");
    return $logs;
}

=head2 remove_image($image_name)

Remove a image from the pool.

=cut
sub remove_image {
    my ($self, $image_name) = @_;
    $self->_rt_assert_script_run("rmi -f $image_name");
}

=head2 remove_container

Remove a container from the pool.

=cut
sub remove_container {
    my ($self, $container_name) = @_;
    $self->_rt_assert_script_run("rm -f $container_name");
}

=head2 check_image_in_host_registry

Returns true if host contains C<img> or false.

=cut
sub check_image_in_host_registry {
    my ($self, $img) = shift;
    my @lregistry = $self->enum_images();
    $img =~ @lregistry;
}

=head2 setup_registry

Updates the registry files for the running container runtime to allow access to
insecure registries.

Implementation is subject to the the subclass otherwise call to this subroutine dies.

=cut
sub setup_registry {
    my ($self) = shift;
    die "Unsupported runtime - " . $self->runtime;
}

=head2 cleanup_system_host

Remove containers and then all the images respectively. 
Asserts that everything was cleaned up unless c<assert> is set to 0.

=cut
sub cleanup_system_host {
    my ($self) = @_;
    $self->_rt_assert_script_run("ps -q | xargs -r $self->{runtime} stop", 180);
    $self->_rt_assert_script_run("system prune -a -f",                     180);
    assert_equals(0, scalar @{$self->enum_containers()}, "containers have not been removed");
    assert_equals(0, scalar @{$self->enum_images()},     "images have not been removed");
}

# Container runtime subclasses here
package containers::runtime::docker;
use Mojo::Base 'containers::runtime';
has runtime => 'docker';

sub setup_registry {
    my ($self) = shift;
    my $registry = registry_url();
    # Allow our internal 'insecure' registry
    assert_script_run(
	'echo "{ \"debug\": true, \"insecure-registries\" : [\"localhost:5000\", \"registry.suse.de\", \"' . $registry . '\"] }" > /etc/docker/daemon.json');
    assert_script_run('cat /etc/docker/daemon.json');
    systemctl('restart docker');
}

package containers::runtime::podman;
use Mojo::Base 'containers::runtime';
has runtime => "podman";
use testapi;
sub setup_registry {
    my ($self) = shift;
    my $registry = registry_url();

    assert_script_run "curl " . data_url('containers/registries.conf') . " -o /etc/containers/registries.conf";
    assert_script_run "chmod 644 /etc/containers/registries.conf";
    file_content_replace("/etc/containers/registries.conf", REGISTRY => $registry);
}

package containers::runtime::buildah;
use Mojo::Base 'containers::runtime';
has runtime => "buildah";

sub cleanup_system_host {
    my ($self, $assert) = @_;
    $assert // 1;
    $self->_rt_assert_script_run("rm --all");
    $self->_rt_assert_script_run("rmi --all --force");

    if ($assert) {
        assert_equals(0, scalar @{$self->enum_containers()}, "containers have not been removed");
        assert_equals(0, scalar @{$self->enum_images()},     "images have not been removed");
    }
}

sub get_images_by_repo_name {
    my ($self) = @_;
    my $repo_images;

    $repo_images = $self->_rt_script_output("images --format '{{.Name}}'");
    my @images = split /[\n\t ]/, $repo_images;
    return \@images;
}

1;
