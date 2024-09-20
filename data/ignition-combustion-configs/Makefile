all: combustiononly.qcow2 ignition.qcow2 ignition_no_network_probe_minimal.qcow2 ignitiononly.qcow2
.PHONY: all
.ONESHELL:
.SECONDEXPANSION:
%.qcow2: $$(shell find $$*)
	if [ "$*" = "combustiononly" ]; then
		/sbin/mkfs.ext4 -F -L combustion -d $* $*.raw 16M
	else
		/sbin/mkfs.ext4 -F -L ignition -d $* $*.raw 16M
	fi
	qemu-img convert -c -O qcow2 $*.raw $@
	rm $*.raw
