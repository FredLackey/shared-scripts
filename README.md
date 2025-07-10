# Shared Scripts

This repository contains a collection of scripts for various administrative and deployment tasks. Each script is located in its own directory and includes detailed documentation.

##  Scripts

### CloudFront Deploy for React (`cloudfront-deploy-react`)

Automates the complete deployment of a Vite-based React application to AWS S3 and CloudFront. It handles resource creation (S3, OAC, Distribution), code build, and deployment in one go.

-   [Go to script](./cloudfront-deploy-react/)
-   [Read the guide](./cloudfront-deploy-react/README.md)

### CloudFront Remove (`cloudfront-remove`)

A destructive script that finds and permanently deletes all AWS resources associated with a CloudFront deployment based on the S3 origin bucket. Use this to tear down environments and avoid ongoing costs.

-   [Go to script](./cloudfront-remove/)
-   [Read the guide](./cloudfront-remove/README.md)

### XCopy Update (`xcopy-update`)

A Windows batch script for updating an application from a source to a destination directory, with built-in backup functionality.

-   [Go to script](./xcopy-update/)
-   [Read the guide](./xcopy-update/README.md)

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details. 