#!/bin/sh

set -euo pipefail

readonly GENERATED_BUCKET_SUFFIX="6qzzv6zqfb0d"
readonly TF_STATE_BUCKET_NAME="tf-state-kkp-$GENERATED_BUCKET_SUFFIX"

echo "Setting up S3 bucket ${TF_STATE_BUCKET_NAME} for storing Terraform state."

set -x

# Create the bucket
aws s3api create-bucket \
  --bucket "${TF_STATE_BUCKET_NAME}" \
  --create-bucket-configuration LocationConstraint=eu-central-1

# Enable AES-256 encryption
aws s3api put-bucket-encryption \
  --bucket "${TF_STATE_BUCKET_NAME}" \
  --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket "${TF_STATE_BUCKET_NAME}" \
  --versioning-configuration Status=Enabled

# Disable public access
aws s3api put-public-access-block \
  --bucket "${TF_STATE_BUCKET_NAME}" \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

set +x

printf "Terraform state bucket name: %s\n" "${TF_STATE_BUCKET_NAME}"

aws dynamodb create-table \
  --table-name terraform-state-kkp-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1

# put empty file in s3 bucket for readiness check in pipeline
temp_file=$(mktemp)
aws s3 cp $temp_file s3://${TF_STATE_BUCKET_NAME}/bucket-ready
rm -f $temp_file