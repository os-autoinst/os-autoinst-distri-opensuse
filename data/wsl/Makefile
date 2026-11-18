.PHONY: all clean

all: clean autounattend_UEFI.raw autounattend.iso

autounattend_%.raw: Autounattend_%.xml
	@echo "***** Creating $@ from $< *****"
	/usr/sbin/mkfs.vfat -C $@ 16384
	mcopy -i $@ $< ::Autounattend.xml
	@echo "***** $@ created successfully! *****"

# ARM ISO image target
autounattend.iso: Autounattend_Arm64.xml
	mkisofs -J -graft-points -o $@ Autounattend.xml=$<
	@echo "***** $@ created successfully! *****"

clean:
	rm -f autounattend.iso autounattend_*.raw
