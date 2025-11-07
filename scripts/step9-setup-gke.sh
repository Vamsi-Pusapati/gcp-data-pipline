#!/bin/bash

# Step 9: Setup Google Kubernetes Engine (GKE) Cluster
# This script creates a GKE cluster for containerized applications

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ID=${1:-"gcp-project-deliverable"}
CLUSTER_NAME="data-pipeline-gke"
REGION="us-central1"
ZONE="us-central1-a"
NODE_COUNT=3
MACHINE_TYPE="e2-medium"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 9: Setup GKE Cluster${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Project ID: $PROJECT_ID"
echo "Cluster Name: $CLUSTER_NAME"
echo "Region: $REGION"
echo "Zone: $ZONE"
echo "Node Count: $NODE_COUNT"
echo "Machine Type: $MACHINE_TYPE"
echo ""

# Set the project
echo -e "${YELLOW}Setting gcloud project...${NC}"
gcloud config set project $PROJECT_ID

# Check if cluster already exists
echo -e "${YELLOW}Checking if GKE cluster exists...${NC}"
if gcloud container clusters describe $CLUSTER_NAME --zone=$ZONE --project=$PROJECT_ID &>/dev/null; then
    echo -e "${YELLOW}GKE cluster already exists.${NC}"
    
    # Get cluster status
    CLUSTER_STATUS=$(gcloud container clusters describe $CLUSTER_NAME --zone=$ZONE --project=$PROJECT_ID --format="value(status)")
    echo "Cluster status: $CLUSTER_STATUS"
    
    if [ "$CLUSTER_STATUS" = "RUNNING" ]; then
        echo -e "${GREEN}Cluster is running and ready to use.${NC}"
    else
        echo -e "${YELLOW}Cluster exists but is not running. Current status: $CLUSTER_STATUS${NC}"
    fi
else
    echo -e "${YELLOW}Creating GKE cluster...${NC}"
    echo "This will take approximately 3-7 minutes."
    echo ""
    
    # Create GKE cluster
    if gcloud container clusters create $CLUSTER_NAME \
        --zone=$ZONE \
        --machine-type=$MACHINE_TYPE \
        --num-nodes=$NODE_COUNT \
        --enable-autorepair \
        --enable-autoupgrade \
        --enable-autoscaling \
        --min-nodes=1 \
        --max-nodes=10 \
        --disk-size=50GB \
        --disk-type=pd-standard \
        --image-type=COS_CONTAINERD \
        --enable-network-policy \
        --enable-ip-alias \
        --enable-cloud-logging \
        --enable-cloud-monitoring \
        --project=$PROJECT_ID; then
        echo -e "${GREEN}✓ GKE cluster created successfully${NC}"
    else
        echo -e "${RED}✗ Failed to create GKE cluster${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${YELLOW}Configuring kubectl...${NC}"

# Get cluster credentials
if gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE --project=$PROJECT_ID; then
    echo -e "${GREEN}✓ Kubectl configured${NC}"
else
    echo -e "${RED}✗ Failed to configure kubectl${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Creating Kubernetes namespaces...${NC}"

# Create namespaces
NAMESPACES=("data-pipeline" "monitoring" "staging")

for namespace in "${NAMESPACES[@]}"; do
    echo -n "Creating namespace: $namespace... "
    if kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi
done

echo ""
echo -e "${YELLOW}Creating Kubernetes deployment files...${NC}"

# Create GKE directory structure
GKE_DIR="../gke"
mkdir -p $GKE_DIR/deployments
mkdir -p $GKE_DIR/services
mkdir -p $GKE_DIR/configmaps
mkdir -p $GKE_DIR/secrets

# Create data processor deployment
cat > $GKE_DIR/deployments/data-processor.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-processor
  namespace: data-pipeline
  labels:
    app: data-processor
spec:
  replicas: 2
  selector:
    matchLabels:
      app: data-processor
  template:
    metadata:
      labels:
        app: data-processor
    spec:
      containers:
      - name: data-processor
        image: gcr.io/gcp-project-deliverable/data-processor:latest
        ports:
        - containerPort: 8080
        env:
        - name: PROJECT_ID
          value: "gcp-project-deliverable"
        - name: PUBSUB_TOPIC
          value: "sensor-data"
        - name: BIGQUERY_DATASET
          value: "processed_data"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: data-processor-service
  namespace: data-pipeline
spec:
  selector:
    app: data-processor
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: ClusterIP
EOF

# Create API gateway deployment
cat > $GKE_DIR/deployments/api-gateway.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: data-pipeline
  labels:
    app: api-gateway
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      containers:
      - name: api-gateway
        image: gcr.io/gcp-project-deliverable/api-gateway:latest
        ports:
        - containerPort: 8080
        env:
        - name: PROJECT_ID
          value: "gcp-project-deliverable"
        - name: BIGQUERY_DATASET
          value: "analytics"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: api-gateway-service
  namespace: data-pipeline
spec:
  selector:
    app: api-gateway
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: LoadBalancer
EOF

# Create monitoring deployment
cat > $GKE_DIR/deployments/monitoring.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
  labels:
    app: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-service
  namespace: monitoring
spec:
  selector:
    app: prometheus
  ports:
  - protocol: TCP
    port: 9090
    targetPort: 9090
  type: ClusterIP
EOF

# Create ConfigMap for Prometheus
cat > $GKE_DIR/configmaps/prometheus-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: 'kubernetes-apiservers'
        kubernetes_sd_configs:
        - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
          action: keep
          regex: default;kubernetes;https
      - job_name: 'kubernetes-nodes'
        kubernetes_sd_configs:
        - role: node
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      - job_name: 'data-pipeline-apps'
        kubernetes_sd_configs:
        - role: endpoints
          namespaces:
            names:
            - data-pipeline
        relabel_configs:
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
EOF

# Create Ingress for external access
cat > $GKE_DIR/services/ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: data-pipeline-ingress
  namespace: data-pipeline
  annotations:
    kubernetes.io/ingress.class: "gce"
    kubernetes.io/ingress.global-static-ip-name: "data-pipeline-ip"
    networking.gke.io/managed-certificates: "data-pipeline-ssl"
spec:
  rules:
  - host: api.data-pipeline.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-gateway-service
            port:
              number: 80
EOF

echo ""
echo -e "${YELLOW}Applying Kubernetes configurations...${NC}"

# Apply ConfigMaps first
echo -n "Applying ConfigMaps... "
if kubectl apply -f $GKE_DIR/configmaps/; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
fi

# Note: We're not deploying the actual applications since the container images don't exist yet
echo ""
echo -e "${YELLOW}Kubernetes deployment files created.${NC}"
echo "Container images need to be built and pushed before deploying."

# Create simple test deployment to verify cluster
echo -n "Deploying test nginx pod... "
if kubectl run test-nginx --image=nginx --port=80 --namespace=data-pipeline; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}Pod may already exist${NC}"
fi

# Expose test deployment
echo -n "Exposing test deployment... "
if kubectl expose pod test-nginx --port=80 --target-port=80 --type=ClusterIP --namespace=data-pipeline; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}Service may already exist${NC}"
fi

echo ""
echo -e "${YELLOW}Checking cluster status...${NC}"

# Get cluster info
echo "Cluster nodes:"
kubectl get nodes

echo ""
echo "Cluster namespaces:"
kubectl get namespaces

echo ""
echo "Test deployment status:"
kubectl get pods -n data-pipeline

echo ""
echo -e "${GREEN}GKE setup completed!${NC}"
echo ""
echo -e "${YELLOW}Cluster Details:${NC}"
echo "  • Cluster Name: $CLUSTER_NAME"
echo "  • Zone: $ZONE"
echo "  • Nodes: $NODE_COUNT x $MACHINE_TYPE"
echo "  • Auto-scaling: 1-10 nodes"

echo ""
echo -e "${YELLOW}Created Namespaces:${NC}"
echo "  • data-pipeline - Main application namespace"
echo "  • monitoring - Monitoring tools namespace"
echo "  • staging - Staging environment namespace"

echo ""
echo -e "${YELLOW}Deployment Files Created:${NC}"
echo "  • $GKE_DIR/deployments/data-processor.yaml"
echo "  • $GKE_DIR/deployments/api-gateway.yaml"
echo "  • $GKE_DIR/deployments/monitoring.yaml"
echo "  • $GKE_DIR/configmaps/prometheus-config.yaml"
echo "  • $GKE_DIR/services/ingress.yaml"

echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "  Get cluster info: kubectl cluster-info"
echo "  Get nodes: kubectl get nodes"
echo "  Get pods: kubectl get pods --all-namespaces"
echo "  Deploy app: kubectl apply -f deployment.yaml"
echo "  Scale deployment: kubectl scale deployment DEPLOYMENT_NAME --replicas=3"
echo "  Delete test pod: kubectl delete pod test-nginx -n data-pipeline"

echo ""
echo -e "${YELLOW}Console URLs:${NC}"
echo "  GKE Console: https://console.cloud.google.com/kubernetes/list?project=$PROJECT_ID"
echo "  Workloads: https://console.cloud.google.com/kubernetes/workload?project=$PROJECT_ID"

echo ""
echo "Next step: Run './step10-setup-react-dashboard.sh' to deploy the React dashboard"
