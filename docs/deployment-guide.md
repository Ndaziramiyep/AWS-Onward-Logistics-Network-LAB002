# Deployment guide (CloudFormation Git sync)

The template creates every network resource. Git sync itself needs three small prerequisites that cannot live inside the template it deploys: the GitHub connection, the Git sync IAM role, and the stack that points at the repository.

## Step 0. Commit the discovery report first

```bash
git init -b main
git add docs/discovery.md
git commit -m "docs: add discovery report before build"
git add .
git commit -m "feat: add CloudFormation network, Git sync deployment file and docs"
```

Create an empty repository on GitHub, then:

```bash
git remote add origin https://github.com/<your-username>/onward-logistics-network.git
git push -u origin main
```

## Step 1. Create the GitHub connection (one time)

1. AWS Console, open **Developer Tools**, then **Settings**, then **Connections** (AWS CodeConnections).
2. Choose **Create connection**, provider **GitHub**, name it `onward-logistics-github`.
3. Choose **Connect to GitHub**, sign in, install the AWS Connector for GitHub app, and select your repository.
4. Wait until the status is **Available**.

## Step 2. Create the Git sync IAM role (one time)

Deploy `bootstrap/gitsync-role.yaml` with CloudFormation (console or CLI):

```bash
aws cloudformation deploy \
  --stack-name onward-logistics-gitsync-prereq \
  --template-file bootstrap/gitsync-role.yaml \
  --capabilities CAPABILITY_NAMED_IAM
```

Copy the `GitSyncRoleArn` output.

## Step 3. Create the stack from Git

1. Open **CloudFormation**, then **Create stack**, then **With new resources (standard)**.
2. Under **Prepare template** choose **Sync from Git**.
3. Stack name: `onward-logistics-lab`.
4. Git provider: **GitHub**. Select the connection from Step 1, the repository and branch `main`.
5. **Deployment file path:** `infrastructure/deployment.yaml`
6. **IAM role:** choose the role from Step 2 (use the ARN output).
7. Choose **Submit** and wait for the stack to reach `CREATE_COMPLETE` (about 5 to 8 minutes, mostly NAT Gateways).

Open the stack **Outputs** tab. `FrontEndUrl` is the address of the front end.

## Step 4. Change anything later

Edit the template or `deployment.yaml`, commit, and push to `main`. Git sync detects the commit and updates the stack. Nothing is changed in the console.

## Rebuild from the repository

Delete the stack, then repeat Step 3. The same commit always produces the same infrastructure.

## Clean up to stop charges

NAT Gateways and the load balancer bill by the hour. When finished, delete the stack `onward-logistics-lab` (this also removes the Git sync link), then delete `onward-logistics-gitsync-prereq` if you no longer need it.

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| Stack fails on instance type | Use `t2.micro` in `deployment.yaml` if `t3.micro` is not Free Tier eligible in your account or region. |
| Front-end URL returns 502 or 503 | Servers are still installing Apache. Wait 2 to 3 minutes for the health checks to pass. |
| Session Manager shows no instances | Wait a few minutes after launch. Internal servers need their NAT route and the SSM role to register. |
| Git sync permission error | Review the permissions in `bootstrap/gitsync-role.yaml` and the stack events for the denied action. |
| Sync does not start | Confirm the connection status is Available and the deployment file path is correct. |
