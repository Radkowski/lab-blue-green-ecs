terraform {
  required_providers {
    lambdabased = {
      source = "thetradedesk/lambdabased"
    }
  }
}

provider "lambdabased" {
  region = var.REGION
}