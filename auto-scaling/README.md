# Auto Scaling Lab

Highly available, auto-scaling web tier deployed with CloudFormation GitSync.

## Architecture

- **VPC** (`10.20.0.0/16`) across two Availability Zones
- **2 public subnets** — host the internet-facing ALB and the NAT Gateway
- **2 private subnets** — host the EC2 web servers (no public IPs, no inbound SSH)
- **NAT Gateway** — outbound internet for package installs from private subnets
- **ALB** — internet-facing, round-robin (stickiness disabled), HTTP :80
- **Launch Template** — Amazon Linux 2023 (latest AMI via SSM), Apache + `stress-ng` installed by UserData, IMDSv2 enforced
- **ASG** — Min 1 / Desired 1 / Max 4, spans both private subnets, ELB health checks
- **Scaling policy** — target tracking on average CPU at **30%** (scales out above, scales back in when load drops — extra credit)

Each instance serves a page showing its **instance ID, private IP, and AZ**, so traffic distribution and scaling are visible during the demo.

## Deploy (GitSync)

1. Push this repo to GitHub.
2. In the CloudFormation console: **Stacks → Create stack → Sync from Git**.
3. Point the sync configuration at `param.yml` (deployment file) on branch `main`.
4. GitSync deploys the stack and re-syncs on every push.

## Demo / Validation

1. Get the endpoint from stack outputs (`AlbUrl`) and open it in a browser.
2. Refresh (or `curl` in a loop) — instance ID changes once ≥2 instances are in service:
   ```bash
   for i in {1..10}; do curl -s http://<ALB_DNS>/ | grep -oP 'i-[0-9a-f]+'; done
   ```
3. Trigger scale-out: connect with **SSM Session Manager** (no SSH needed) and run:
   ```bash
   sudo stress-ng --cpu 0 --cpu-load 90 --timeout 600s
   ```
4. Watch: CloudWatch `CPUUtilization` climbs past 30% → ASG activity shows new
   instances launching → they register in the target group automatically →
   refreshing the ALB URL shows new instance IDs.
5. Stop the stress test — target tracking scales the group back in (scale-in demo).

## Cost / Security Notes

- Single NAT Gateway (vs one per AZ) keeps lab cost down.
- `t3.micro` instances; low CPU target (30%) makes scale-out easy to trigger cheaply.
- Instance SG accepts HTTP **only from the ALB SG**; no SSH ingress at all.
- IMDSv2 required; instance role limited to `AmazonSSMManagedInstanceCore`.
