#!/usr/bin/env bash
# Verification helper for the live review. Needs the AWS CLI and credentials for the account.
# Usage: ./scripts/verify.sh <stack-name> [region]
set -euo pipefail
STACK="${1:?Usage: $0 <stack-name> [region]}"
REGION="${2:-${AWS_REGION:-us-east-1}}"
out() { aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
        --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text; }

URL=$(out FrontEndUrl); SG=$(out InternalSecurityGroupId)
I1=$(out InternalServer1Id); I2=$(out InternalServer2Id)

echo "== Check 1: front end reachable from the internet =="
curl -s --max-time 10 "$URL" | grep -E "Name:|Lab:|Served from" || echo "FAILED to reach $URL"

echo; echo "== Check 2: no inbound rule from the internet on internal servers =="
OPEN=$(aws ec2 describe-security-groups --group-ids "$SG" --region "$REGION" \
  --query "SecurityGroups[0].IpPermissions[?contains(IpRanges[].CidrIp, '0.0.0.0/0')]" --output text)
[ -z "$OPEN" ] && echo "PASS: no 0.0.0.0/0 ingress on $SG" || echo "FAIL: open rule found: $OPEN"
for I in "$I1" "$I2"; do
  IP=$(aws ec2 describe-instances --instance-ids "$I" --region "$REGION" \
       --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
  echo "$I public IP: $IP (expected None)"
done

echo; echo "== Check 3: internal servers downloaded a package through NAT =="
for I in "$I1" "$I2"; do
  CMD=$(aws ssm send-command --instance-ids "$I" --region "$REGION" \
        --document-name AWS-RunShellScript \
        --parameters 'commands=["cat /var/log/internal-bootstrap.log | tail -3","rpm -q htop"]' \
        --query "Command.CommandId" --output text)
  sleep 5
  echo "--- $I"
  aws ssm get-command-invocation --command-id "$CMD" --instance-id "$I" --region "$REGION" \
    --query "StandardOutputContent" --output text
done

echo; echo "== Check 4: Session Manager can reach every internal server (no SSH, no keys) =="
aws ssm describe-instance-information --region "$REGION" \
  --query "InstanceInformationList[].[InstanceId,PingStatus]" --output table
echo "Interactive login:  aws ssm start-session --target $I1 --region $REGION"
