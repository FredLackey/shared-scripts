# AWS CloudFront Info Fetcher Script

## 🎯 What Does This Do?

This Bash script is a simple but powerful utility for finding and displaying key information about an AWS CloudFront distribution. It works by searching for a distribution that uses a specific S3 bucket as its origin.

This is particularly useful when you know which S3 bucket your website is in but have forgotten the long, unique ID of the CloudFront distribution that serves its content.

## 🎯 Usage Scenarios

This script is for anyone who needs to quickly:

-   **Find a CloudFront Distribution ID** without having to log in to the AWS Console.
-   **Look up the details** of a distribution, such as its CNAMEs (custom domains) or current status.
-   **Verify which distribution is connected** to a particular S3 bucket.
-   **Automate information gathering** as part of a larger administrative workflow.

## 📋 The Problem This Solves

**The Scenario:**
You have multiple projects deployed on AWS, each with its own CloudFront distribution. You need to perform an action on a specific distribution—like adding a custom domain or clearing the cache—but you can't remember its ID (e.g., `E123ABCDEFGHIJ`). You do, however, remember the S3 bucket name associated with the project (e.g., `my-awesome-app-bucket`).

**The Challenge:**
-   CloudFront IDs are not human-friendly and are difficult to memorize.
-   Searching for the right distribution in the AWS Management Console can be slow and inefficient if you have many of them.
-   You need a quick, command-line way to get the information you need to proceed with other tasks.

**The Solution:**
This script provides a direct lookup method. You provide the S3 bucket name you know, and it queries AWS to find the exact distribution linked to it, instantly giving you the ID and other relevant details.

## 🔧 How It Works

1.  **Gathers Information** - Prompts the user for their AWS Access Key, Secret Key, Region, and the S3 Bucket Name to search for.
2.  **Configures AWS CLI** - Sets up the necessary environment variables for the AWS CLI to authenticate for the current session.
3.  **Lists Distributions** - It calls the `aws cloudfront list-distributions` command to get a list of all distributions in the account.
4.  **Filters Results** - It pipes the JSON output of the list to the `jq` utility. `jq` filters the list to find the one distribution whose origin `DomainName` matches the S3 bucket endpoint derived from the user's input.
5.  **Displays Information** - If a match is found, it parses the JSON for that distribution and prints out the most important details in a clean, readable format. If no match is found, it informs the user.

## 📁 What's Included

-   `cloudfront-info.sh` - The main Bash script.
-   `README.md` - This documentation file.

## �� What You'll Need

-   **AWS CLI** - Must be installed and accessible in your system's `PATH`.
-   **jq** - A command-line JSON processor. Install it via Homebrew (`brew install jq`) or your package manager.
-   **AWS Credentials** with sufficient permissions.

### Required IAM Permissions (Example Policy)
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudfront:ListDistributions"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "sts:GetCallerIdentity",
            "Resource": "*"
        }
    ]
}
```

## 🚀 Getting Started

1.  Navigate to this script's directory.
2.  Make the script executable (you only need to do this once):
    ```bash
    chmod +x cloudfront-info.sh
    ```
3.  Execute the script:
    ```bash
    ./cloudfront-info.sh
    ```
4.  Follow the on-screen prompts to provide your credentials and the target S3 bucket name.

## 🛠️ Troubleshooting

**"No CloudFront distribution found"**
-   Verify you entered the correct S3 bucket name and AWS region.
-   The distribution may have been deleted, or it may be configured with a different origin.

**"jq: command not found"**
-   You need to install the `jq` utility. On macOS with Homebrew, the command is `brew install jq`. On other systems, use your respective package manager (e.g., `sudo apt-get install jq` on Debian/Ubuntu).

**"AWS credentials are invalid"**
-   You may have entered the Access Key ID or Secret Access Key incorrectly.

## 📞 Need Help?

If you have questions or run into problems, please contact me.

### 📧 Contact Information

**Fred Lackey**  
📧 Email: [Fred.Lackey@gmail.com](mailto:Fred.Lackey@gmail.com)  
🌐 Website: [@FredLackey.com](https://FredLackey.com) 