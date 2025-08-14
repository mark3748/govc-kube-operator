# govc Kubernetes Operator

A lightweight, production-ready Docker container for VMware vSphere VM operations using govc, designed for Kubernetes environments and GitOps workflows.

## 🚀 Features

- **VMware vSphere Integration**: Full compatibility with vSphere 6.7+ using govc CLI
- **Cloud-init Support**: VMware GuestInfo datasource for VM customization
- **Multiple Operation Modes**: One-shot commands or daemon mode watching Kubernetes ConfigMaps
- **Production Ready**: Built on Alpine Linux with security best practices
- **Kubernetes Native**: Designed for deployment in K8s clusters with RBAC support

## 📦 Image Details

- **Base Image**: Alpine 3.19 (minimal, secure)
- **Size**: ~71MB
- **Tools Included**:
  - govc 0.37.2 (VMware vSphere CLI)
  - kubectl 1.30.3 (Kubernetes CLI)
  - jq, yq (JSON/YAML processing)
  - bash, curl, openssh-client

## 🔧 Supported Operations

### VM Management
- **deploy-vm**: Clone VM from template with hardware and cloud-init customization
- **delete-vm**: Safe VM deletion with automatic power-off
- **list-vms**: Detailed VM inventory with status and resource information
- **validate-template**: Template readiness and compatibility checks

### Operation Modes
- **One-shot**: Execute single operation and exit
- **Daemon**: Watch Kubernetes ConfigMaps for operation requests

## 🚀 Quick Start

### Build the Image
```bash
docker build -t govc-kube-operator:latest .
```

### One-Shot VM Deployment
```bash
docker run --rm \
  -e GOVC_URL="https://user:password@vcenter.example.com/sdk" \
  -e GOVC_INSECURE=1 \
  -e OPERATION=deploy-vm \
  -e VM_NAME=test-vm-001 \
  -e TEMPLATE_NAME=fedora-42-k3s-template \
  -e MEMORY_GB=8 \
  -e CPU_COUNT=4 \
  govc-kube-operator:latest
```

### Docker Compose Deployment
```bash
# Edit docker-compose.yml with your vSphere credentials
docker-compose up -d
```

## 🔧 Configuration

### Required Environment Variables
```bash
# vSphere Connection (Required)
GOVC_URL=https://user:password@vcenter.example.com/sdk
GOVC_INSECURE=1                    # Set to 1 for self-signed certificates
GOVC_DATACENTER=Datacenter         # vSphere datacenter name
GOVC_CLUSTER=Cluster              # vSphere cluster name
GOVC_DATASTORE=datastore1         # Default datastore
GOVC_NETWORK="VM Network"         # Default network
GOVC_FOLDER=K3s-Nodes            # VM folder for deployments
```

### Operation-Specific Variables
```bash
# VM Deployment
VM_NAME=my-vm-001                 # Target VM name
TEMPLATE_NAME=my-template         # Source template name
MEMORY_GB=8                       # Memory allocation (default: 8)
CPU_COUNT=4                       # CPU cores (default: 4)
DISK_SIZE_GB=50                   # Disk size (default: 50)
USERDATA=<cloud-init-userdata>    # Cloud-init user data
METADATA=<cloud-init-metadata>    # Cloud-init metadata

# Daemon Mode
OPERATION=daemon                  # Set to 'daemon' for ConfigMap watching
WATCH_NAMESPACE=default           # Kubernetes namespace to watch
CHECK_INTERVAL=30                 # Check interval in seconds
```

## 📋 Usage Examples

### Deploy VM with Cloud-init
```bash
export USERDATA='#cloud-config
hostname: web-server-001
fqdn: web-server-001.example.com
users:
  - name: admin
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2E... your-key-here
runcmd:
  - systemctl enable nginx
  - systemctl start nginx'

docker run --rm \
  -e GOVC_URL="$GOVC_URL" \
  -e OPERATION=deploy-vm \
  -e VM_NAME=web-server-001 \
  -e TEMPLATE_NAME=ubuntu-22-04-template \
  -e USERDATA="$USERDATA" \
  govc-kube-operator:latest
```

### List All VMs
```bash
docker run --rm \
  -e GOVC_URL="$GOVC_URL" \
  -e OPERATION=list-vms \
  govc-kube-operator:latest
```

### Validate Template
```bash
docker run --rm \
  -e GOVC_URL="$GOVC_URL" \
  -e OPERATION=validate-template \
  -e TEMPLATE_NAME=fedora-42-k3s-template \
  govc-kube-operator:latest
```

### Delete VM
```bash
docker run --rm \
  -e GOVC_URL="$GOVC_URL" \
  -e OPERATION=delete-vm \
  -e VM_NAME=test-vm-001 \
  govc-kube-operator:latest
```

## 🎛️ Kubernetes Integration

### Daemon Mode with ConfigMap Operations

The operator can run in daemon mode, watching for Kubernetes ConfigMaps labeled with `govc-operator/operation` and executing the requested operations.

#### Example ConfigMap for VM Deployment
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: deploy-web-server
  namespace: default
  labels:
    govc-operator/operation: "deploy-vm"
data:
  operation: |
    operation: deploy-vm
    vm_name: web-server-001
    template_name: ubuntu-22-04-template
    memory_gb: 16
    cpu_count: 8
    userdata: |
      #cloud-config
      hostname: web-server-001
      fqdn: web-server-001.example.com
      users:
        - name: admin
          ssh_authorized_keys:
            - ssh-rsa AAAAB3NzaC1yc2E... your-key-here
      packages:
        - nginx
        - htop
      runcmd:
        - systemctl enable nginx
        - systemctl start nginx
    metadata: |
      instance-id: web-server-001
      local-hostname: web-server-001
```

#### Example ConfigMap for VM Deletion
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: delete-test-vm
  namespace: default
  labels:
    govc-operator/operation: "delete-vm"
data:
  operation: |
    operation: delete-vm
    vm_name: test-vm-001
```

### Kubernetes Deployment Example
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: govc-operator
  namespace: infrastructure-automation
spec:
  replicas: 1
  selector:
    matchLabels:
      app: govc-operator
  template:
    metadata:
      labels:
        app: govc-operator
    spec:
      serviceAccountName: govc-operator
      containers:
      - name: govc-operator
        image: govc-kube-operator:latest
        env:
        - name: OPERATION
          value: "daemon"
        - name: WATCH_NAMESPACE
          value: "infrastructure-automation"
        - name: GOVC_URL
          valueFrom:
            secretKeyRef:
              name: vsphere-credentials
              key: govc-url
        - name: GOVC_INSECURE
          value: "1"
        - name: GOVC_DATACENTER
          value: "Datacenter"
        - name: GOVC_CLUSTER
          value: "Cluster"
        - name: GOVC_DATASTORE
          value: "iscsi-1tb"
        - name: GOVC_NETWORK
          value: "DPortGroup 10gb-1"
        - name: GOVC_FOLDER
          value: "K3s-Nodes"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          exec:
            command:
            - govc
            - about
          initialDelaySeconds: 30
          periodSeconds: 60
```

## 🔒 Security Considerations

### Credential Management
- **Never embed credentials in images**: Use environment variables or Kubernetes secrets
- **Use Sealed Secrets**: For GitOps workflows, encrypt secrets with sealed-secrets
- **Limit RBAC**: Grant minimal permissions for ConfigMap operations
- **Network Policies**: Restrict network access to vSphere endpoints only

### Example Sealed Secret for vSphere
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: vsphere-credentials
  namespace: infrastructure-automation
spec:
  encryptedData:
    govc-url: AgBy3i4OJSWK+PiTySYZZA9rO21HcMRkpF...
  template:
    metadata:
      name: vsphere-credentials
      namespace: infrastructure-automation
```

## 🐛 Troubleshooting

### Common Issues

#### Connection Errors
```bash
# Test vSphere connectivity
docker run --rm \
  -e GOVC_URL="$GOVC_URL" \
  govc-kube-operator:latest \
  govc about
```

#### Template Not Found
```bash
# List available templates
docker run --rm \
  -e GOVC_URL="$GOVC_URL" \
  govc-kube-operator:latest \
  govc vm.info -json "Templates/*" | jq -r '.VirtualMachines[].Name'
```

#### Cloud-init Issues
- Ensure VMware Tools are installed in template
- Verify VMware GuestInfo datasource is configured
- Check that template is properly marked as template (`Config.Template: true`)

### Debug Mode
```bash
# Enable verbose logging
docker run --rm \
  -e GOVC_URL="$GOVC_URL" \
  -e GOVC_DEBUG=1 \
  -e OPERATION=deploy-vm \
  -e VM_NAME=debug-vm \
  -e TEMPLATE_NAME=test-template \
  govc-kube-operator:latest
```

## 🔗 Integration Examples

### GitOps Workflow with Flux CD
1. **ConfigMap Creation**: Developers create ConfigMaps for VM operations
2. **Git Commit**: ConfigMaps are committed to Git repository
3. **Flux Sync**: Flux CD applies ConfigMaps to cluster
4. **Operation Execution**: govc operator detects and processes operations
5. **Status Updates**: Operations are annotated with completion status

### CI/CD Pipeline Integration
```yaml
# GitHub Actions example
- name: Deploy Test Environment
  run: |
    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: deploy-test-env-${{ github.run_id }}
      namespace: infrastructure-automation
      labels:
        govc-operator/operation: "deploy-vm"
    data:
      operation: |
        operation: deploy-vm
        vm_name: test-env-${{ github.run_id }}
        template_name: test-template
        memory_gb: 4
        cpu_count: 2
    EOF
```

## 📊 Monitoring and Observability

### Health Checks
- **Container Health**: Built-in healthcheck using `govc about`
- **Operation Status**: ConfigMaps are annotated with completion status
- **Logging**: Structured logging with operation context

### Metrics Collection
The operator can be extended with Prometheus metrics for:
- Operation success/failure rates
- VM deployment times
- Resource utilization
- Template validation results

## 🚧 Roadmap

- [ ] Prometheus metrics integration
- [ ] Webhook-based operations (alternative to ConfigMap watching)
- [ ] VM snapshot management
- [ ] Storage policy configuration
- [ ] Multi-cluster support
- [ ] Terraform provider integration

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- [VMware govc](https://github.com/vmware/govmomi) - Official vSphere CLI
- [Alpine Linux](https://alpinelinux.org/) - Secure, lightweight base image
- [Kubernetes](https://kubernetes.io/) - Container orchestration platform
