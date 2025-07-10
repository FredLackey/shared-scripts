# AWS CloudFront Teardown Script

## 🎯 What Does This Do?

This Bash script is a powerful and destructive utility designed to **find and permanently delete** all AWS resources associated with a specific CloudFront deployment. It identifies resources based on the S3 bucket name used as the origin, making it a comprehensive cleanup tool for deployments created by its companion `deploy-cloudfront.sh` script (not included).

**WARNING:** This script is DESTRUCTIVE and will permanently delete AWS resources. This action cannot be undone.

## 🎯 Usage Scenarios

This script is intended for developers and system administrators who need to:

-   **Completely remove** a CloudFront-S3 web application deployment.
-   **Clean up test or staging environments** to avoid ongoing AWS costs.
-   **Automate the teardown process** to ensure no resources are accidentally left running.
-   **Decommission a project** and ensure all related cloud infrastructure is properly removed.

## 📋 The Problem This Solves

**The Scenario:**
You have deployed a static website using S3 and CloudFront. The deployment includes an S3 bucket, a CloudFront distribution, and an Origin Access Control (OAC) to secure the bucket. Now, you need to delete this entire stack.

**The Challenge:**
-   Deleting AWS resources in the correct order is critical. You can't delete an S3 bucket used by a CloudFront distribution.
-   CloudFront distributions cannot be deleted immediately. They must first be disabled, a process that can take **15-20 minutes** to propagate across all AWS edge locations.
-   Manually finding and deleting each interconnected resource (Distribution, OAC, S3 Bucket) is time-consuming and prone to errors, potentially leaving orphaned resources that incur costs.

**The Solution:**
This script automates the entire teardown process. It correctly sequences the deletion operations, patiently waits for CloudFront to disable, and cleans up all related components, ensuring a complete and tidy removal.

## 🔧 How It Works

1.  **Gathers Information** - Prompts the user for their AWS Access Key, Secret Key, Region, and the S3 Bucket Name of the deployment to be deleted.
2.  **Finds Associated Resources** - It queries AWS to find the CloudFront distribution, Origin Access Control (OAC), and the S3 bucket linked to the provided bucket name.
3.  **Shows a Plan and Confirms** - The script lists all the resources it found and asks for a final, explicit confirmation (`yes`) before proceeding with any deletion.
4.  **Disables CloudFront Distribution** - It sends a request to disable the distribution and then polls AWS until it confirms the status is "Deployed" and "Disabled." This is the step that takes the most time.
5.  **Deletes CloudFront Distribution** - Once disabled, it deletes the distribution, with retry logic in case of delays.
6.  **Deletes Origin Access Control** - It deletes the OAC, which is now no longer in use by the distribution.
7.  **Deletes S3 Bucket** - Finally, it empties and deletes the S3 bucket using the `--force` option.
8.  **Logs Everything** - All actions, progress, and errors are printed to the console for real-time monitoring.

## 📁 What's Included

This folder contains:
-   `cloudfront-remove.sh` - The main Bash script that performs the teardown.
-   `README.md` - This documentation file.

## �� What You'll Need

Before using this script, you'll need:

-   **AWS CLI** - Must be installed and accessible in your system's `PATH`.
-   **AWS Credentials** - An AWS Access Key ID and Secret Access Key for an IAM user with sufficient permissions to manage CloudFront, OAC, and S3.
-   **Target S3 Bucket Name** - You must know the exact name of the S3 bucket at the heart of the deployment you wish to delete.

### Required IAM Permissions (Example Policy)
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudfront:GetDistribution",
                "cloudfront:GetDistributionConfig",
                "cloudfront:UpdateDistribution",
                "cloudfront:DeleteDistribution",
                "cloudfront:ListDistributions",
                "cloudfront:GetOriginAccessControl",
                "cloudfront:DeleteOriginAccessControl",
                "cloudfront:ListOriginAccessControls"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:DeleteBucket",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:HeadBucket"
            ],
            "Resource": [
                "arn:aws:s3:::YOUR_BUCKET_NAME_HERE",
                "arn:aws:s3:::YOUR_BUCKET_NAME_HERE/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "sts:GetCallerIdentity",
            "Resource": "*"
        }
    ]
}
```
*Note: Replace `YOUR_BUCKET_NAME_HERE` with the actual bucket name, or use a wildcard for broader permissions if needed.*

## 🚀 Getting Started

### Step 1: Prepare Your Environment
1.  Ensure the AWS CLI is installed and configured in your terminal environment.
2.  Open a terminal or command prompt.

### Step 2: Run the Script
1.  Navigate to the directory containing the script: `cd aws-cloudfront-teardown`
2.  Make the script executable (you only need to do this once):
    ```bash
    chmod +x cloudfront-remove.sh
    ```
3.  Execute the script:
    ```bash
    ./cloudfront-remove.sh
    ```
4.  Follow the on-screen prompts to provide your AWS credentials, region, and the target S3 bucket name.
5.  Carefully review the list of resources that will be deleted.
6.  Type `yes` and press Enter to confirm and begin the deletion process.

## ⚠️ Important Notes

-   **DESTRUCTIVE ACTION**: This script permanently deletes data and infrastructure. There is no undo. Double-check the bucket name and region before confirming.
-   **LONG RUNNING TIME**: The CloudFront disabling step can take **15-20 minutes** or more. The script will appear to hang during this time, but it is polling in the background. Be patient and do not interrupt it.
-   **Permissions**: The script will fail if the provided AWS credentials do not have the necessary permissions to perform the required actions.
-   **Network Connectivity**: The script requires a stable internet connection to communicate with AWS APIs.

## 🛠️ Troubleshooting

### Common Issues:

**"AWS credentials are invalid"**
-   You may have entered the Access Key ID or Secret Access Key incorrectly.
-   The IAM user associated with the credentials may be disabled or deleted.

**"No resources found"**
-   Verify you have entered the correct S3 bucket name and AWS region.
-   The resources may have already been deleted.

**Deletion Errors or Timeouts**
-   This can happen if the IAM user is missing permissions for a specific action (e.g., `cloudfront:DeleteDistribution`).
-   Another process or user might be modifying the resources while the script is running.
-   If the script fails repeatedly, you may need to log into the AWS Management Console to identify the conflict and delete the resources manually.

## 📞 Need Help?

If you run into problems or have questions about this script:

### 📧 Contact Information

**Fred Lackey**  
📧 Email: [Fred.Lackey@gmail.com](mailto:Fred.Lackey@gmail.com)  
🌐 Website: [@FredLackey.com](https://FredLackey.com) 