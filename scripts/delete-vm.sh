#!/bin/bash
set -euo pipefail

echo "🗑️  VM Deletion Script Starting..."

# Required environment variables
: ${VM_NAME:?"VM_NAME is required"}
: ${GOVC_URL:?"GOVC_URL is required"}

echo "📋 Deletion Parameters:"
echo "  VM Name: ${VM_NAME}"

# Check if VM exists
if ! govc vm.info "${VM_NAME}" >/dev/null 2>&1; then
    echo "⚠️  VM '${VM_NAME}' not found - nothing to delete"
    exit 0
fi

echo "🔍 Getting VM status..."
vm_state=$(govc vm.info -json "${VM_NAME}" | jq -r '.VirtualMachines[0].Runtime.PowerState')

if [ "$vm_state" = "poweredOn" ]; then
    echo "🔌 Powering off VM..."
    govc vm.power -off "${VM_NAME}"
    
    echo "⏰ Waiting for VM to power off..."
    timeout=60
    elapsed=0
    while [ $elapsed -lt $timeout ]; do
        current_state=$(govc vm.info -json "${VM_NAME}" | jq -r '.VirtualMachines[0].Runtime.PowerState')
        if [ "$current_state" = "poweredOff" ]; then
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
fi

echo "🗑️  Destroying VM..."
govc vm.destroy "${VM_NAME}"

echo "✅ VM '${VM_NAME}' deleted successfully!"