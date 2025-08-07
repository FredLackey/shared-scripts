# AWS SSO Login Setup Guide

This guide provides step-by-step instructions for setting up and using AWS Single Sign-On (SSO) with the AWS CLI, including creating and managing local profiles.

## Prerequisites

- AWS CLI v2 installed on your system
- Access to your organization's AWS SSO portal
- Your AWS SSO start URL and region

## Step 1: Verify AWS CLI Version

First, ensure you have AWS CLI v2 installed, as SSO is not supported in v1:

```bash
aws --version
```

Expected output should show version 2.x.x:
```
aws-cli/2.x.x Python/3.x.x Darwin/x.x.x source/x86_64
```

If you need to install or upgrade AWS CLI v2, visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

## Step 2: Configure AWS SSO

Configure your AWS SSO settings using the AWS CLI:

```bash
aws configure sso
```

You'll be prompted for the following information:

1. **SSO session name**: A descriptive name for your SSO session (e.g., `company-sso`, `orgname-sso`)
2. **SSO start URL**: Your organization's SSO portal URL (e.g., `https://my-company.awsapps.com/start`)
3. **SSO region**: The AWS region where your SSO is configured (e.g., `us-east-1`)
4. **SSO registration scopes**: Permissions for the CLI client (default: `sso:account:access`)
5. **Account selection**: Choose from the list of AWS accounts you have access to
6. **Role selection**: Choose the IAM role you want to assume
7. **CLI default client region**: Default AWS region for CLI operations (e.g., `us-east-1`)
8. **CLI default output format**: Choose output format (`json`, `yaml`, `text`, or `table`)
9. **CLI profile name**: Name for this profile (e.g., `company-prod`, `company-dev`)

### Understanding SSO Registration Scopes

When prompted for **SSO registration scopes**, you'll typically see:
```
SSO registration scopes [sso:account:access]:
```

**Recommended action**: Press Enter to accept the default `sso:account:access` scope.

#### Available Scopes and Access Levels

**`sso:account:access` (Default - Recommended)**
- **What it does**: Standard scope for AWS CLI operations
- **Permissions**: Access to all accounts and roles assigned to your user
- **Use case**: Normal AWS CLI operations, script automation, daily development work
- **Access level**: Full access to assigned AWS resources

**Alternative Scopes** (Less Common):
- **`sso:account:access:read-only`**: Read-only access to account information
- **`sso:account:access:limited`**: Restricted access with limited permissions
- **Custom scopes**: Your organization may define custom scopes with specific limitations

#### When to Use Different Scopes

**Stick with `sso:account:access` unless:**
- Your organization has specific security policies requiring restricted scopes
- You're setting up a dedicated read-only CLI profile
- You're in a compliance environment with strict access controls
- Your security team has provided specific scope requirements

**Security Note**: The scope only controls what the CLI client can request - your actual permissions are still limited by the IAM roles assigned to you in AWS SSO. The scope doesn't grant additional access beyond what your administrator has already configured.

### Recommended Naming Conventions

**SSO Session Name**:
- Use a descriptive name that identifies your organization or domain
- Format: `[organization]-sso` or `[domain]-sso`
- Examples: `mycompany-sso`, `acme-corp-sso`, `projectname-sso`
- **Benefits**: Easy to identify which SSO instance you're using when you have multiple

**Profile Name**:
- Use a format that clearly identifies the environment and purpose
- Format: `[org-prefix]-[account-purpose]-[environment]`
- Examples: `company-app-prod`, `company-data-dev`, `org-billing-main`
- **Avoid**: Default suggested names like `AdministratorAccess-123456789012`
- **Benefits**: 
  - Instantly recognizable when switching profiles
  - Easier to manage in scripts and automation
  - Clear separation between environments

**Example Good Naming**:
```bash
SSO session name: myorg-sso
Profile name: myorg-web-prod     # Production web application account
Profile name: myorg-web-dev      # Development web application account  
Profile name: myorg-data-prod    # Production data/analytics account
Profile name: myorg-billing      # Billing/finance account
```

### Example Configuration Session

```bash
$ aws configure sso
SSO session name (Recommended): mycompany-sso
SSO start URL [None]: https://my-company.awsapps.com/start
SSO region [None]: us-east-1
SSO registration scopes [sso:account:access]: 
Attempting to automatically open the SSO authorization page in your default browser.
If the browser does not open or you wish to use a different device to authorize this request, open the following URL:

https://device.sso.us-east-1.amazonaws.com/

Then enter the code: ABCD-EFGH

# Browser will open for authentication
# After successful authentication, you'll see available accounts

There are 3 AWS accounts available to you.
Using the account ID 123456789012
The only role available to you is: AdministratorAccess
Using the role name "AdministratorAccess"

Default client Region [None]: us-east-1
CLI default output format (json if not specified) [None]: 
Profile name [AdministratorAccess-123456789012]: mycompany-app-dev

To use this profile, specify the profile name using --profile, as shown:

aws sts get-caller-identity --profile mycompany-app-dev
```

## Step 3: Login to AWS SSO

After configuration, log in to activate your SSO session:

```bash
aws sso login --profile mycompany-app-dev
```

This will open your browser for authentication. After successful login, your session will be active.

## Step 4: Verify Your Profile

Test that your profile is working correctly:

```bash
# List S3 buckets using your SSO profile
aws s3 ls --profile mycompany-app-dev

# Get caller identity to verify which account/role you're using
aws sts get-caller-identity --profile mycompany-app-dev
```

Expected output for `get-caller-identity`:
```json
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE:user@company.com",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/AdministratorAccess/user@company.com"
}
```

## Step 5: Set Default Profile (Optional)

To avoid typing `--profile` with every command, you can set a default profile:

```bash
export AWS_PROFILE=mycompany-app-dev
```

Add this to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.) to make it persistent:

```bash
echo 'export AWS_PROFILE=mycompany-app-dev' >> ~/.bashrc
source ~/.bashrc
```

## Managing Multiple Profiles

You can configure multiple SSO profiles for different accounts or roles:

```bash
# Configure additional profiles
aws configure sso --profile mycompany-app-prod
aws configure sso --profile mycompany-data-dev
```

List all configured profiles:

```bash
aws configure list-profiles
```

Switch between profiles:

```bash
# Use specific profile for one command
aws s3 ls --profile mycompany-app-prod

# Set environment variable
export AWS_PROFILE=mycompany-app-prod

# Unset to use default
unset AWS_PROFILE
```

## Session Management

### Check Session Status

```bash
# Check if your SSO session is still valid
aws sts get-caller-identity --profile mycompany-app-dev
```

### Refresh Expired Sessions

When your SSO session expires, you'll need to log in again:

```bash
aws sso login --profile mycompany-app-dev
```

### Logout

To end your SSO session:

```bash
aws sso logout
```

## Troubleshooting

### Common Issues

1. **Session Expired**
   ```bash
   # Error: The SSO session associated with this profile has expired or is otherwise invalid
   aws sso login --profile mycompany-app-dev
   ```

2. **Profile Not Found**
   ```bash
   # Error: The config profile (mycompany-app-dev) could not be found
   aws configure list-profiles  # Check available profiles
   ```

3. **Browser Issues**
   If the browser doesn't open automatically:
   ```bash
   # Copy the URL from the terminal and open it manually in your browser
   # Then enter the provided code
   ```

### View Profile Configuration

Check your SSO configuration:

```bash
# View all profiles
cat ~/.aws/config

# View specific profile
aws configure list --profile mycompany-app-dev
```

## Best Practices

1. **Use descriptive profile names** that include environment and purpose
2. **Set appropriate default regions** based on your primary usage
3. **Regularly refresh sessions** before they expire to avoid interruptions
4. **Use environment variables** for automation scripts
5. **Keep your AWS CLI updated** for the latest SSO features

## Configuration File Location

Your SSO profiles are stored in:
- **Config**: `~/.aws/config`
- **Credentials cache**: `~/.aws/sso/cache/`

Example config file entry:
```ini
[sso-session mycompany-sso]
sso_start_url = https://my-company.awsapps.com/start
sso_region = us-east-1
sso_registration_scopes = sso:account:access

[profile mycompany-app-dev]
sso_session = mycompany-sso
sso_account_id = 123456789012
sso_role_name = AdministratorAccess
region = us-east-1
output = json
```

## Next Steps

After setting up your SSO profile:
1. Explore AWS services using the CLI
2. Set up automation scripts with your profile
3. Configure IDE integrations to use your SSO profile
4. Share this setup process with your team members

For more advanced configurations and troubleshooting, refer to the [official AWS SSO CLI documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html).