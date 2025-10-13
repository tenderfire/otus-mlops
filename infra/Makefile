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

compute-destroy:
	terraform destroy -target yandex_dataproc_cluster.dataproc_cluster -target yandex_compute_instance.proxy -auto-approve