# Shared Scripts & Utilities

This repository contains a collection of scripts, utilities, and small applications designed to automate or simplify common developer and administrative tasks.

## 🎯 What's This All About?

This is a growing collection of:
- **Windows Scripts** - Batch and PowerShell scripts for Windows environments.
- **Cloud Scripts** - Utilities for managing cloud infrastructure (e.g., AWS).
- **JavaScript Utilities** - Simple web-based tools and Node.js scripts.
- **Small Applications** - Lightweight programs for specific problems.

## 🌟 Philosophy

All scripts and utilities in this repository are designed for **simplicity** and **clarity**:
- Straightforward and easy to understand
- Well-commented to explain the "why" behind the code
- Accompanied by clear, step-by-step README files
- Thoroughly tested and documented

## 📁 Repository Structure

Each script or utility will have its own folder with:
- The main script/application files
- A detailed `README.md` with usage instructions
- Any necessary configuration or example files
- Clear explanations of what the tool does and why you might need it

## 🚀 Getting Started

1. **Browse the folders** to find the script or utility you need.
2. **Read the `README.md`** in the tool's folder for specific instructions.
3. **Follow the steps** to execute the tool.
4. **Ask questions** if you encounter any issues.

## 📋 Available Scripts & Tools

The following scripts & tools are available, with more planned for the future.

### ☁️ AWS CloudFront Scripts

- **[cloudfront-remove/](cloudfront-remove/)** - **AWS CloudFront Teardown**
  - **WARNING:** This script is DESTRUCTIVE and permanently deletes resources.
  - Automates the complete removal of a CloudFront distribution, S3 bucket, and Origin Access Control (OAC).
  - Designed for developers and administrators to clean up test/staging environments or decommission projects.
  - Sequences deletion operations correctly and waits for CloudFront to disable before removal.

### 🔄 Application Update Scripts

- **[xcopy-update/](xcopy-update/)** - **Windows Application Updater**
  - Automatically updates applications on user workstations from network locations
  - Uses RoboCopy for reliable, efficient file synchronization
  - Designed for deployment via login scripts or manual execution
  - User-friendly interface with no technical jargon
  - Comprehensive logging for administrators
  - Perfect for keeping desktop applications current across multiple workstations

### 🚀 Coming Soon

More helpful scripts and utilities are always in development. Future additions may include file and system maintenance scripts, network helpers, and data synchronization tools.

*Each new script will follow the same philosophy: simple, well-documented, and family-friendly.*

## 🔒 Safety First

- All scripts are tested before being shared
- Each tool includes safety checks where appropriate
- Instructions include warnings about any potential risks
- When in doubt, ask before running anything!

## 📚 How to Use Each Tool

Every tool in this repository follows the same pattern:

1. **Navigate to the tool's folder**
2. **Open the README.md file**
3. **Read the "What does this do?" section**
4. **Follow the step-by-step instructions**
5. **Check the troubleshooting section if needed**

## 🆘 Need Help?

Don't worry if something doesn't work as expected or if you have questions! I'm here to help.

### 📧 Contact Information

**Fred Lackey**  
📧 Email: [Fred.Lackey@gmail.com](mailto:Fred.Lackey@gmail.com)  
🌐 Website: [@FredLackey.com](https://FredLackey.com)

### When to Reach Out

- ❓ You're not sure which tool to use
- 🐛 Something isn't working as described
- 💡 You have an idea for a new script or utility
- 🤔 You need help understanding what a script does
- 📝 You'd like clearer instructions for something

### What to Include in Your Message

To help me assist you quickly:
1. **Which script/tool** you're trying to use
2. **What you're trying to accomplish**
3. **What happened** when you tried to run it
4. **Any error messages** you saw
5. **Your operating system** (Windows 10, Windows 11, Mac, etc.)

---

*Remember: There are no silly questions! I'd rather you ask and be safe than struggle on your own.* 