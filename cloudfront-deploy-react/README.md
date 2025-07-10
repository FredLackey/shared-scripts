# AWS CloudFront Deployment Script for Vite/React

## 🎯 What Does This Do?

This Bash script provides a complete, one-stop solution for deploying a Vite-based static web application to AWS. It automates the entire process, from provisioning the necessary cloud infrastructure to building and deploying your application code.

The script is **idempotent**, meaning you can run it multiple times without causing issues. On its first run, it creates a secure, private S3 bucket and a CloudFront distribution configured with Origin Access Control (OAC). On subsequent runs, it intelligently finds the existing resources, deploys the latest version of your application, and invalidates the CloudFront cache to ensure users see the new content immediately.

## 🎯 Usage Scenarios

This script is ideal for developers who want to:

-   **Automate the entire deployment process** for a Vite project to AWS.
-   **Quickly set up new hosting environments** for staging, testing, or production.
-   **Ensure a secure and modern setup** using CloudFront's Origin Access Control (OAC) instead of legacy methods.
-   **Simplify repetitive deployment tasks** into a single command.

## 📋 The Problem This Solves

**The Scenario:**
You have a Vite project ready for the web. You want to host it on AWS using S3 for storage and CloudFront as a CDN for performance and security.

**The Challenge:**
-   Manually creating and configuring AWS resources is complex. You need to create an S3 bucket, lock it down for private access, create an Origin Access Control (OAC), create a CloudFront distribution, link them correctly, and set up a bucket policy.
-   The process is tedious and prone to misconfiguration, which can lead to security vulnerabilities (like a public S3 bucket) or a non-working website.
-   Deploying updates requires building the app, uploading files to S3, and creating a CloudFront invalidation—all separate, manual steps.
-   CloudFront distribution creation can take **10-15 minutes**, requiring you to wait and monitor the process.

**The Solution:**
This script automates every step. It handles resource provisioning, application building, file synchronization, and cache invalidation. It enforces best practices by creating a private S3 bucket accessible only by CloudFront via OAC, giving you a secure, performant, and production-ready setup with a single command.

## 🔧 How It Works

1.  **Finds Project** - Checks for a `vite.config.js` or `vite.config.ts` file. If not found, it prompts for the correct project path.
2.  **Gathers Information** - Prompts for your AWS Access Key, Secret Key, Region, and a unique S3 Bucket Name for hosting.
3.  **Builds the Application** - Runs `npm run build` in your project directory to compile the static assets.
4.  **Provisions S3 Bucket** - If the S3 bucket doesn't exist, it creates one and applies a public access block to ensure it remains private.
5.  **Provisions CloudFront** - It checks for an existing, correctly configured CloudFront distribution.
    -   If one is found, it uses it.
    -   If not, it creates a new Origin Access Control (OAC) and a new CloudFront distribution. It then waits for the distribution to be fully deployed.
6.  **Applies Bucket Policy** - It generates and applies the necessary S3 bucket policy to grant `s3:GetObject` permission to the CloudFront distribution.
7.  **Syncs Files** - It uploads the contents of your `dist` folder to the S3 bucket.
8.  **Invalidates Cache** - It creates a CloudFront invalidation for `/*` to force edge locations to fetch the latest version of your files.

## 📁 What's Included

This folder contains:
-   `cloudfront-deploy-react.sh` - The main Bash script that performs the deployment.
-   `README.md` - This documentation file.

## �� What You'll Need

Before using this script, you'll need:

-   **AWS CLI** - Must be installed and accessible in your system's `PATH`.
-   **Node.js and npm** - Required to build the Vite application.
-   **A Vite Project** - A functional Vite project with a `build` script in its `package.json`.
-   **AWS Credentials** - An AWS Access Key ID and Secret Access Key for an IAM user with sufficient permissions.

### Required IAM Permissions (Example Policy)
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudfront:CreateDistribution",
                "cloudfront:CreateInvalidation",
                "cloudfront:CreateOriginAccessControl",
                "cloudfront:GetDistribution",
                "cloudfront:GetInvalidation",
                "cloudfront:ListDistributions"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:CreateBucket",
                "s3:ListBucket",
                "s3:GetBucketLocation",
                "s3:PutBucketPolicy",
                "s3:PutBucketPublicAccessBlock",
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
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
1.  Ensure the AWS CLI, Node.js, and npm are installed.
2.  Open a terminal or command prompt.

### Step 2: Run the Script
1.  Make the script executable (you only need to do this once):
    ```bash
    chmod +x cloudfront-deploy-react.sh
    ```
2.  Execute the script from your Vite project's root directory:
    ```bash
    /path/to/script/cloudfront-deploy-react.sh
    ```
    Alternatively, run it from its own directory and provide the path to your project when prompted.
    ```bash
    ./cloudfront-deploy-react.sh
    ```
3.  Follow the on-screen prompts to provide your AWS credentials, region, and desired S3 bucket name.
4.  The script will now build and deploy your application. Be patient, as the initial CloudFront setup can take 10-15 minutes.

## ⚠️ Important Notes

-   **Long First Run**: The initial deployment is slow because creating a CloudFront distribution takes time. Subsequent deployments will be much faster.
-   **Idempotent**: You can safely run this script multiple times. It will detect existing resources and simply update the application files.
-   **Permissions**: The script will fail if the provided AWS credentials do not have the necessary permissions. Refer to the IAM policy example above.
-   **Vite Build**: The script assumes your Vite project builds to a `dist/` directory.

## 🛠️ Troubleshooting

### Common Issues:

**"AWS credentials are invalid"**
-   You may have entered the Access Key ID or Secret Access Key incorrectly.
-   The IAM user associated with the credentials may be disabled or deleted.

**"Build failed"**
-   Ensure you can run `npm run build` successfully in your project directory without errors.
-   Check that all `npm` dependencies are installed (`npm install`).

**Resource Creation Errors**
-   This usually indicates the IAM user is missing permissions for a specific action (e.g., `cloudfront:CreateDistribution`). Check the policy.
-   The S3 bucket name you chose might already be taken globally. S3 bucket names must be unique across all of AWS.

## 📞 Need Help?

If you run into problems or have questions about this script:

### 📧 Contact Information

**Fred Lackey**  
📧 Email: [Fred.Lackey@gmail.com](mailto:Fred.Lackey@gmail.com)  
🌐 Website: [@FredLackey.com](https://FredLackey.com) 