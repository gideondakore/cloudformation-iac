# Infrastructure as Code (IaC) Templates

A personal repository of Infrastructure as Code templates for provisioning and managing AWS resources using CloudFormation.

---

## Repository Structure

```
.
├── cloudformation/
│   ├── networking/          # VPCs, Subnets, Security Groups, Route Tables
│   ├── compute/             # EC2, Auto Scaling Groups, Launch Templates
│   ├── storage/             # S3 Buckets, EBS Volumes, EFS
│   ├── database/            # RDS, DynamoDB, ElastiCache
│   ├── serverless/          # Lambda, API Gateway, SQS, SNS
│   ├── security/            # IAM Roles, Policies, KMS Keys
│   ├── monitoring/          # CloudWatch, Alarms, Dashboards
│   └── nested-stacks/       # Reusable nested stack modules
└── README.md
```

---

## Prerequisites

Before deploying any templates, ensure you have the following set up:

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) installed and configured
- An AWS account with appropriate IAM permissions
- AWS CLI configured with your credentials:

```bash
aws configure
```

---

## Deploying a Template

### Using the AWS CLI

```bash
aws cloudformation create-stack \
  --stack-name <your-stack-name> \
  --template-body file://<path-to-template>.yaml \
  --parameters ParameterKey=EnvType,ParameterValue=prod \
  --capabilities CAPABILITY_NAMED_IAM
```

### Using a Parameters File

```bash
aws cloudformation create-stack \
  --stack-name <your-stack-name> \
  --template-body file://<path-to-template>.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_NAMED_IAM
```

### Updating an Existing Stack

```bash
aws cloudformation update-stack \
  --stack-name <your-stack-name> \
  --template-body file://<path-to-template>.yaml \
  --parameters ParameterKey=EnvType,ParameterValue=prod \
  --capabilities CAPABILITY_NAMED_IAM
```

### Deleting a Stack

```bash
aws cloudformation delete-stack \
  --stack-name <your-stack-name>
```

---

## Template Conventions

All templates in this repository follow these conventions:

- Written in **YAML** for readability
- Include a `Description` field explaining the template's purpose
- Use `Parameters` for all environment-specific values (no hardcoded values)
- Use `Conditions` for environment-based resource creation (e.g. `prod` vs `test`)
- Use `Outputs` to export key resource values for cross-stack references
- Resources are tagged with at minimum:

```yaml
Tags:
  - Key: Environment
    Value: !Ref EnvType
  - Key: ManagedBy
    Value: CloudFormation
  - Key: Repository
    Value: iac-templates
```

---

## Template Anatomy

Each template is structured following the standard CloudFormation sections:

```
AWSTemplateFormatVersion  →  always 2010-09-09
Description               →  what this template does
Metadata                  →  parameter groupings and notes
Parameters                →  inputs (environment, instance type, etc.)
Rules                     →  cross-parameter validation
Mappings                  →  region/environment lookup tables
Conditions                →  if/else logic (prod vs test)
Transform                 →  macros e.g. AWS::Serverless (if applicable)
Resources                 →  infrastructure being provisioned
Outputs                   →  exported values for other stacks to consume
```

---

## Environments

Templates support the following environment types via the `EnvType` parameter:

| Environment | Description                           |
| ----------- | ------------------------------------- |
| `dev`       | Local development and experimentation |
| `test`      | Testing and QA workloads              |
| `staging`   | Pre-production environment            |
| `prod`      | Live production environment           |

---

## Cross-Stack References

Some templates export values for use by other stacks. Export names follow the convention:

```
{StackName}-{ResourceType}-{Attribute}
```

For example:

```yaml
Export:
  Name: !Sub "${AWS::StackName}-VpcId"
```

To use an exported value in another stack:

```yaml
VpcId: !ImportValue MyNetworkStack-VpcId
```

---

## Resources

- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [CloudFormation Template Reference](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-reference.html)
- [AWS CLI CloudFormation Reference](https://docs.aws.amazon.com/cli/latest/reference/cloudformation/)
- [CloudFormation Linter (cfn-lint)](https://github.com/aws-cloudformation/cfn-lint)

---

## Author

**Gideon Dakore**
