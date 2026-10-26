# Verification checklist for the live review

Run `./scripts/verify.sh onward-logistics-lab <region>` to print most of this at once, or follow the manual steps.

| # | Client check | How to prove it | Expected result |
|---|---|---|---|
| 1 | Front end reachable from the internet, always | Open `FrontEndUrl` in a browser. Refresh several times. | Page shows **Patrick Ndaziramiye** and the lab name. The "Served from" line alternates between two instance IDs and two zones. |
| 2 | Nobody on the internet can start a connection to an internal server | EC2 console: internal instances have no public IPv4. Security group `internal-sg` has no `0.0.0.0/0` rule. Private route tables have no Internet Gateway route. | All three are true. |
| 3 | Internal servers can download a package | Start a session on an internal server and run `rpm -q htop` and `tail /var/log/internal-bootstrap.log`. Optionally run `sudo dnf install -y jq`. | htop is installed and the log says "package download OK". |
| 4 | Engineers administer each internal server without open ports | `aws ssm start-session --target <instance-id>` for both internal servers (commands are in the stack Outputs). Show that no security group has port 22. | A shell opens on each server with no key pair. |
| 5 | Explain what happens if a component goes down | Terminate one front-end instance, or stop one, while refreshing the URL. | The page keeps loading. The target group shows one unhealthy target, then Auto Scaling launches a replacement. |
| 6 | Explain cost and rejected alternatives | Use the cost table in `docs/architecture.md` and the Pricing Calculator. | Two NAT Gateways and the load balancer are the main costs. Four rejected alternatives are named. |
| 7 | Rebuild from the repository | Delete the stack, then recreate it from Git sync. | The same infrastructure returns with no console edits. |

## Mandatory technical requirements

| Requirement | Where it is met |
|---|---|
| Everything in CloudFormation | `infrastructure/template.yaml` |
| Deployed by Git sync | `infrastructure/deployment.yaml` and `docs/deployment-guide.md` |
| Highly available | Two zones, ALB, Auto Scaling group, NAT Gateway per zone, one internal server per zone |
| Security matches the Head of Security | No inbound path to internal servers, no port 22, no key pairs |
| Free Tier Amazon Linux with name and lab page | Amazon Linux 2023, `t3.micro` or `t2.micro`, page written by `FrontEndLaunchTemplate` user data |
| Remote admin without inbound SSH | Session Manager with `AmazonSSMManagedInstanceCore` |
| Company standards, naming and tags | `${ProjectName}-${Environment}-<resource>` names, stack tags in `deployment.yaml` |
| No inline policies | Only an AWS managed policy on the instance role. Git sync role uses a managed policy. |
