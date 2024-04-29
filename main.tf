terraform {
  cloud {
    organization = "Lennar-sample"

    workspaces {
      name = "vault-workspace"
    }
  }
}

provider "vault" {
  address = var.vault_url
}

provider "aws" {
  region = "us-east-1"
}

## Create Vault KV2 Secret
resource "vault_mount" "kv2" {
  path        = "kv2"
  type        = "kv-v2"
  description = "KV2 secret engine"
}

resource "vault_kv_secret_v2" "mysecret" {
  mount               = vault_mount.kv2.path
  name               = "mysecret"
  cas                = 1
  delete_all_versions = true

  data_json = <<-EOT
    {
      "key": "ABC1234"
    }
  EOT
}

## Create Vault Policy
resource "vault_policy" "read_mysecret" {
  name = "read-mysecret"

  policy = <<EOT
path "kv2/data/mysecret" {
  capabilities = ["read"]
}
EOT
}

## Create IAM Role
resource "aws_iam_role" "lennar_vault_role" {
  name = "lennar_vault_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

## Configure AWS Auth Method
resource "vault_auth_backend" "aws" {
  type = "aws"
  path = "aws"
}

resource "vault_aws_auth_backend_role" "vault_role" {
  backend                        = vault_auth_backend.aws.path
  role                           = "lennar_vault_role"
  auth_type                      = "iam"
  bound_iam_principal_arns        = aws_iam_role.lennar_vault_role.arn
  token_policies                 = [vault_policy.read_mysecret.name]
  token_ttl                      = 3600
  token_max_ttl                  = 7200
  token_num_uses                 = 12
}

## Retrieve Secret
data "vault_kv_secret_v2" "mysecret" {
  mount = vault_mount.kv2.path
  name = "mysecret"
}

output "secret_key" {
  value = data.vault_kv_secret_v2.mysecret.data.data.key
}