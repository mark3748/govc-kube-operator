#!/bin/bash
set -euo pipefail

echo "🚀 VM Deployment Script Starting..."

# Required environment variables
: ${VM_NAME:?"VM_NAME is required"}
: ${TEMPLATE_NAME:?"TEMPLATE_NAME is required"}
: ${GOVC_URL:?"GOVC_URL is required"}

# Optional parameters with defaults
MEMORY_GB=${MEMORY_GB:-8}
CPU_COUNT=${CPU_COUNT:-4}
DISK_SIZE_GB=${DISK_SIZE_GB:-50}

echo "📋 Deployment Parameters:"
echo "  VM Name: ${VM_NAME}"
echo "  Template: ${TEMPLATE_NAME}"
echo "  Memory: ${MEMORY_GB}GB"
echo "  CPU: ${CPU_COUNT} cores"
echo "  Disk: ${DISK_SIZE_GB}GB"

# Validate template exists
echo "🔍 Validating template exists..."
if ! govc vm.info "${TEMPLATE_NAME}" >/dev/null 2>&1; then
    echo "❌ Template '${TEMPLATE_NAME}' not found"
    exit 1
fi

# Check if VM already exists
if govc vm.info "${VM_NAME}" >/dev/null 2>&1; then
    echo "⚠️  VM '${VM_NAME}' already exists"
    exit 1
fi

echo "🔧 Cloning VM from template..."
govc vm.clone \
    -vm="${TEMPLATE_NAME}" \
    -folder="${GOVC_FOLDER}" \
    "${VM_NAME}"

echo "⚙️  Configuring VM hardware..."
govc vm.change \
    -vm="${VM_NAME}" \
    -c="${CPU_COUNT}" \
    -m="${MEMORY_GB}000"

# Configure cloud-init if userdata is provided
if [ -n "${USERDATA:-}" ]; then
    echo "☁️  Configuring cloud-init userdata..."
    govc vm.change \
        -vm="${VM_NAME}" \
        -e="guestinfo.userdata=$(echo -n "${USERDATA}" | base64 -w 0)" \
        -e="guestinfo.userdata.encoding=base64"
fi

if [ -n "${METADATA:-}" ]; then
    echo "☁️  Configuring cloud-init metadata..."
    govc vm.change \
        -vm="${VM_NAME}" \
        -e="guestinfo.metadata=$(echo -n "${METADATA}" | base64 -w 0)" \
        -e="guestinfo.metadata.encoding=base64"
fi

echo "🔌 Powering on VM..."
govc vm.power -on "${VM_NAME}"

echo "⏰ Waiting for VM to get IP address..."
timeout=300
elapsed=0
while [ $elapsed -lt $timeout ]; do
    vm_ip=$(govc vm.ip "${VM_NAME}" 2>/dev/null || echo "")
    if [ -n "$vm_ip" ] && [ "$vm_ip" != "<nil>" ]; then
        echo "✅ VM deployed successfully!"
        echo "   IP Address: $vm_ip"
        break
    fi
    sleep 10
    elapsed=$((elapsed + 10))
    echo "   Waiting for IP... (${elapsed}s/${timeout}s)"
done

if [ $elapsed -ge $timeout ]; then
    echo "⚠️  Timeout waiting for IP address, but VM is running"
    govc vm.info "${VM_NAME}"
fi

echo "🎉 VM deployment completed!"