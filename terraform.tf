terraform {
  required_version = ">= 1.7.0"

}

provider "aws" {
  profile = var.profile
  region  = var.region
}