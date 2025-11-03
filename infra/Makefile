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

dp-destroy:
	terraform destroy -target yandex_dataproc_cluster.dataproc_cluster -auto-approve
	
stop:
	yc dataproc cluster stop --id $$(terraform output -raw dataproc_cluster_id)
	yc compute instance stop --id $$(terraform output -raw proxy_vm_id)

start:
	yc dataproc cluster start --id $$(terraform output -raw dataproc_cluster_id)
	yc compute instance start --id $$(terraform output -raw proxy_vm_id)

tunnel:
	ssh ubuntu@$$(yc compute instance get --id $$(terraform output -raw proxy_vm_id) --format json | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address') -i .ignore/id_ed25519 -L 8888:localhost:8888

ssh:
	ssh ubuntu@$$(yc compute instance get --id $$(terraform output -raw proxy_vm_id) --format json | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address') -i .ignore/id_ed25519