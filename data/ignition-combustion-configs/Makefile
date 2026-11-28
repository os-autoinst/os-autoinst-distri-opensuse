QCOWS = ignition_no_network_probe_minimal.qcow2 ignition_no_network_probe_test.qcow2 \
        ignition_only_no_network_minimal.qcow2 ignitiononly.qcow2 ignition.qcow2 \
        combustion_ltp.qcow2 combustiononly_no_network.qcow2 combustiononly.qcow2 \
        extended_combustion.qcow2
# Target directory for the .qcow2 files
HDD_FIXED_DIR ?= /var/lib/openqa/factory/hdd/
all: $(QCOWS:%=$(HDD_FIXED_DIR)/%)
.PHONY: all
.ONESHELL:
.SHELLFLAGS = -ec
.SECONDEXPANSION:
# All files in the directory named after the qcow2 are dependencies
$(HDD_FIXED_DIR)/%.qcow2: $$(shell find $(PWD)/%)
	if echo $* | grep -q combustion; then
		/sbin/mkfs.ext4 -q -L combustion -d $* $@.raw 16M
	else
		/sbin/mkfs.ext4 -q -L ignition -d $* $@.raw 16M
	fi
	qemu-img convert -c -O qcow2 $@.raw $@.new
	rm $@.raw
	mv $@.new $@
