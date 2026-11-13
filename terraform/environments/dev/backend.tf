terraform {
  backend "s3" {
    bucket       = "clinicflow-tfstate-d690c946fd00f40158a4736f03"
    key          = "dev/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true

  }
}