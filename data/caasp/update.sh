#!/usr/bin/env bash
set -exuo pipefail

# Fake update repositories for QA tests
# 2.0 -> 2.0 http://download.suse.de/ibs/Devel:/CASP:/2.0:/ControllerNode:/TestUpdate/standard/Devel:CASP:2.0:ControllerNode:TestUpdate.repo
# 3.0 -> 3.0 TODO

usage() {
	echo "Usage: $0
		[-s $REPO] Setup all nodes with update REPO
		[-c] Check that update was applied
		[-r] Just reboot cluster test" 1>&2
	exit 1
}

while getopts "s:cr" opt; do
case $opt in
	s)
		SETUP=$OPTARG
		;;
	c)
		CHECK=true
		;;
	r)
		REBOOT=true
		;;
	\?)
		usage
		;;
	:)
		echo "Option -$opt requires an argument." >&2
		usage
		;;
esac
done

# Set up some shortcuts
saltid=$(docker ps | grep salt-master | awk '{print $1}')
where="-P roles:(admin|kube-(master|minion))"
srun="docker exec -i $saltid salt --batch 7"
runner="$srun $where cmd.run"

if [ ! -z "${SETUP:-}" ]; then
	# Remove non-existent ISO repository
	# Workaround because of higher package versions
	$runner "zypper rr 1"

	# Add repository as system venodors
	$runner 'echo -e "[main]\nvendors = suse,opensuse,obs://build.suse.de,obs://build.opensuse.org" > /etc/zypp/vendors.d/vendors.conf'
	$runner "zypper ar --refresh --no-gpgcheck $SETUP UPDATE"
	$runner "zypper lr -U"

	# Manually Trigger Transactional Update (or wait up to 24 hours for it run by itself)
	$runner 'systemctl disable --now transactional-update.timer'
	$runner '/usr/sbin/transactional-update cleanup dup salt'

	# Manually Refresh the Grains (or wait up to 10 minutes)
	$srun '*' saltutil.refresh_grains

elif [ ! -z "${CHECK:-}" ]; then
	# caasp-container-manifests
	# check installed version
	zypper if --provides caasp-container-manifests | grep 100.0.0
	# check there is a "fo:bar" in the public manifests
	grep "fo: bar" /usr/share/caasp-container-manifests/public.yaml
	# check the change has been "activated"
	grep "fo: bar" /etc/kubernetes/manifests/public.yaml
	
	# container-feeder
	# check installed version
	zypper if --provides container-feeder | grep 100.0.0
	# check changes in README - zypper config changed to exclude doc
	# grep "This image has been updated fine" /usr/share/doc/packages/container-feeder/README.md
	
	# kubernetes-salt
	# check version
	zypper if --provides kubernetes-salt | grep 100.0
	# check etc/motd in a minion node
	COMMAND="grep 'This has been updated fine' /etc/motd"
	$srun -P "roles:kube-minion" cmd.run "$COMMAND" | grep 'This has been updated fine'
	
	# velum image
	# check version
	rpm -q sles12-velum-image | grep sles12-velum-image-100.0.0.*
	# check image has been loaded
	image_id=$(docker images | grep sles12/velum | grep 100.0 | head -1 | awk '{print $3}')
	container_id=$(docker ps | grep $image_id | grep dashboard | awk '{print $1}')
	# check change is in the image
	docker exec -i $container_id ls /IMAGE_UPDATED

elif [ ! -z "${REBOOT:-}" ]; then
	where="-P roles:kube-(master|minion)"
	srun="docker exec -d $saltid salt"
	$srun $where system.reboot
fi

# Workaround for assert_script_run "update.sh | tee $serialdev | grep EXIT_0", otherwise exit status is from tee
echo 'EXIT_OK'
