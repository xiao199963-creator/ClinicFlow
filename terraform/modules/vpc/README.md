# ClinicFlow network

Shared across all three environment roots. Data route tables have no default route. Database security groups need no egress rule because responses to accepted connections are stateful.

| Input | Meaning |
|---|---|
| vpc_cidr | Environment /16 |
| environment | Resource name/tag prefix only |
| availability_zones | Two distinct AZs |
| nat_gateway_count | 1 or 2, explicit environment setting |
| subnet_offsets | Two distinct /24 offsets per public/web/api/data tier |

| Output | Meaning |
|---|---|
| vpc_id | VPC ID |
| public_subnet_ids | Public subnets by stable key |
| private_web_subnet_ids | Web subnets by stable key |
| private_api_subnet_ids | App subnets by stable key |
| private_data_subnet_ids | Isolated database subnets by stable key |
| private_route_table_ids | Web/App/Data tables for S3 gateway endpoint |

PDF target offsets are public `[0,1]`, web `[10,11]`, api `[20,21]`, data `[30,31]`. The root's legacy defaults deliberately remain `[1,2]`, `[3,4]`, `[5,6]`, `[7,8]` until the existing network migration is approved. Target examples explicitly set the PDF values. Never apply them to an existing state without the migration review in `docs/phase-2.5-review.md`.

Endpoints live in a separate module to avoid a VPC → security group → VPC dependency cycle.
