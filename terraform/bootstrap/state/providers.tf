provider "aws" {
  region = "ap-southeast-2"
  default_tags {
    tags = { Project = "clinicflow", Environment = "shared", Owner = "platform", CostCentre = "capstone", ManagedBy = "terraform" }
  }
}
