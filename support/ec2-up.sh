#!/bin/bash
# This script brings up an EC2 instance for binary compilation.
# Requirements: ec2-api-tools, and env vars set according to http://docs.amazonwebservices.com/AWSEC2/latest/UserGuide/setting-up-your-tools.html#set-aws-credentials
# 

# -k <private key name as per EC2 console>
# -t <instance type, m1.small or c1.small>

ec2run ami-04c9306d $@
