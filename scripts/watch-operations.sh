#!/bin/bash
set -euo pipefail

echo "👀 Operation Watcher Starting..."

# Configuration
NAMESPACE=${WATCH_NAMESPACE:-default}
CHECK_INTERVAL=${CHECK_INTERVAL:-30}

echo "📋 Watcher Configuration:"
echo "  Namespace: ${NAMESPACE}"
echo "  Check Interval: ${CHECK_INTERVAL}s"

# Function to process ConfigMap operations
process_operation() {
    local operation_name="$1"
    local operation_data="$2"
    
    echo "🎯 Processing operation: ${operation_name}"
    
    # Extract operation type and parameters
    local op_type=$(echo "$operation_data" | yq eval '.operation' -)
    
    case "$op_type" in
        "deploy-vm")
            export VM_NAME=$(echo "$operation_data" | yq eval '.vm_name' -)
            export TEMPLATE_NAME=$(echo "$operation_data" | yq eval '.template_name' -)
            export MEMORY_GB=$(echo "$operation_data" | yq eval '.memory_gb // 8' -)
            export CPU_COUNT=$(echo "$operation_data" | yq eval '.cpu_count // 4' -)
            export USERDATA=$(echo "$operation_data" | yq eval '.userdata // ""' -)
            export METADATA=$(echo "$operation_data" | yq eval '.metadata // ""' -)
            
            echo "🚀 Executing VM deployment..."
            /workspace/scripts/deploy-vm.sh
            ;;
        "delete-vm")
            export VM_NAME=$(echo "$operation_data" | yq eval '.vm_name' -)
            
            echo "🗑️  Executing VM deletion..."
            /workspace/scripts/delete-vm.sh
            ;;
        *)
            echo "❌ Unknown operation type: $op_type"
            return 1
            ;;
    esac
    
    # Mark operation as completed by adding status annotation
    kubectl annotate configmap "$operation_name" \
        -n "$NAMESPACE" \
        "govc-operator/status=completed" \
        "govc-operator/completed-at=$(date -Iseconds)" \
        --overwrite
}

# Main watch loop
echo "🔄 Starting watch loop..."
while true; do
    # Find ConfigMaps with govc-operator operations
    operations=$(kubectl get configmaps -n "$NAMESPACE" \
        -l "govc-operator/operation" \
        -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
    
    for operation_name in $operations; do
        # Skip if already processed
        status=$(kubectl get configmap "$operation_name" -n "$NAMESPACE" \
            -o jsonpath='{.metadata.annotations.govc-operator/status}' 2>/dev/null || echo "")
        
        if [ "$status" = "completed" ]; then
            continue
        fi
        
        echo "📝 Found pending operation: $operation_name"
        
        # Get operation data
        operation_data=$(kubectl get configmap "$operation_name" -n "$NAMESPACE" -o yaml | yq eval '.data.operation' -)
        
        # Process the operation
        if process_operation "$operation_name" "$operation_data"; then
            echo "✅ Operation $operation_name completed successfully"
        else
            echo "❌ Operation $operation_name failed"
            # Mark as failed
            kubectl annotate configmap "$operation_name" \
                -n "$NAMESPACE" \
                "govc-operator/status=failed" \
                "govc-operator/failed-at=$(date -Iseconds)" \
                --overwrite
        fi
    done
    
    sleep "$CHECK_INTERVAL"
done