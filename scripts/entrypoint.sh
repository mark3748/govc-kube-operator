#!/bin/bash
set -euo pipefail

echo "🚀 govc Kubernetes Operator Starting..."

# Check if this is a one-shot operation or daemon mode
if [ "${OPERATION:-daemon}" = "daemon" ]; then
    echo "🔄 Running in daemon mode - waiting for events..."
    exec /workspace/scripts/watch-operations.sh
else
    echo "🎯 Running one-shot operation: ${OPERATION}"
    case "${OPERATION}" in
        "deploy-vm")
            exec /workspace/scripts/deploy-vm.sh
            ;;
        "delete-vm")
            exec /workspace/scripts/delete-vm.sh
            ;;
        "list-vms")
            exec /workspace/scripts/list-vms.sh
            ;;
        "validate-template")
            exec /workspace/scripts/validate-template.sh
            ;;
        *)
            echo "❌ Unknown operation: ${OPERATION}"
            echo "Available operations: deploy-vm, delete-vm, list-vms, validate-template"
            exit 1
            ;;
    esac
fi