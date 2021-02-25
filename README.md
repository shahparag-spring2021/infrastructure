# Terraform

    Install Terraform
    Install AWS CLI and create AWS CLI dev and prod profiles

    Create vars.tfvars file with below variables - 
    ```
    region = "us-east-1"
    vpc_name = "csye6225"
    cidr_block_vpc = "10.0.0.0/16"
    cidr_block1_subnet = "10.0.1.0/24"
    cidr_block2_subnet = "10.0.2.0/24"
    cidr_block3_subnet = "10.0.3.0/24"
    ```

    Set any profile
        export AWS_PROFILE=dev

    Terraform commands to run - 	
        terraform init
        terraform plan -var-file="vars.tfvars"
        terraform apply -var-file="vars.tfvars"

    Destroy using - 
        terraform destroy
