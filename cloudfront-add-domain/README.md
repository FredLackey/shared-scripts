# Add Custom Domain to AWS CloudFront Script

## 🎯 What Does This Do?

This Bash script automates the process of adding a custom domain (e.g., `sub.your-domain.com`) to an existing AWS CloudFront distribution. It streamlines the entire workflow, which includes:

1.  **Requesting a public SSL/TLS certificate** from AWS Certificate Manager (ACM) in the required `us-east-1` region.
2.  **Providing the DNS validation record** you need to add to your domain's DNS provider.
3.  **Waiting for domain ownership to be validated** by AWS.
4.  **Updating the CloudFront distribution** to use the new custom domain and its associated certificate.
5.  **Waiting for the distribution changes to be fully deployed** across all AWS edge locations.

## 🎯 Usage Scenarios

This script is for developers and system administrators who need to:

-   **Securely add a custom domain** to a CloudFront distribution that was previously only accessible via its `*.cloudfront.net` address.
-   **Automate the SSL certificate provisioning** and validation process.
-   **Avoid the manual complexity** of configuring ACM, DNS, and CloudFront through the AWS Console.
-   **Ensure a correct and repeatable setup** for new custom domains on existing deployments.

## 📋 The Problem This Solves

**The Scenario:**
You have a CloudFront distribution serving content from an S3 bucket. It works perfectly, but you want users to access it via a professional, branded URL like `app.my-company.com` instead of `d123xyz.cloudfront.net`.

**The Challenge:**
-   **Regional Requirement:** SSL certificates for CloudFront **must** be created in the **US East (N. Virginia) / `us-east-1`** region, regardless of where your other resources are. This is a common point of confusion.
-   **Validation Complexity:** To issue a certificate, AWS must verify you own the domain. This requires creating a specific CNAME record in your DNS provider's system (e.g., Route 53, GoDaddy, Cloudflare).
-   **Configuration Order:** You must get the distribution's current configuration (`ETag`), modify it correctly in JSON format to add the new alias and certificate, and then submit the update. A mistake in the JSON can break the update.
-   **Waiting Game:** Certificate validation isn't instant, and CloudFront deployments take 10-15 minutes. The process involves significant waiting and checking.

**The Solution:**
This script orchestrates the entire process. It enforces the `us-east-1` region for the certificate, retrieves the exact CNAME record you need, waits for you to add it, waits for AWS to validate it, and then correctly builds and applies the new CloudFront configuration.

## 🔧 How It Works

1.  **Gathers Information** - Prompts for AWS credentials, the ID of the target CloudFront distribution, and the custom domain name you want to add.
2.  **Requests Certificate** - Submits a request to ACM in `us-east-1` for a new public SSL certificate for your custom domain.
3.  **Provides DNS Record** - Fetches the CNAME record details required for validation and displays them, then pauses.
4.  **Waits for User Action** - The script stops and waits for you to press Enter after you have added the CNAME record to your DNS provider.
5.  **Waits for Validation** - Once you proceed, it polls ACM until the certificate's status changes to "Issued."
6.  **Updates CloudFront** - It fetches the current distribution config, adds the new domain as an alias, and replaces the `ViewerCertificate` block with the new certificate's details.
7.  **Waits for Deployment** - It polls CloudFront until the distribution's status returns to "Deployed," indicating the changes are live.

## 📁 What's Included

This folder contains:
-   `cloudfront-add-domain.sh` - The main Bash script.
-   `README.md` - This documentation file.

## �� What You'll Need

-   **AWS CLI** - Must be installed and accessible in your system's `PATH`.
-   **jq** - A command-line JSON processor. Install it via Homebrew (`brew install jq`) or your package manager.
-   **DNS Provider Access** - You must be able to add a CNAME record for your domain.
-   **AWS Credentials** with sufficient permissions.

### Required IAM Permissions (Example Policy)
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "acm:RequestCertificate",
                "acm:DescribeCertificate",
                "acm:Wait"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudfront:GetDistributionConfig",
                "cloudfront:UpdateDistribution",
                "cloudfront:Wait"
            ],
            "Resource": "arn:aws:cloudfront::YOUR_ACCOUNT_ID:distribution/YOUR_DISTRIBUTION_ID"
        },
        {
            "Effect": "Allow",
            "Action": "sts:GetCallerIdentity",
            "Resource": "*"
        }
    ]
}
```
*Note: Replace `YOUR_ACCOUNT_ID` and `YOUR_DISTRIBUTION_ID` or use `"*"` for broader permissions.*

## 🚀 Getting Started

1.  Navigate to this script's directory.
2.  Make the script executable (you only need to do this once):
    ```bash
    chmod +x cloudfront-add-domain.sh
    ```
3.  Execute the script:
    ```bash
    ./cloudfront-add-domain.sh
    ```
4.  Follow the prompts for your credentials, Distribution ID, and the custom domain name.
5.  When prompted, add the provided CNAME record to your DNS provider.
6.  Return to the terminal and press Enter to continue.

## 🛠️ Troubleshooting

**"Certificate validation failed or timed out"**
-   The CNAME record was not entered correctly. Double-check the name and value.
-   DNS propagation can sometimes be slow. You may need to wait longer before pressing Enter.

**"An error occurred (InvalidViewerCertificate)"**
-   This script is designed to prevent this, but it can happen if the distribution is in a strange state. Ensure no other changes are being made to the distribution while the script is running.

**"Could not get ETag for distribution"**
-   Verify the Distribution ID was entered correctly and that the IAM user has `cloudfront:GetDistributionConfig` permissions.

## 📞 Need Help?

If you run into problems, feel free to reach out.

### 📧 Contact Information

**Fred Lackey**  
📧 Email: [Fred.Lackey@gmail.com](mailto:Fred.Lackey@gmail.com)  
🌐 Website: [@FredLackey.com](https://FredLackey.com) 