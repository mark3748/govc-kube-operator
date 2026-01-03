FROM alpine:3.19

# Install required packages
RUN apk add --no-cache \
    bash \
    curl \
    ca-certificates \
    openssh-client \
    jq \
    yq

# Install kubectl
ARG KUBECTL_VERSION=1.35.0
RUN curl -LO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Install govc
ARG GOVC_VERSION=0.52.0
RUN curl -L -o - "https://github.com/vmware/govmomi/releases/download/v${GOVC_VERSION}/govc_Linux_x86_64.tar.gz" | tar -C /usr/local/bin -xzf -

# Create workspace
WORKDIR /workspace

# Copy scripts and configuration
COPY scripts/ /workspace/scripts/
COPY config/ /workspace/config/

# Make scripts executable
RUN chmod +x /workspace/scripts/*.sh

# Set default environment variables for vSphere
ENV GOVC_INSECURE=1
ENV GOVC_DATACENTER=Datacenter
ENV GOVC_CLUSTER=Cluster
ENV GOVC_DATASTORE=iscsi-1tb
ENV GOVC_NETWORK="DPortGroup 10gb-1"
ENV GOVC_FOLDER=K3s-Nodes

# Default command
CMD ["/workspace/scripts/entrypoint.sh"]