# start.kubermatic.io - Manual Deployment Steps

Here's the list of exact steps to be followed if you want to validate everything yourself
(without having that delivered with GitHub Actions / Workflows).

This can be handy for testing everything locally, understanding the whole flow and to be able to customize
for your needs later on.

## Preparation

### Required Tools

 * `git`
 * `aws` (AWS CLI tool)
 * `terraform` (1.0.4+)
 * `kubeone` (1.3.0+)
 * `sops` (3.7.1+)
 * `flux` v2 (0.16.1+)

### Setup env.variables

```bash
# from AWS console or CLI
export AWS_ACCESS_KEY_ID=<AWS_ACCESS_KEY_ID>
# from AWS console or CLI      
export AWS_SECRET_ACCESS_KEY=<AWS_SECRET_ACCESS_KEY>
# from GitHub settings
export GITHUB_TOKEN=<GITHUB_TOKEN>
# your GitHub owner / username / organization
export GITHUB_OWNER=<GITHUB_OWNER>
# your GitHub repository name
export GITHUB_REPOSITORY=<GITHUB_REPOSITORY>
```

### Prepare GitHub repository

```bash
gh auth login
gh repo create --private $GITHUB_OWNER/$GITHUB_REPOSITORY
git init
git checkout -b main
# do not add .github directory!
git add README.md .gitignore flux/ kubermatic/ terraform/ kubeone/
git commit -m "Initial setup for KKP on Autopilot"
git remote add origin git@github.com:$GITHUB_OWNER/$GITHUB_REPOSITORY.git
git push -u origin main
```

## Deployment

### Prepare Terraform backend (S3 bucket)

```bash
cd terraform/aws
./setup_terraform_backend.sh
cd ../..
```

### Prepare infrastructure with Terraform

```bash
cd terraform/aws
terraform init \
  -backend-config="bucket=tf-state-kkp-" \
  -backend-config="region=eu-central-1"
terraform apply
terraform output -json > output.json
cd ../..
```

### Initialize k8s cluster with KubeOne

```bash
cd kubeone
eval `ssh-agent`
ssh-add ~/.ssh/k8s_rsa
kubeone apply -m kubeone.yaml -t ../terraform/aws/output.json -y -v
export KUBECONFIG=`pwd`/kkp-demo-cds-kubeconfig
cd ..
```

### Deploy KKP

First we need to decrypt the kkp-config and helm values, put the secret key from secrets.md in `.age.key`.

```bash
export SOPS_AGE_KEY_FILE=`pwd`/.age.txt
cd kubermatic
sops -d -i kubermatic-configuration.yaml
sops -d -i values.yaml
export VERSION=v2.18.0
wget https://github.com/kubermatic/kubermatic/releases/download/${VERSION}/kubermatic-ce-${VERSION}-linux-amd64.tar.gz
tar -xzvf kubermatic-ce-${VERSION}-linux-amd64.tar.gz
./kubermatic-installer deploy --config kubermatic-configuration.yaml --helm-values values.yaml --storageclass aws
cd ..
```

### Prepare other resources for KKP and Flux

```bash
kubectl create secret generic kubeconfig-cluster -n kubermatic --from-file=kubeconfig=`pwd`/kubeone/kkp-demo-cds-kubeconfig --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic kubermatic-values -n kubermatic --from-file=values.yaml=`pwd`/kubermatic/values.yaml --dry-run=client -o yaml | kubectl apply -f -
# Values for helm releases are able to read secret only from same namespace so we need values in all NS
kubectl create secret generic kubermatic-values -n logging --from-file=values.yaml=`pwd`/kubermatic/values.yaml --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic kubermatic-values -n monitoring --from-file=values.yaml=`pwd`/kubermatic/values.yaml --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic kubermatic-values -n iap --from-file=values.yaml=`pwd`/kubermatic/values.yaml --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic kubermatic-values -n kube-system --from-file=values.yaml=`pwd`/kubermatic/values.yaml --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic kubermatic-values -n minio --from-file=values.yaml=`pwd`/kubermatic/values.yaml --dry-run=client -o yaml | kubectl apply -f -
cat .age.txt | kubectl -n kubermatic create secret generic sops-age --from-file=age.agekey=/dev/stdin --dry-run=client -o yaml | kubectl apply -f -
```

### Update DNS records

At this point, you should manage the DNS records the Kubermatic Kubernetes platform.

See the related [documentation](https://docs.kubermatic.com/kubermatic/master/guides/installation/install_kkp_ce/#create-dns-records).

### Initialize Flux v2

```bash
flux bootstrap github --owner=$GITHUB_OWNER --repository=$GITHUB_REPOSITORY \
  --branch=main --personal=true --path flux/clusters/master
```

Your Kubermatic Kubernetes Platform is ready to use now, look around
all deployed services and custom resources in Kubernetes.

More cheat sheets to follow are summarized in [documentation](https://docs.kubermatic.com/kubermatic/master/startio/cheat_sheets).
