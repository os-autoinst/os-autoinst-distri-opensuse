QCOWS = combustiononly.qcow2 ignition.qcow2 ignition_no_network_probe_minimal.qcow2 ignitiononly.qcow2
# Target directory for the .qcow2 files
HDD_FIXED_DIR ?= /var/lib/openqa/factory/hdd/
all: $(QCOWS:%=$(HDD_FIXED_DIR)/%)
.PHONY: all
.ONESHELL:
.SHELLFLAGS = -ec
.SECONDEXPANSION:
# All files in the directory named after the qcow2 are dependencies
$(HDD_FIXED_DIR)/%.qcow2: $$(shell find $(PWD)/%)
	if [ "$*" = "combustiononly" ]; then
		/sbin/mkfs.ext4 -q -L combustion -d $* $@.raw 16M
	else
		/sbin/mkfs.ext4 -q -L ignition -d $* $@.raw 16M
	fi
	qemu-img convert -c -O qcow2 $@.raw $@.new
	rm $@.raw
	mv $@.new $@
