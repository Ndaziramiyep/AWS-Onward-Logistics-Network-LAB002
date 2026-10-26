# Onward Logistics: Highly Available, Secure Order System Network

Student: Patrick Ndaziramiye

CloudFormation project that moves the Onward Logistics order system from a single server into a two-zone AWS network. It is deployed with CloudFormation Git sync from this repository.

## What it builds

- A VPC with two public and two private subnets across two Availability Zones.
- An internet-facing Application Load Balancer and an Auto Scaling group of Amazon Linux front-end servers. Each shows the student name and lab name.
- Two internal servers in private subnets with no internet inbound path, one NAT Gateway per zone for outbound updates only.
- Remote administration with AWS Systems Manager Session Manager. No SSH port, no key pairs.
- Least-privilege security groups and an IAM role that uses a managed policy only (no inline policies).

See [docs/architecture.md](docs/architecture.md) for the diagram, traffic rules, failure behaviour and costs.

## Repository layout

```
onward-logistics-network/
├── README.md
├── .gitignore
├── .github/workflows/lint.yml        cfn-lint on every push
├── bootstrap/
│   └── gitsync-role.yaml             one-time IAM role for Git sync
├── infrastructure/
│   ├── template.yaml                 the whole network, servers and load balancer
│   └── deployment.yaml               Git sync deployment file (parameters and tags)
├── docs/
│   ├── discovery.md                  Stage 1 report, committed first
│   ├── architecture.md               diagram, rules, failure table, cost
│   ├── deployment-guide.md           step by step Git sync setup
│   └── verification-checklist.md     the client's checks and requirement mapping
└── scripts/
    └── verify.sh                     prints proof for the live review
```

## Quick start

1. Push this repository to GitHub (discovery report committed first).
2. Create the GitHub connection and deploy `bootstrap/gitsync-role.yaml`.
3. In CloudFormation choose **Create stack, Sync from Git** and set the deployment file to `infrastructure/deployment.yaml`.
4. Open the stack Outputs and visit `FrontEndUrl`.

Full instructions are in [docs/deployment-guide.md](docs/deployment-guide.md).

## Before you deploy

- Edit `infrastructure/deployment.yaml` so the tags and names match the Client Profile standards.
- Use `InstanceType: t2.micro` if `t3.micro` is not Free Tier eligible in your region.
- NAT Gateways and the load balancer bill by the hour. Delete the stack when you finish.

## Security notes

No credentials, keys or secrets are stored in this repository. `.gitignore` blocks common key files.
