terraform {
  backend "s3" {
    bucket         = "lucas-tf-state-281639842765"
    key            = "dev/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "lucas-tf-state-lock"
    encrypt        = true
  }
}
