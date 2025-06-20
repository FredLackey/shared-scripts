# XCopy Update Script (Windows Batch File)

## 🎯 What Does This Do?

This Windows batch script helps system administrators automatically and safely update application files on user workstations by copying them from a network location using RoboCopy. It's designed for situations where:

- You manage multiple workstations that need regular application updates
- Another team builds and deploys updated application files to a network folder
- You don't know exactly when those files are updated
- You need to safely copy those updates to user workstations using RoboCopy
- You want to avoid copying the same files repeatedly

## 🎯 Usage Scenarios

**Initial Use - Manual Execution:**
The script is initially designed to be run manually by system administrators. You can double-click the batch file or run it from a command prompt to check for and apply updates as needed.

**Ultimate Goal - Automatic Login Execution:**
The long-term purpose is to have this script run automatically whenever a user logs into their Windows workstation. This means:
- The script gets deployed to user workstations
- It's configured to execute during the login process
- Users automatically receive application updates without manual intervention
- The workstation application stays current with the latest deployed version

## 📋 The Problem This Solves

**The Scenario:**
You're responsible for keeping application files up-to-date on user workstations. Another development team periodically updates the application and places the new files in a shared network folder. Your job is to copy these updated files to user workstations.

**The Challenge:**
- You don't know when the network folder gets updated
- You don't want to copy files that haven't changed
- You need to track what was copied and when
- Manual checking is time-consuming and error-prone

**The Solution:**
This Windows batch script automatically uses RoboCopy to check if files have been updated and only copies what's new or changed, keeping a record of what it did.

## 🔧 How It Works

1. **Checks the Network Folder** - Uses RoboCopy to examine the source UNC path for application files
2. **Compares with Last Run** - RoboCopy intelligently identifies what has changed since the last run
3. **Identifies Changes** - Finds files that are new, modified, or updated using RoboCopy's built-in comparison
4. **Performs Safe Copy** - Uses RoboCopy's robust copying features to transfer only changed files
5. **Updates Records** - RoboCopy maintains detailed logs of what was copied and when
6. **Logs Everything** - Creates comprehensive log files for your review and troubleshooting

## 👥 User Experience

The script is designed to be **completely user-friendly** for non-technical end users:

### What Users See:
- **Clean, professional messages** - No technical jargon or scary batch file terms
- **Branded application name** - All messages reference the specific application being updated
- **Clear progress updates** - Simple messages like "Checking for updates..." and "Success! Application updated"
- **Friendly completion messages** - "Great news! Your application is already up to date"

### What Users DON'T See:
- RoboCopy commands or technical parameters
- File paths or UNC network locations  
- Batch file references or exit codes
- Complex error messages (redirected to "contact your administrator")

## 📁 What's Included

This folder contains:
- **UpdateApp.bat** - The main batch script that performs the updates
- **README.md** - This documentation file
- **logs/** - Directory created automatically to store update logs

## 🏷️ Customizing the Script Name

The batch file is named `UpdateApp.bat` as a generic starting point, but you should **rename it** to match your specific application:

### Recommended Naming:
- **For Accounting Software**: `UpdateAccounting.bat`
- **For Payroll System**: `UpdatePayroll.bat`
- **For Customer Database**: `UpdateCustomerDB.bat`
- **For Point of Sale**: `UpdatePOS.bat`

### Multiple Applications:
You can use this script for **multiple different applications** by:
1. **Making copies** of the batch file for each application
2. **Renaming each copy** to match the specific application
3. **Configuring each copy** with different paths and APP_NAME settings
4. **Deploying each script** to the appropriate users/systems

### Benefits of Renaming:
- **Clear identification** - Users know exactly what's being updated
- **Professional appearance** - Matches your organization's naming conventions
- **Easy management** - Administrators can quickly identify which script does what
- **Reduced confusion** - No generic "UpdateApp" running on user systems

## 📁 What You'll Need

Before using this script, you'll need to know:

- **Application Name** - A friendly name for the application (for user messages)
- **Source UNC Path** - The fully qualified UNC path to the network folder containing the deployed application
- **Destination Local Path** - The fully qualified local Windows path on the workstation where the application should be copied
- **RoboCopy Path** - The fully qualified path to the RoboCopy executable
- **Permissions** - Access rights to both source and destination folders

## ⚙️ Configuration

The script uses four clearly defined variables at the top of the batch file that you can easily modify:

- **APP_NAME** - The friendly name for the application (e.g., `Accounting Software`)
- **NETWORK_SOURCE_PATH** - The fully qualified UNC path (e.g., `\\server\share\application`)
- **LOCAL_DEST_PATH** - The fully qualified local path (e.g., `C:\Applications\MyApp`)
- **ROBOCOPY_EXE** - The fully qualified path to RoboCopy (e.g., `C:\Windows\System32\robocopy.exe`)

### Easy Configuration:
- **Simple to customize** - Just update the four variables at the top of the batch file
- **User-friendly branding** - The APP_NAME appears in all user messages
- **Environment-specific** - Each workstation can have its own copy with different paths
- **No script editing required** - All customization happens in the variable definitions

## 🚀 Getting Started

### Step 1: Prepare Your Environment
1. Make sure you have access to both source and destination folders
2. Test that you can manually copy files between these locations
3. Identify the exact paths you'll be using

### Step 2: Rename and Configure the Script
1. **Rename the batch file** to match your application (e.g., `UpdatePayroll.bat`)
2. **Open the renamed file** in a text editor (like Notepad)
3. **Find the four variables** at the top of the file and configure them:
   - Set `APP_NAME` to a friendly name for your application (e.g., "Payroll System")
   - Set `NETWORK_SOURCE_PATH` to your UNC path (where files come from)
   - Set `LOCAL_DEST_PATH` to your local path (where files go to)
   - Set `ROBOCOPY_EXE` to your RoboCopy executable path
4. **Save the batch file**

### Step 3: Test Run
1. **Double-click your renamed batch file** to run it manually
2. **Review the console output** to see what it plans to do
3. **Check the log files** in the `logs/` directory for detailed results

### Step 4: Deploy for Automatic Execution (Optional)
Once you've tested the script and confirmed it works correctly:

**For Manual Use:**
- Keep running the script manually as needed
- Double-click the batch file or run from command prompt

**For Automatic Login Execution:**
1. **Test thoroughly first** - Ensure the script works perfectly in manual mode
2. **Choose deployment method:**
   - Add to Windows Startup folder for current user
   - Use Group Policy to run at login (for domain environments)
   - Add to Windows Registry Run keys
   - Use Task Scheduler with "At logon" trigger
3. **Deploy to user workstations** - Copy the configured script to target machines
4. **Monitor initial deployments** - Check log files after users log in
5. **Verify automatic updates** - Confirm the application stays current

## 📊 What Gets Tracked

RoboCopy and the script maintain several types of information:

- **File Comparison** - RoboCopy compares file sizes, dates, and attributes to detect changes
- **Last Run Time** - When the script last checked for updates
- **Copy History** - Detailed RoboCopy logs showing what files were copied and when
- **Error Log** - Any problems encountered during the RoboCopy operation

## 🔒 Safety Features

- **RoboCopy Reliability** - Uses Windows' most robust file copying utility
- **Dry Run Mode** - RoboCopy can show what would happen without actually copying (`/L` flag)
- **Verification** - RoboCopy has built-in verification to confirm files copied correctly
- **Detailed Logging** - Comprehensive logs help track all changes and troubleshoot issues
- **Restart Capability** - RoboCopy can resume interrupted transfers

## 📝 Log Files

The script creates comprehensive logging in the `logs/` directory:

### Log File Types:
- **Timestamped Logs** - Detailed log for each run (e.g., `UpdateApp_2024-01-15_14-30-25.log`)
- **Summary Log** - Quick reference of all runs (`UpdateApp_Summary.log`)

### What Gets Logged:
- Configuration settings and paths used
- Pre-update verification results
- Complete RoboCopy output with file-by-file details
- Exit codes and their interpretations
- Error messages and troubleshooting information
- Start and end times for each operation

### Benefits:
- **Troubleshooting** - Detailed technical information for administrators
- **Audit Trail** - Complete history of all update operations
- **Verification** - Confirm what files were actually copied
- **Performance Tracking** - Monitor how long updates take

## ⚠️ Important Notes

- **Test First** - Always run with RoboCopy's `/L` flag (list only) before doing actual copies
- **Check Permissions** - Ensure you have proper access to both UNC source and local destination
- **Monitor Logs** - Review RoboCopy log files regularly for any issues
- **RoboCopy Path** - Verify the RoboCopy executable path is correct for your Windows version
- **Network Connectivity** - Script requires reliable access to the UNC network source
- **Windows Compatibility** - This is a Windows batch file designed for Windows systems only
- **Login Script Considerations** - When running at login, ensure network connectivity is established before the script executes
- **User Context** - The script will run with the permissions of the logged-in user, so ensure they have appropriate access rights
- **Workstation Deployment** - This script is designed for deployment to individual user workstations, not servers

## 🛠️ Troubleshooting

### Common Issues:

**"Access Denied" Errors**
- Check that you have read access to source folder
- Verify you have write access to destination folder
- Ensure network path is accessible

**"No Files Found" Messages**
- Verify the source path is correct
- Check that files exist in the source location
- Confirm network connectivity

**"Files Not Copying" Problems**
- Check available disk space on destination
- Verify file permissions
- Review error logs for specific issues

## 📞 Need Help?

If you run into problems or have questions about this script:

### 📧 Contact Information

**Fred Lackey**  
📧 Email: [Fred.Lackey@gmail.com](mailto:Fred.Lackey@gmail.com)  
🌐 Website: [@FredLackey.com](https://FredLackey.com)

### When Contacting for Support:

Please include:
1. **What you were trying to do** - Your goal with the script
2. **What happened** - The actual result or error message
3. **Your environment** - Windows version, network setup details
4. **Configuration** - Your source and destination paths (remove sensitive info)
5. **Log files** - Any error messages from the script logs

### Before You Contact:

1. Check the troubleshooting section above
2. Review the log files for error messages
3. Try running in test mode to see what the script plans to do
4. Verify your network connectivity and permissions

---

*Remember: This script is designed to help make your job easier. Don't hesitate to reach out if you need help getting it set up or working properly!* 