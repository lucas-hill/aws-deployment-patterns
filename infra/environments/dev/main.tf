module "vpc" {
  source = "../../modules/vpc"

  name_prefix          = var.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "ecr" {
  source = "../../modules/ecr/"

  name                 = "${var.name_prefix}-go-api"
  image_tag_mutability = "MUTABLE" # dev: allow :latest to move
  force_delete         = true      # dev: allow easy teardown
  scan_on_push         = true
}

module "compute" {
  source = "../../modules/compute"

  name_prefix            = var.name_prefix
  vpc_id                 = module.vpc.vpc_id
  vpc_cidr               = module.vpc.vpc_cidr
  public_subnet_ids      = module.vpc.public_subnet_ids
  private_subnet_ids     = module.vpc.private_subnet_ids
  private_route_table_id = module.vpc.private_route_table_id
  ecr_repository_arn     = module.ecr.repository_arn
  ecr_repository_url     = module.ecr.repository_url
}
