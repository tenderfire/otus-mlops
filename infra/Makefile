init:
	terraform init -upgrade
	. .ignore/setenv.sh

plan:
	terraform fmt --diff --recursive
	terraform validate 
	terraform plan -out='tfplan'

apply:
	terraform apply "tfplan"

destroy:
	terraform destroy -auto-approve