#!/bin/bash
set -euo pipefail

echo "🔍 Template Validation Script Starting..."

# Required environment variables
: ${TEMPLATE_NAME:?"TEMPLATE_NAME is required"}
: ${GOVC_URL:?"GOVC_URL is required"}

echo "📋 Validation Parameters:"
echo "  Template Name: ${TEMPLATE_NAME}"

# Check if template exists
echo "🔍 Checking if template exists..."
if ! govc vm.info "${TEMPLATE_NAME}" >/dev/null 2>&1; then
    echo "❌ Template '${TEMPLATE_NAME}' not found"
    exit 1
fi

echo "✅ Template exists"

# Get template details
echo "📊 Template Details:"
template_info=$(govc vm.info -json "${TEMPLATE_NAME}")

echo "$template_info" | jq -r '
.VirtualMachines[0] | 
"  Name: \(.Name)
  Template: \(.Config.Template)
  Guest OS: \(.Config.GuestFullName)
  CPU: \(.Config.Hardware.NumCPU) cores
  Memory: \(.Config.Hardware.MemoryMB)MB
  Power State: \(.Runtime.PowerState)
  VMware Tools: \(.Guest.ToolsStatus // "Unknown")"
'

# Validate it's actually marked as template
is_template=$(echo "$template_info" | jq -r '.VirtualMachines[0].Config.Template')
if [ "$is_template" != "true" ]; then
    echo "⚠️  Warning: VM is not marked as template"
    echo "   This may cause issues during cloning"
else
    echo "✅ VM is properly marked as template"
fi

# Check for cloud-init compatibility
echo "🔍 Checking cloud-init compatibility..."
vm_tools_status=$(echo "$template_info" | jq -r '.VirtualMachines[0].Guest.ToolsStatus')
if [ "$vm_tools_status" = "toolsOk" ] || [ "$vm_tools_status" = "toolsOld" ]; then
    echo "✅ VMware Tools installed - cloud-init should work"
else
    echo "⚠️  VMware Tools status: $vm_tools_status"
    echo "   Cloud-init functionality may be limited"
fi

echo "🎉 Template validation completed!"