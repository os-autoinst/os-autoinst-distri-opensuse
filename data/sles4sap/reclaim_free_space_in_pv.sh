#!/bin/sh

# Exit if a command exits with a non-zero RC
set -e

# Error function
function error() {
  echo -e "$@" >&2
  exit 1
}

# Variable(s)
typeset -r DEVICE=$1
typeset PV_LIST PV PV_DEV
typeset -i NR_FREE START SSIZE PV_SIZE PV_DSTPE

# Device should be provided
[[ -z "${DEVICE}" ]] && error "Device should be provided!"

# There should be no multiple free regions
NR_FREE=$(pvs --noheadings -v --segments ${DEVICE} | grep -c free)

if (( NR_FREE <= 1 )); then
  echo "No multiple or no free regions, nothing to do!"
  exit 0
fi

# Try to have a contiguous free region
while (( NR_FREE > 1)); do
  PV_LIST=$(pvs --noheadings -v --segments ${DEVICE})

  # We need to remove the LV that begin at 0
  PV_LIST=$(grep -v "${DEVICE}:0-[0-9]*" <<<"${PV_LIST}")

  while IFS= read PV; do
    if grep -q free <<<"${PV}"; then
      # Keep the Start and SSize variables
      read START SSIZE <<< $(awk '{print $7, $8}' <<<"${PV}")

      # Go to next entry
      continue
    fi

    # PV to move
    read PV_SIZE PV_DEV <<< $(awk '{print $8, $12}' <<<"${PV}")

    # PV_SIZE should fit in SSIZE
    (( PV_SIZE > SSIZE )) && error "Not enough free space!"

    # Try to move the PV
    (( PV_DSTPE = START + PV_SIZE - 1 ))
    pvmove --alloc anywhere ${PV_DEV} ${DEVICE}:${START}-${PV_DSTPE}
  done <<<"${PV_LIST}"

  # Update NR_FREE
  NR_FREE=$(pvs --noheadings -v --segments ${DEVICE} | grep -c free)
done

# Clean exit
exit 0
