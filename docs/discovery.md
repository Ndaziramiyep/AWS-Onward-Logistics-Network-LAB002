# Discovery Report: Highly Available Network for the Onward Logistics Order System

| | |
|---|---|
| **Lab** | Highly Available, Secure Network on AWS (CloudFormation + GitSync) |
| **Name** | Patrick Ndaziramiye |
| **Date** | 26 October 2026 |
| **Client** | Onward Logistics (see the Client Profile) |

---

## 1. What I found

### The client's need

Onward Logistics needs merchants and customers to be able to place and track orders at any time, even on triple-volume sales days or when part of the data center fails, while the internal order processing stays completely hidden from the internet yet still maintainable and up to date.

### Solutions that exist

| Solution | How it works | Trade-off for this client |
|---|---|---|
| **A. Single public server (what they have today)** | One server holds the front end and order services and is reachable from the internet. | *Strength:* cheapest and simplest. *Weakness:* one failure takes everything down, and internal services are exposed. |
| **B. Public/private tiers in one Availability Zone (AZ)** | Front end in a public subnet, internal servers in a private subnet, one NAT gateway for updates. | *Strength:* hides internal servers at low cost. *Weakness:* losing the AZ is a full outage, which fails the CTO's requirement. |
| **C. Multi-AZ tiers with a load balancer, NAT per AZ and SSM Session Manager (chosen)** | Application Load Balancer (ALB) spreads traffic across front ends in two AZs. Internal servers sit in private subnets in two AZs, reach the internet outbound only via NAT, and are administered through Systems Manager (no SSH). | *Strength:* survives the loss of an AZ, no inbound path to internal servers, no keys or open ports. *Weakness:* NAT gateways and the ALB bill hourly, so it costs more than A or B. |

### What happens with no solution

- **Downtime costs revenue and trust.** Outages on peak days lose orders, and merchants who cannot reach the platform move to competitors. A real example: in December 2021 an AWS issue in a single region (us-east-1) disrupted many businesses for hours, and AWS's own post-event summary shows how a dependency failure cascades. Concentrating in one AZ or one server carries the same risk at smaller scale.
- **Exposed internal systems create legal and reputational risk.** The 2019 Capital One breach began with a misconfigured cloud component being reachable and exploited; it led to a US$80 million regulatory penalty and a later settlement with customers. Internal order data (customer addresses, merchant details) falls under privacy obligations, so exposure could mean fines and loss of customers.
- **Shared SSH keys and open admin ports** are a common route in for attackers and make it impossible to say who did what when something goes wrong.
- **Unpatched servers** with no way to download updates accumulate vulnerabilities, while "fixing" that by exposing servers to the internet breaks the security requirement.

### Sources

- AWS, *Summary of the AWS Service Event in the Northern Virginia (US-EAST-1) Region* (Dec 2021): https://aws.amazon.com/message/12721/
- AWS Well-Architected Framework, Reliability Pillar: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html
- AWS Well-Architected Framework, Security Pillar: https://docs.aws.amazon.com/wellarchitected/latest/securitypillar/welcome.html
- AWS Systems Manager, Session Manager: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html
- Amazon VPC pricing (NAT gateway, endpoints): https://aws.amazon.com/vpc/pricing/
- Elastic Load Balancing pricing: https://aws.amazon.com/elasticloadbalancing/pricing/
- AWS CloudFormation Git sync: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/git-sync.html
- US Department of Justice / OCC reporting on the Capital One 2019 incident (public record)

---

## 2. The business value of my solution

### Chosen approach

I chose **Solution C**: a two-AZ VPC with public subnets for the internet-facing tier and private subnets for internal order services. This is the only option that meets all of the leaders' requirements together: it keeps the front end available when an AZ is lost (CTO), makes internal servers unreachable from the internet (Security), lets engineers fix servers and servers update themselves (Operations), and has a small, predictable, explainable bill (Finance). Option A fails on availability and security; option B fails on availability. The extra cost of C is the price of the resilience the business explicitly asked for, and it is far smaller than one lost peak sales day.

### Services I will use

| Service | The job it does | Why this service, used this way |
|---|---|---|
| **AWS CloudFormation + Git sync** | Builds every resource from a template stored in the repository and redeploys on each commit. | Meets the "no console changes" and "rebuild from the repository" requirements; gives an auditable history and repeatable rebuilds. |
| **Amazon VPC (2 AZs, 2 public + 2 private subnets)** | Provides the isolated network and splits it into internet-facing and internal tiers. | Two AZs is the minimum for AZ-failure tolerance; separate tiers allow strict routing rules. |
| **Internet Gateway** | Gives the public subnets a route to and from the internet. | Needed for the ALB and for merchant/customer access; private subnets get no route to it. |
| **NAT Gateway (one per AZ)** | Lets internal servers start outbound connections (updates, SSM) while blocking inbound ones. | Meets "download updates but unreachable". One per AZ avoids a single point of failure and cross-AZ data charges. |
| **Application Load Balancer** | Receives internet traffic and distributes it to healthy front-end servers in both AZs. | Health checks automatically stop sending traffic to a failed server or AZ; gives one stable address. |
| **EC2 Auto Scaling group (Launch Template, Amazon Linux, t3.micro/t2.micro Free Tier eligible)** | Runs front-end servers (page showing my name and lab name preinstalled via user data) and replaces failed ones. | Self-healing and spreads instances across AZs; Free Tier eligible instance type keeps cost low. |
| **EC2 internal servers (one per private subnet)** | Host the internal order services. | One per AZ keeps internal services running if an AZ fails. |
| **Security Groups** | Act as the firewall: front end allows HTTP only from the ALB; ALB allows HTTP from the internet; internal servers allow no inbound from the internet. | Stateful, least-privilege rules by reference to other security groups, not IP addresses. No port 22 anywhere. |
| **AWS Systems Manager Session Manager** | Gives engineers shell access to servers through the AWS API. | No inbound ports, no SSH keys to share, and every session can be logged against an individual identity. |
| **IAM role + instance profile (managed policies only)** | Gives instances permission to register with Systems Manager (`AmazonSSMManagedInstanceCore`). | Meets "no inline policies"; credentials are temporary and never stored on a server. |
| **AWS-standard tags and naming** | Label every resource per the Client Profile. | Supports cost allocation and the company standards. |

### Estimated cost and rejected alternatives

Approximate on-demand figures for us-east-1 (to be confirmed in the AWS Pricing Calculator before the review):

- 2 NAT gateways: about US$0.045/hour each, roughly US$65/month plus data processing. This is the largest item.
- 1 ALB: about US$0.0225/hour, roughly US$16–20/month plus a small usage charge.
- EC2 instances: covered by Free Tier hours for new accounts (limited hours per month across all instances), otherwise a few dollars per instance.
- VPC, subnets, route tables, security groups, IGW, IAM and SSM Session Manager: no charge.

Alternatives rejected:

- **Single NAT gateway:** saves about US$32/month but an AZ loss would cut updates and Session Manager access for the other AZ's servers.
- **SSM interface VPC endpoints instead of NAT:** about 3 endpoints × 2 AZs billed hourly; costs about the same as NAT and still would not allow package downloads from the internet.
- **Bastion host with SSH:** an internet-facing server, open port 22 and shared keys, which violates the Head of Security's requirement.
- **Front end in the private subnets:** would add no extra security because the security group already limits it to ALB traffic, and would raise NAT data costs.

### Who benefits, and how I will know

| Stakeholder | Benefit | How I would know |
|---|---|---|
| **Chief Technology Officer** | Front end stays up if one AZ is lost. | Stop one front-end instance (or simulate AZ loss); the ALB URL keeps returning the page and the target group shows the other AZ healthy. |
| **Head of Security** | Nothing internal is reachable from the internet; no admin ports or shared keys. | Security groups show no inbound rule from `0.0.0.0/0` on internal servers and no port 22 anywhere; internal servers have no public IP; private route tables contain no IGW route. |
| **Head of Operations** | Engineers can still log in and servers can update. | Start a Session Manager session on each internal server and run a package install (e.g. `sudo dnf install -y htop`) successfully. |
| **Finance Lead** | Clear, explainable cost with justified choices. | Cost table above, tag-based cost reporting, and the Pricing Calculator estimate matches the bill. |
| **Merchants and customers** | Reliable ordering, including on sales days. | ALB healthy-host count stays above zero; the page loads at any time. |

### Limits and risks of my design

- **Single region:** losing the whole region would still be an outage. A multi-region design would cost significantly more and is out of scope.
- **ALB is HTTP only unless a certificate is added:** production should use HTTPS with an ACM certificate and a domain name.
- **The lab does not include the real order application, database or WAF,** so application-level and data-layer resilience are not covered.
- **Cost depends on NAT data volume:** heavy update traffic raises the bill; this should be monitored (budgets and alarms).
- **Session Manager depends on the AWS API and NAT:** if both AZ NATs failed, administration would be interrupted; adding SSM VPC endpoints later would reduce this risk at extra cost.
- **Free Tier hours are limited,** so the running cost may exceed US$0 once the account's allowance is used.
