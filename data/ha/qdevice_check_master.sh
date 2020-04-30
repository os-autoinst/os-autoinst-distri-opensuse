#!/bin/sh
crm_resource --locate -r promotable-1 2>&1 | grep Master | grep `crm_node -n` >/dev/null 2>&1
