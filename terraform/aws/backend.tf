
terraform {
  backend "s3" {
    key            = "terraform-kkp.tfstate"
    dynamodb_table = "terraform-state-kkp-locks"
    encrypt        = true
  }
}

