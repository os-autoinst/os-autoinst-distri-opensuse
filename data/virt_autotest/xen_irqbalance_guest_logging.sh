#!/bin/bash
#xen irqbalance guest debugging
date
set -x
rpm -q irqbalance
echo ""
systemctl status irqbalance
grep -e vif -e eth /proc/interrupts
echo ""
cat /proc/irq/default_smp_affinity
cat /proc/irq/*/smp_affinity
#skip 'irqbalance --debug' because it takes too long(more than 15 minutes)
#irqbalance --debug
set +x
date
