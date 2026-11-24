resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "clinicflow-${var.environment}-vpc"
    Project     = "clinicflow"
    Environment = var.environment
    ManagedBy   = "terraform"
  }

}

locals {
  public_subnets = {
    public_a = {
      cidr_number = var.subnet_offsets.public[0]
      az          = var.availability_zones[0]
    }

    public_b = {
      cidr_number = var.subnet_offsets.public[1]
      az          = var.availability_zones[1]
    }
  }
}

resource "aws_subnet" "public" {
  for_each          = local.public_subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value.cidr_number)
  availability_zone = each.value.az

  tags = {
    Name        = "clinicflow-${var.environment}-${each.key}"
    Project     = "clinicflow"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

locals {
  private_web_subnets = {
    web_a = {
      cidr_number = var.subnet_offsets.web[0]
      az          = var.availability_zones[0]
    }

    web_b = {
      cidr_number = var.subnet_offsets.web[1]
      az          = var.availability_zones[1]
    }
  }
}

resource "aws_subnet" "private_web" {
  for_each          = local.private_web_subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value.cidr_number)
  availability_zone = each.value.az

  tags = {
    Name        = "clinicflow-${var.environment}-${each.key}"
    Project     = "clinicflow"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

locals {
  private_api_subnets = {
    api_a = {
      cidr_number = var.subnet_offsets.api[0]
      az          = var.availability_zones[0]
    }

    api_b = {
      cidr_number = var.subnet_offsets.api[1]
      az          = var.availability_zones[1]
    }
  }
}

resource "aws_subnet" "private_api" {
  for_each                = local.private_api_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value.cidr_number)
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name        = "clinicflow-${var.environment}-${each.key}"
    Project     = "clinicflow"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

locals {
  private_data_subnets = {
    data_a = {
      cidr_number = var.subnet_offsets.data[0]
      az          = var.availability_zones[0]
    }

    data_b = {
      cidr_number = var.subnet_offsets.data[1]
      az          = var.availability_zones[1]
    }
  }
}

resource "aws_subnet" "private_data" {
  for_each                = local.private_data_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value.cidr_number)
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name        = "clinicflow-${var.environment}-${each.key}"
    Project     = "clinicflow"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "clinicflow-${var.environment}-igw"
    Project     = "clinicflow"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "clinicflow-${var.environment}-public-rt"
    Project     = "clinicflow"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_data" {
  vpc_id = aws_vpc.main.id
  # Explicitly enforce no routes beyond AWS's implicit local route.
  route = []

  tags = {
    Name        = "clinicflow-${var.environment}-private-data-rt"
    Project     = "clinicflow"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_route_table_association" "private_data" {
  for_each       = aws_subnet.private_data
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_data.id
}

# Private Web Route Table
resource "aws_route_table" "private_web" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }

  tags = {
    Name        = "clinicflow-${var.environment}-web-rt"
    Project     = "clinicflow"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_route_table_association" "private_web" {
  for_each = aws_subnet.private_web

  subnet_id      = each.value.id
  route_table_id = var.nat_gateway_count == 2 && each.key == "web_b" ? aws_route_table.private_web_b[0].id : aws_route_table.private_web.id
}

resource "aws_route_table" "private_api" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }

  tags = {
    Name        = "clinicflow-${var.environment}-api-rt"
    Project     = "clinicflow"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_route_table_association" "private_api" {
  for_each = aws_subnet.private_api

  subnet_id      = each.value.id
  route_table_id = var.nat_gateway_count == 2 && each.key == "api_b" ? aws_route_table.private_api_b[0].id : aws_route_table.private_api.id
}

resource "aws_eip" "nat_a" {
  domain = "vpc"

  tags = {
    Name        = "clinicflow-${var.environment}-nat-eip-a"
    Project     = "clinicflow"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public["public_a"].id

  tags = {
    Name        = "clinicflow-${var.environment}-nat-a"
    Project     = "clinicflow"
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_eip" "nat_b" {
  count  = var.nat_gateway_count == 2 ? 1 : 0
  domain = "vpc"
  tags   = { Name = "clinicflow-${var.environment}-nat-eip-b" }
}

resource "aws_nat_gateway" "nat_b" {
  count         = var.nat_gateway_count == 2 ? 1 : 0
  allocation_id = aws_eip.nat_b[0].id
  subnet_id     = aws_subnet.public["public_b"].id
  tags          = { Name = "clinicflow-${var.environment}-nat-b" }
  depends_on    = [aws_internet_gateway.main]
}

resource "aws_route_table" "private_web_b" {
  count  = var.nat_gateway_count == 2 ? 1 : 0
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_b[0].id
  }
  tags = { Name = "clinicflow-${var.environment}-web-b-rt" }
}

resource "aws_route_table" "private_api_b" {
  count  = var.nat_gateway_count == 2 ? 1 : 0
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_b[0].id
  }
  tags = { Name = "clinicflow-${var.environment}-api-b-rt" }
}
