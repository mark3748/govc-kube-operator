#!/bin/bash
set -euo pipefail

echo "📋 VM Listing Script Starting..."

# Required environment variables
: ${GOVC_URL:?"GOVC_URL is required"}

echo "🔍 Listing VMs in folder: ${GOVC_FOLDER}"

# List VMs with details
govc vm.info -json "${GOVC_FOLDER}/*" 2>/dev/null | jq -r '
.VirtualMachines[] | 
"Name: \(.Name)
  Power State: \(.Runtime.PowerState)
  IP Address: \(.Guest.IpAddress // "N/A")
  CPU: \(.Config.Hardware.NumCPU) cores
  Memory: \(.Config.Hardware.MemoryMB)MB
  Guest OS: \(.Config.GuestFullName // "Unknown")
  Tools Status: \(.Guest.ToolsStatus // "Unknown")
  Template: \(.Config.Template)
  ---"
' || echo "No VMs found in folder ${GOVC_FOLDER}"

echo "📊 Summary:"
vm_count=$(govc find "${GOVC_FOLDER}" -type m 2>/dev/null | wc -l || echo "0")
echo "  Total VMs: ${vm_count}"