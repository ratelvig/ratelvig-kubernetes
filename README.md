# Ratelvig kubernetes

Homelab automation for deploying a K3S Kubernates instance on Proxmox.

The project provisions a Debian VM with Terraform, then uses Ansible to install K3S.

---

## 📋 Prerequisites

- Terraform.
- Docker, if you use `ansible/run-ansible.sh` as the Ansible control environment.
- SSH access to the target VM as `root`.
- A Proxmox API token with permissions to create and start the VM.
- The SSH private key referenced by `ansible/ansible.cfg` inside the Ansible control environment:
  `/root/.ssh/ansible_id`.

---

## 🔐 Secret Management Guide

Do not commit local plaintext secrets. The following files are expected to stay private and untracked:

- `terraform/secrets.auto.tfvars`
- `ansible/.ansible.key`

`ansible/vault/secrets.yml` may be committed only if it is encrypted with
Ansible Vault. Never commit it in plaintext.

### 1. Terraform Secrets (`secrets.auto.tfvars`)

Copy the example variable template and supply your Proxmox credentials:

```bash
cd terraform
cp secrets.auto.tfvars.example secrets.auto.tfvars
```

Edit `terraform/secrets.auto.tfvars`:
```hcl
pm_api_url          = "https://192.168.2.2:8006/api2/json"
pm_api_token_id     = "terraform@pve!terraform-token"
pm_api_token_secret = "YOUR-PROXMOX-API-TOKEN-SECRET-UUID"
ssh_public_key      = "ssh-ed25519 AAAA... your-key-comment"
```

### 2. Ansible Vault (`.ansible.key` & `vault/secrets.yml`)

Ansible Vault protects sensitive tokens like the K3s node join token.

1. **Create the Vault Password File**:
   ```bash
   cd ansible
   cp .ansible.key.example .ansible.key
   chmod 600 .ansible.key
   # Replace with your secure secret passphrase
   ```

2. **Initialize Encrypted Secrets**:
   ```bash
   cp vault/secrets.yml.example vault/secrets.yml
   ansible-vault encrypt vault/secrets.yml --vault-password-file .ansible.key
   ```

   To edit secrets later:
   ```bash
   ansible-vault edit vault/secrets.yml --vault-password-file .ansible.key
   ```

---

## 🚀 Step-by-Step Execution Guide

### Step 1: Provision Infrastructure with Terraform

```bash
cd terraform

# Initialize providers
terraform init

# Review execution plan
terraform plan

# Apply infrastructure deployment
terraform apply -auto-approve
```

Inspect the output containing node IPs and the pre-formatted inventory snippet:
```bash
terraform output ansible_inventory_content
```

If needed, update `ansible/inventories/hosts.ini` with any IP addresses customized during your Terraform run.

---

### Step 2: Bootstrap Ansible Galaxy Dependencies

Using the containerized Docker runner:

```bash
cd ../ansible

# Install required Ansible collections inside the runner
./run-ansible.sh ansible-galaxy collection install -r requirements.yml
```

---

### Step 3: Deploy K3s Kubernetes Cluster

Execute the master deployment playbook:

```bash
./run-ansible.sh ansible-playbook playbooks/install_k3s.yml
```

The playbook will sequentially:
1. Validate connectivity and prepare Linux kernel modules (`overlay`, `br_netfilter`) and `sysctl` rules on all nodes.
2. Configure `/etc/rancher/k3s/config.yaml` on the server node and start the `k3s` service.
3. Fetch and update the `kubeconfig` file with the server's routable IP.
4. Configure and join worker agents via the `k3s-agent` service.
5. Perform an initial cluster sanity check.

---

### Step 4: Post-Install Verification & Local Kubectl Access

After deployment finishes, the cluster `kubeconfig` is automatically saved to `./kubeconfig` in the root of the repository.

1. **Set your `KUBECONFIG` environment variable**:
   ```bash
   export KUBECONFIG="$(pwd)/kubeconfig"
   ```

2. **Verify Cluster Nodes**:
   ```bash
   kubectl get nodes -o wide
   ```
   *Expected output:*
   ```text
   NAME            STATUS   ROLES                  AGE   VERSION        INTERNAL-IP    EXTERNAL-IP   OS-IMAGE
   k3s-master-01   Ready    control-plane,master   2m    v1.30.4+k3s1   192.168.2.10   <none>        Debian GNU/Linux 12 (bookworm)
   k3s-worker-01   Ready    worker                 1m    v1.30.4+k3s1   192.168.2.11   <none>        Debian GNU/Linux 12 (bookworm)
   ```

3. **Check Core Kubernetes System Pods**:
   ```bash
   kubectl get pods -A
   ```

---

### Step 5: Deploy Ingress Controller & Portainer

Since `traefik` and `servicelb` are disabled in K3s (`ansible/inventories/group_vars/k3s_cluster.yml`), Ingress-NGINX is deployed with `hostNetwork=true` to bind ports 80 and 443 directly on the host node.

#### 1. Install Ingress-NGINX Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.hostNetwork=true \
  --set controller.service.type=ClusterIP \
  --set controller.kind=DaemonSet
```

#### 2. Create Namespace & TLS Secret for Portainer

Combine your server certificate and CA certificate into a full chain bundle, then create the TLS secret:

```bash
# 1. Create full chain certificate (if not already created)
cat crt.crt root_ca.crt > fullchain.crt

# 2. Create the portainer namespace
kubectl create namespace portainer

# 3. Create the TLS secret
kubectl create secret tls portainer-tls \
  --cert=fullchain.crt \
  --key=pk.crt \
  -n portainer
```

#### 3. Deploy Portainer with Ingress

Deploy Portainer behind Ingress-NGINX with TLS termination:

```bash
helm repo add portainer https://portainer.github.io/k8s/
helm repo update

helm upgrade --install portainer portainer/portainer \
  -n portainer \
  --set tls.existingSecret=portainer-tls \
  --set service.type=ClusterIP \
  --set ingress.enabled=true \
  --set ingress.ingressClassName=nginx \
  --set ingress.hosts[0].host=kubernetes.ratelvig.local \
  --set ingress.hosts[0].paths[0].path="/" \
  --set ingress.hosts[0].paths[0].pathType=Prefix \
  --set ingress.tls[0].secretName=portainer-tls \
  --set ingress.tls[0].hosts[0]=kubernetes.ratelvig.local
```

Access the Portainer UI securely at:
```text
https://kubernetes.ratelvig.local/
```

---

### Step 6: Deploy & Configure cert-manager with HashiCorp Vault PKI

`cert-manager` is used to automate the issuance and renewal of TLS certificates using HashiCorp Vault's PKI secrets engine as a `ClusterIssuer`.

#### 1. Install cert-manager

Install `cert-manager` with Custom Resource Definitions (CRDs) enabled via Helm:

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true
```

Verify that cert-manager pods and webhook are running:
```bash
kubectl get pods -n cert-manager
```

#### 2. Configure Service Accounts & RBAC for Vault Integration

Apply the Service Accounts and tokens located in the `kubernetes/` folder:

1. **Deploy Vault Token Reviewer** (allows Vault to verify Kubernetes service account tokens):
   ```bash
   kubectl apply -f kubernetes/vault-reviewer.yaml
   ```

2. **Deploy cert-manager Vault Service Account** (used by cert-manager to authenticate against Vault):
   ```bash
   kubectl apply -f kubernetes/vault-sa.yaml
   ```

*(Optional reference)* In HashiCorp Vault, configure the Kubernetes authentication backend and role matching these service accounts:
```bash
# Extract the reviewer token and Kubernetes CA certificate
REVIEWER_JWT=$(kubectl get secret vault-reviewer-token -n cert-manager -o jsonpath='{.data.token}' | base64 -d)
K8S_CA=$(kubectl get secret vault-reviewer-token -n cert-manager -o jsonpath='{.data.ca\.crt}' | base64 -d)
K8S_HOST="https://kubernetes.ratelvig.local:6443"

# Configure Vault Kubernetes auth
vault write auth/kubernetes/config \
  kubernetes_host="$K8S_HOST" \
  token_reviewer_jwt="$REVIEWER_JWT" \
  kubernetes_ca_cert="$K8S_CA" \
  disable_iss_validation=true

# Bind Vault PKI role to cert-manager SA
vault write auth/kubernetes/role/cert-manager-vault-role \
  bound_service_account_names=cert-manager-vault-sa \
  bound_service_account_namespaces=cert-manager \
  policies=pki-policy \
  ttl=24h
```

#### 3. Deploy the Vault ClusterIssuer

Create the cluster-wide certificate issuer referencing Vault PKI:

```bash
kubectl apply -f kubernetes/vault-cluster-issuer.yaml
```

Check the status of the `ClusterIssuer`:
```bash
kubectl get clusterissuer vault-issuer
```
*Expected status should report `Ready: True`.*

#### 4. Requesting TLS Certificates

You can now automatically issue certificates from Vault:

- **Via Ingress annotations**:
  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: example-app
    annotations:
      cert-manager.io/cluster-issuer: vault-issuer
  spec:
    tls:
      - hosts:
          - app.ratelvig.local
        secretName: example-app-tls
  ...
  ```

- **Via a Certificate custom resource**:
  ```yaml
  apiVersion: cert-manager.io/v1
  kind: Certificate
  metadata:
    name: example-app-cert
    namespace: default
  spec:
    secretName: example-app-tls
    issuerRef:
      name: vault-issuer
      kind: ClusterIssuer
    commonName: app.ratelvig.local
    dnsNames:
      - app.ratelvig.local
  ```

---

## 🛠 Common Administrative Commands

### Cluster Management

- **View all cluster resources**:
  ```bash
  kubectl get all -A
  ```
- **Check node resource consumption**:
  ```bash
  kubectl top nodes
  ```

### Service Troubleshooting on Nodes

- **Inspect K3s Server logs (on control-plane)**:
  ```bash
  journalctl -u k3s -f
  ```
- **Inspect K3s Agent logs (on worker)**:
  ```bash
  journalctl -u k3s-agent -f
  ```
- **Check K3s configuration file**:
  ```bash
  cat /etc/rancher/k3s/config.yaml
  ```

### Teardown & Reset

- **Destroy infrastructure via Terraform**:
  ```bash
  cd terraform
  terraform destroy -auto-approve
  ```
