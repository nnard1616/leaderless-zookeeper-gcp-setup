


function Start-Server {
	Param (
		[Parameter(Mandatory=$TRUE,
			HelpMessage="Enter an integer to identify the vm.")]
		[Alias("n")]
		[int]
		$number,

		[Parameter(Mandatory=$TRUE,
			HelpMessage="Enter a zone, run 'gcloud compute zones list' for a listing of possibilities")]
		[ValidateSet('us-east1-b',
					'us-east1-c',
					'us-east1-d',
					'us-east4-c',
					'us-east4-b',
					'us-east4-a',
					'us-central1-c',
					'us-central1-a',
					'us-central1-f',
					'us-central1-b',
					'us-west1-b',
					'us-west1-c',
					'us-west1-a',
					'europe-west4-a',
					'europe-west4-b',
					'europe-west4-c',
					'europe-west1-b',
					'europe-west1-d',
					'europe-west1-c',
					'europe-west3-c',
					'europe-west3-a',
					'europe-west3-b',
					'europe-west2-c',
					'europe-west2-b',
					'europe-west2-a',
					'asia-east1-b',
					'asia-east1-a',
					'asia-east1-c',
					'asia-southeast1-b',
					'asia-southeast1-a',
					'asia-southeast1-c',
					'asia-northeast1-b',
					'asia-northeast1-c',
					'asia-northeast1-a',
					'asia-south1-c',
					'asia-south1-b',
					'asia-south1-a',
					'australia-southeast1-b',
					'australia-southeast1-c',
					'australia-southeast1-a',
					'southamerica-east1-b',
					'southamerica-east1-c',
					'southamerica-east1-a',
					'asia-east2-a',
					'asia-east2-b',
					'asia-east2-c',
					'asia-northeast2-a',
					'asia-northeast2-b',
					'asia-northeast2-c',
					'asia-northeast3-a',
					'asia-northeast3-b',
					'asia-northeast3-c',
					'asia-southeast2-a',
					'asia-southeast2-b',
					'asia-southeast2-c',
					'europe-north1-a',
					'europe-north1-b',
					'europe-north1-c',
					'europe-west6-a',
					'europe-west6-b',
					'europe-west6-c',
					'northamerica-northeast1-a',
					'northamerica-northeast1-b',
					'northamerica-northeast1-c',
					'us-west2-a',
					'us-west2-b',
					'us-west2-c',
					'us-west3-a',
					'us-west3-b',
					'us-west3-c',
					'us-west4-a',
					'us-west4-b',
					'us-west4-c'
					)]
		[Alias("z")]
		[String]
		$zone,

		[Parameter(Mandatory=$TRUE,
				HelpMessage="Enter a docker hub image")]
		[Alias("c")]
		[String]
		$containerImage,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter fail limit")]
		[int]
		$faillimit = 1


	)

	$OS = $PSVersionTable.OS | cut -d ' ' -f1
	$env_file_path = ""
	if ($OS -eq 'Microsoft') {
		$env_file_path = ".\Environment_Files\env_file"
	}

	if ($OS -eq 'Linux') {
		$env_file_path = "./Environment_Files/env_file"
	}

	gcloud compute --project "leaderless-zookeeper" instances create-with-container "zook$('{0:d3}' -f $number)" `
	--container-image "$containerImage" --zone $zone --machine-type "n1-standard-2" `
	--subnet "default" --maintenance-policy "MIGRATE" --service-account "858944573210-compute@developer.gserviceaccount.com" `
	--scopes=default --tags "zook-server" --image "cos-stable-85-13310-1209-17" --image-project "cos-cloud" --boot-disk-size "10" `
	--boot-disk-type "pd-standard" --boot-disk-device-name "zook$('{0:d3}' -f $number)" --container-env=ZOO_MY_ID=$number `
	--container-env=ZOO_FAIL_LIMIT=$faillimit --container-env-file=$env_file_path
}

function Update-VM {
	Param (
		[Parameter(Mandatory=$TRUE,
			HelpMessage="Enter an integer to identify the vm.")]
		[Alias("n")]
		[int]
		$number,

		[Parameter(Mandatory=$TRUE,
			HelpMessage="Enter zone to identify the vm.")]
		[Alias("z")]
		[string]
		$zone
	)

	$OS = $PSVersionTable.OS | cut -d ' ' -f1
	$env_file_path = ""
	if ($OS -eq 'Microsoft') {
		$env_file_path = ".\Environment_Files\env_file"
	}

	if ($OS -eq 'Linux') {
		$env_file_path = "./Environment_Files/env_file"
	}

	gcloud compute --project "leaderless-zookeeper" instances update-container "zook$('{0:d3}' -f $number)" `
	--container-env=ZOO_MY_ID=$number  --container-env-file=$env_file_path --zone=$zone
}

function Update-Servers {

	$existing_server_count = $(gcloud compute instances list --filter="tags:zook-server" | measure-object -line).Lines - 1

	$OS = $PSVersionTable.OS | cut -d ' ' -f1
	$zones_file_path = ""
	if ($OS -eq 'Microsoft') {
		$zones_file_path = ".\Zones_Files\zones_file$existing_server_count"
	}

	if ($OS -eq 'Linux') {
		$zones_file_path = "./Zones_Files/zones_file$existing_server_count"
	}

	[string[]]$zones = Get-Content -Path $zones_file_path

	if ($existing_server_count -ne $zones.length) {
		echo "ERROR: Update-Servers: there is an unexpected number of active servers."
		return
	}


	$scriptBlock = {
		param($n, $z)
		Write-Host $n $z
		Update-VM $n $z
	}

	1..$existing_server_count | ForEach-Object {
		Start-Job -ScriptBlock $scriptBlock -ArgumentList  $_, $zones[$($_-1)]
	}


	get-job

	While (Get-Job -State "Running")
	{
	  Start-Sleep 5
	}

	Get-Job | % { Receive-Job $_.Id; Remove-Job $_.Id }
}

function prep-env {
	Param (
		[Parameter(Mandatory=$TRUE,
			HelpMessage="Enter an integer to identify how many machines will be in the cluster.")]
		[Alias("n")]
		[int]
		$number,

		[Parameter(Mandatory=$TRUE,
			HelpMessage="Enter a Zones File path")]
		[Alias("z")]
		[String]
		$zones_file_path
	)

	[string[]]$zones = Get-Content -Path $zones_file_path

	if ($number -ne $zones.length) {
		echo "ERROR: make sure the chosen number of machines and the number of zones match"
		return
	}

	$OS = $PSVersionTable.OS | cut -d ' ' -f1
	$env_file_template_path = ""
	$env_file_path = ""
	if ($OS -eq 'Microsoft') {
		$env_file_template_path = ".\Environment_Files\env_file$number"
		$env_file_path = ".\Environment_Files\env_file"
	}

	if ($OS -eq 'Linux') {
		$env_file_template_path = "./Environment_Files/env_file$number"
		$env_file_path = "./Environment_Files/env_file"
	}

	Copy-Item -Force $env_file_template_path $env_file_path



	1..$number | ForEach-Object {
		$oldText = "zook$('{0:d3}' -f $_)"
		$newText = $oldText + ".$($zones[$_-1]).c.leaderless-zookeeper.internal"
		sed -i "s/$oldText/$newText/g" $env_file_path
	}



}

function start-many {
	Param (
		[Parameter(Mandatory=$FALSE,
			HelpMessage="Enter a number of machines to create.")]
		[Alias("n")]
		[int]
		$number = 3,

		[Parameter(Mandatory=$TRUE,
				HelpMessage="Enter a docker hub image")]
		[Alias("c")]
		[String]
		$containerImage,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter fail limit")]
		[int]
		$faillimit = 1
	)
	$OS = $PSVersionTable.OS | cut -d ' ' -f1
	$zones_file_path = ""
	if ($OS -eq 'Microsoft') {
		$zones_file_path = ".\Zones_Files\zones_file$number"
	}

	if ($OS -eq 'Linux') {
		$zones_file_path = "./Zones_Files/zones_file$number"
	}

	[string[]]$zones = Get-Content -Path $zones_file_path

	prep-env $number $zones_file_path

	$scriptBlock = {
		param($n, $z, $c, $l)
		Write-Host $n $z $c $l
		Start-Server $n $z $c $l
	}

	1..$number | ForEach-Object {
		Start-Job -ScriptBlock $scriptBlock -ArgumentList  $_, $zones[$($_-1)], $containerImage, $faillimit
	}

	get-job

	While (Get-Job -State "Running")
	{
	  Start-Sleep 5
	}

	Get-Job | % { Receive-Job $_.Id; Remove-Job $_.Id }

}

function Delete-VM {
	Param (
		[Parameter(Mandatory=$TRUE,
			HelpMessage="Enter the name of vm to delete, as it appears on GCP.")]
		[Alias("n")]
		[String]
		$name,

		[Parameter(Mandatory=$FALSE,
			HelpMessage="Enter zone to identify the vm.")]
		[Alias("z")]
		[string]
		$zone = 'us-west1-a'
	)

	gcloud compute instances delete $name --zone=$zone --quiet
}

function Delete-Servers {

	$vms = Create-VMTable

	$existing_server_count = $vms.count

	$scriptBlock = {
		param($n, $z)
		Write-Host $n $z
		Delete-VM $n $z
	}

	for ($n = 1; $n -le $existing_server_count; $n++) {
		Start-Job -ScriptBlock $scriptBlock -ArgumentList  $vms[$n].NAME, $vms[$n].ZONE
	}

	get-job

	While (Get-Job -State "Running")
	{
	  Start-Sleep 5
	}

	Get-Job | % { Receive-Job $_.Id; Remove-Job $_.Id }
}

function  Delete-Test-Servers {

	$vms = Create-Test-VMTable

	$existing_server_count = $vms.count

	$scriptBlock = {
		param($n, $z)
		Write-Host $n $z
		Delete-VM $n $z
	}

	for ($n = 1; $n -le $existing_server_count; $n++) {
		Start-Job -ScriptBlock $scriptBlock -ArgumentList  $vms[$n].NAME, $vms[$n].ZONE
	}

	get-job

	While (Get-Job -State "Running")
	{
		Start-Sleep 5
	}

	Get-Job | % { Receive-Job $_.Id; Remove-Job $_.Id }
}

function Start-Client {
	Param (
		[Parameter(Mandatory=$TRUE,
				HelpMessage="Enter an integer to identify the vm.")]
		[Alias("n")]
		[int]
		$number,

		[Parameter(Mandatory=$TRUE,
				HelpMessage="Enter a zone, run 'gcloud compute zones list' for a listing of possibilities")]
		[ValidateSet('us-east1-b',
				'us-east1-c',
				'us-east1-d',
				'us-east4-c',
				'us-east4-b',
				'us-east4-a',
				'us-central1-c',
				'us-central1-a',
				'us-central1-f',
				'us-central1-b',
				'us-west1-b',
				'us-west1-c',
				'us-west1-a',
				'europe-west4-a',
				'europe-west4-b',
				'europe-west4-c',
				'europe-west1-b',
				'europe-west1-d',
				'europe-west1-c',
				'europe-west3-c',
				'europe-west3-a',
				'europe-west3-b',
				'europe-west2-c',
				'europe-west2-b',
				'europe-west2-a',
				'asia-east1-b',
				'asia-east1-a',
				'asia-east1-c',
				'asia-southeast1-b',
				'asia-southeast1-a',
				'asia-southeast1-c',
				'asia-northeast1-b',
				'asia-northeast1-c',
				'asia-northeast1-a',
				'asia-south1-c',
				'asia-south1-b',
				'asia-south1-a',
				'australia-southeast1-b',
				'australia-southeast1-c',
				'australia-southeast1-a',
				'southamerica-east1-b',
				'southamerica-east1-c',
				'southamerica-east1-a',
				'asia-east2-a',
				'asia-east2-b',
				'asia-east2-c',
				'asia-northeast2-a',
				'asia-northeast2-b',
				'asia-northeast2-c',
				'asia-northeast3-a',
				'asia-northeast3-b',
				'asia-northeast3-c',
				'asia-southeast2-a',
				'asia-southeast2-b',
				'asia-southeast2-c',
				'europe-north1-a',
				'europe-north1-b',
				'europe-north1-c',
				'europe-west6-a',
				'europe-west6-b',
				'europe-west6-c',
				'northamerica-northeast1-a',
				'northamerica-northeast1-b',
				'northamerica-northeast1-c',
				'us-west2-a',
				'us-west2-b',
				'us-west2-c',
				'us-west3-a',
				'us-west3-b',
				'us-west3-c',
				'us-west4-a',
				'us-west4-b',
				'us-west4-c'
		)]
		[Alias("z")]
		[String]
		$zone,

		[Parameter(Mandatory=$TRUE,
				HelpMessage="Enter a docker hub image")]
		[Alias("c")]
		[String]
		$containerImage
	)
	gcloud compute --project "leaderless-zookeeper" instances create-with-container "zook-client$('{0:d3}' -f $number)" `
	--container-image "$containerImage" --zone $zone --machine-type "n1-standard-2" `
	--subnet "default" --maintenance-policy "MIGRATE" --service-account "858944573210-compute@developer.gserviceaccount.com" `
	--scopes=default --tags "zook-client" --image "cos-stable-85-13310-1209-17" --image-project "cos-cloud" --boot-disk-size "10" `
	--boot-disk-type "pd-standard" --boot-disk-device-name "zook-client$('{0:d3}' -f $number)"
}

function Add-Server {
	Param (
		[Parameter(Mandatory=$FALSE,
			HelpMessage="Enter a number of machines to create.")]
		[Alias("n")]
		[int]
		$number = 1,

		[Parameter(Mandatory=$TRUE,
				HelpMessage="Enter a docker hub image")]
		[Alias("c")]
		[String]
		$containerImage
	)

	$existing_server_count = $(gcloud compute instances list --filter="tags:zook-server" | measure-object -line).Lines - 1

	if ($existing_server_count -lt 3) {
		echo "ERROR: make sure there's at least 3 servers already running"
		return
	}

	$new_cluster_size = $existing_server_count + $number

	$OS = $PSVersionTable.OS | cut -d ' ' -f1
	$zones_file_path = ""
	if ($OS -eq 'Microsoft') {
		$zones_file_path = ".\Zones_Files\zones_file$new_cluster_size"
	}

	if ($OS -eq 'Linux') {
		$zones_file_path = "./Zones_Files/zones_file$new_cluster_size"
	}

	[string[]]$zones = Get-Content -Path $zones_file_path

	prep-env $new_cluster_size $zones_file_path

	Update-Servers

	$scriptBlock = {
		param($n, $z, $c)
		Write-Host $n $z $c
		Start-Server $n $z $c
	}

	($existing_server_count + 1)..$new_cluster_size | ForEach-Object {
		Start-Job -ScriptBlock $scriptBlock -ArgumentList  $_, $zones[$($_-1)], $containerImage
	}

	get-job

	While (Get-Job -State "Running")
	{
	  Start-Sleep 5
	}

	Get-Job | % { Receive-Job $_.Id; Remove-Job $_.Id }

}

function YCSB-Remote {
	Param (
		[Parameter(Mandatory=$TRUE, HelpMessage="Enter target host:port")]
		[String]
		$target_host,

		[Parameter(Mandatory=$FALSE, HelpMessage="Zone")]
		[String]
		$zone = "us-east1-c",

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter record count")]
		[int]
		$recordcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter opeation count")]
		[int]
		$operationcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Load Workload")]
		[String]
		$workload_load = "workload_80_20",

		[Parameter(Mandatory=$FALSE, HelpMessage="Run Workload(s)")]
		[String]
		$workload_run = "workload_100_0,workload_20_80,workload_50_50,workload_80_20"
	)

	gcloud compute --project "leaderless-zookeeper" instances create-with-container "ycsb-load" `
	--container-image "docker.io/atopcu/ycsb" --zone $zone --machine-type "n1-standard-2" `
	--subnet "default" --maintenance-policy "MIGRATE" --service-account "858944573210-compute@developer.gserviceaccount.com" `
	--scopes=default --tags "test-vm" --image "cos-stable-85-13310-1209-17" --image-project "cos-cloud" --boot-disk-size "10" `
	--boot-disk-type "pd-standard" --boot-disk-device-name "ycsb-load" --container-env=RUN_TYPE=load --container-env=CONNECT_STRING=$target_host `
	--container-env=RECORD_COUNT=$recordcount --container-env=OPERATION_COUNT=$operationcount --container-env=WORKLOAD_LOAD=$workload_load `
	--container-env=^@^WORKLOAD_RUN=$workload_run
}


function YCSB-Load-Remote {
	Param (
		[Parameter(Mandatory=$TRUE, HelpMessage="Enter target host:port")]
		[String]
		$target_host,

		[Parameter(Mandatory=$FALSE, HelpMessage="Zone")]
		[String]
		$zone = "us-east1-c",

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter record count")]
		[int]
		$recordcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter opeation count")]
		[int]
		$operationcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Workload")]
		[String]
		$workload = "workload_80_20"
	)

	gcloud compute --project "leaderless-zookeeper" instances create-with-container "ycsb-load" `
	--container-image "docker.io/atopcu/ycsb" --zone $zone --machine-type "n1-standard-2" `
	--subnet "default" --maintenance-policy "MIGRATE" --service-account "858944573210-compute@developer.gserviceaccount.com" `
	--scopes=default --tags "test-vm" --image "cos-stable-85-13310-1209-17" --image-project "cos-cloud" --boot-disk-size "10" `
	--boot-disk-type "pd-standard" --boot-disk-device-name "ycsb-load" --container-env=RUN_TYPE=load --container-env=CONNECT_STRING=$target_host `
	--container-env=RECORD_COUNT=$recordcount --container-env=OPERATION_COUNT=$operationcount --container-env=WORKLOAD=$workload --container-env=RECORD_COUNT=$recordcount
}

function YCSB-Run-Remote {
	Param (
		[Parameter(Mandatory=$TRUE, HelpMessage="Enter target host:port")]
		[String]
		$target_host,

		[Parameter(Mandatory=$FALSE, HelpMessage="Zone")]
		[String]
		$zone = "us-east1-c",

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter record count")]
		[int]
		$recordcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter opeation count")]
		[int]
		$operationcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Workload")]
		[String]
		$workload = "workload_80_20"
	)

	gcloud compute --project "leaderless-zookeeper" instances create-with-container "ycsb-run" `
	--container-image "docker.io/atopcu/ycsb" --zone $zone --machine-type "n1-standard-2" `
	--subnet "default" --maintenance-policy "MIGRATE" --service-account "858944573210-compute@developer.gserviceaccount.com" `
	--scopes=default --tags "test-vm" --image "cos-stable-85-13310-1209-17" --image-project "cos-cloud" --boot-disk-size "10" `
	--boot-disk-type "pd-standard" --boot-disk-device-name "ycsb-run" --container-env=RUN_TYPE=run --container-env=CONNECT_STRING=$target_host `
	--container-env=RECORD_COUNT=$recordcount --container-env=OPERATION_COUNT=$operationcount --container-env=WORKLOAD=$workload --container-env=RECORD_COUNT=$recordcount
}

function YCSB-Load-Local {
	Param (
		[Parameter(Mandatory=$TRUE, HelpMessage="Enter target host:port")]
		[String]
		$target_host,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter record count")]
		[int]
		$recordcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter opeation count")]
		[int]
		$operationcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Workload")]
		[String]
		$workload = "workload_80_20"
	)
	$OS = $PSVersionTable.OS | cut -d ' ' -f1

	$existing_server_count = $(gcloud compute instances list --filter="tags:zook-server" | measure-object -line).Lines - 1

	if ($OS -eq 'Microsoft') {
		.\YCSB\YCSB-master\bin\ycsb.bat load zookeeper -s -P ".\YCSB\workloads\$workload" -p zookeeper.connectString="$target_host" -p recordcount="$recordcount" > .\YCSB\outputs\load-"$workload"-"$existing_server_count"-"$recordcount"-"$operationcount".txt
	}

	if ($OS -eq 'Linux') {
		cd ./YCSB/YCSB-master/
		./bin/ycsb load zookeeper -s -P "../workloads/$workload" -p zookeeper.connectString="$target_host" -p recordcount="$recordcount" > ../outputs/load-"$workload"-"$existing_server_count"-"$recordcount"-"$operationcount".txt
		cd ../..
	}


}

function YCSB-Run-Local {
	Param (
		[Parameter(Mandatory=$TRUE, HelpMessage="Enter target host:port")]
		[String]
		$target_host,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter record count")]
		[int]
		$recordcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter opeation count")]
		[int]
		$operationcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Workload")]
		[String]
		$workload = "workload_80_20"
	)

	$OS = $PSVersionTable.OS | cut -d ' ' -f1

	$existing_server_count = $(gcloud compute instances list --filter="tags:zook-server" | measure-object -line).Lines - 1

	if ($OS -eq 'Microsoft') {
		.\YCSB\YCSB-master\bin\ycsb.bat run zookeeper -s -P ".\YCSB\workloads\$workload" -p zookeeper.connectString="$target_host" -p recordcount="$recordcount" > .\YCSB\outputs\run-"$workload"-"$existing_server_count"-"$recordcount"-"$operationcount".txt
	}

	if ($OS -eq 'Linux') {
		cd ./YCSB/YCSB-master/
		./bin/ycsb run zookeeper -s -P "../workloads/$workload" -p zookeeper.connectString="$target_host" -p recordcount="$recordcount" > ../outputs/run-"$workload"-"$existing_server_count"-"$recordcount"-"$operationcount".txt
		cd ../..
	}


}

function YCSB-Run-Local-Cluster {
	Param (
		[Parameter(Mandatory=$FALSE, HelpMessage="Enter record count")]
		[int]
		$recordcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter opeation count")]
		[int]
		$operationcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Workload")]
		[String]
		$workload = "workload_80_20"
	)

	$vms = Create-VMTable

	# empty array
	$ipsArray = @()

	1..$vms.count | foreach-object {$ipsArray = $ipsArray + ($vms[$_].EXTERNAL_IP + ":2181" )}

	$connectString = $ipsArray -Join ","

	$existing_server_count = $vms.count

	$OS = $PSVersionTable.OS | cut -d ' ' -f1

	if ($OS -eq 'Microsoft') {
		.\YCSB\YCSB-master\bin\ycsb.bat run zookeeper -s -P ".\YCSB\workloads\$workload" -p zookeeper.connectString="$connectString" -p recordcount="$recordcount" > .\YCSB\outputs\run-cluster-"$workload"-"$existing_server_count"-"$recordcount"-"$operationcount".txt
	}

	if ($OS -eq 'Linux') {
		cd ./YCSB/YCSB-master/
		./bin/ycsb run zookeeper -s -P "../workloads/$workload" -p zookeeper.connectString="$connectString" -p recordcount="$recordcount" > ../outputs/run-cluster-"$workload"-"$existing_server_count"-"$recordcount"-"$operationcount".txt
		cd ../..
	}
}



# Assumes no vms are up
function YCSB-Test-All-Single-Connection {

	Param (
		[Parameter(Mandatory=$FALSE, HelpMessage="Enter record count")]
		[int]
		$recordcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter opeation count")]
		[int]
		$operationcount = 1000,

		[Parameter(Mandatory=$TRUE,
				HelpMessage="Enter a docker hub image")]
		[Alias("c")]
		[String]
		$containerImage
	)

	# Iterate from n = 3 to 13
	for ($n = 3; $n -le 12; $n++) {
		echo "Starting ensemble of $n..."

		# Startup the cluster of size n
		start-many $n $containerImage

		# YCSB-Load-Local
		$vms = Create-VMTable
		$host_ip = $vms[1].EXTERNAL_IP

		echo "Host ip: $host_ip"
		echo $running_machines

		echo "Waiting for 600 seconds..."
		Start-Sleep 600

		YCSB-Load-Local $host_ip $recordcount $operationcount

		$workloads = (Get-ChildItem .\YCSB\workloads\*).Name

		# Iterate over all workloads
		foreach ($w in $workloads) {

			# YCSB-Run-Local
			YCSB-Run-Local $host_ip $recordcount $operationcount $w

		}

		echo "Deleting ensemble of $n..."

		# Delete VMs
		Delete-Servers
		echo "Waiting for 60 seconds..."
		Start-Sleep 60
	}
}


# Assumes no vms are up
function YCSB-Test-All-Cluster {

	Param (
		[Parameter(Mandatory=$FALSE, HelpMessage="Enter record count")]
		[int]
		$recordcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter opeation count")]
		[int]
		$operationcount = 1000,

		[Parameter(Mandatory=$TRUE,
				HelpMessage="Enter a docker hub image")]
		[Alias("c")]
		[String]
		$containerImage
	)

	# Iterate from n = 3 to 13
	for ($n = 3; $n -le 12; $n++) {
		echo "Starting ensemble of $n..."

		# Startup the cluster of size n
		start-many $n $containerImage

		# YCSB-Load-Local
		$vms = Create-VMTable
		$host_ip = $vms[1].EXTERNAL_IP

		echo "Host ip: $host_ip"

		echo "Waiting for 600 seconds..."
		Start-Sleep 600

		YCSB-Load-Local $host_ip $recordcount $operationcount

		$workloads = (Get-ChildItem .\YCSB\workloads\*).Name

		# Iterate over all workloads
		foreach ($w in $workloads) {

			# YCSB-Run-Local
			YCSB-Run-Local-Cluster $recordcount $operationcount $w

		}

		echo "Deleting ensemble of $n..."

		# Delete VMs
		Delete-Servers
		echo "Waiting for 60 seconds..."
		Start-Sleep 60
	}
}


function Create-VMTable {

	$table = gcloud compute instances list --sort-by="name" --filter="tags:zook-server" `
		--format="table(NAME,ZONE,MACHINE_TYPE,INTERNAL_IP,EXTERNAL_IP,STATUS)"

	$headers = $($table[0] | tr -s ' ').split()

	$hash = @{}

	for ($i = 1; $i -lt $table.length; $i++) {
		$row = $($table[$i] | tr -s ' ' ).split()
		$rowmap = @{
					$headers[0] = $row[0];
					$headers[1] = $row[1];
					$headers[2] = $row[2];
					$headers[3] = $row[3];
					$headers[4] = $row[4];
					$headers[5] = $row[5]
		}

		$hash[$i] = $rowmap
	}

	return $hash
}

function Create-Test-VMTable {

	$table = gcloud compute instances list --sort-by="name" --filter="tags:test-vm" `
		--format="table(NAME,ZONE,MACHINE_TYPE,INTERNAL_IP,EXTERNAL_IP,STATUS)"

	$headers = $($table[0] | tr -s ' ').split()

	$hash = @{}

	for ($i = 1; $i -lt $table.length; $i++) {
		$row = $($table[$i] | tr -s ' ' ).split()
		$rowmap = @{
			$headers[0] = $row[0];
			$headers[1] = $row[1];
			$headers[2] = $row[2];
			$headers[3] = $row[3];
			$headers[4] = $row[4];
			$headers[5] = $row[5]
		}

		$hash[$i] = $rowmap
	}

	return $hash


}

function Smoketest-Run-Cluster-Remote {
	Param (
		[Parameter(Mandatory=$FALSE, HelpMessage="Enter znode count")]
		[int]
		$znodecount = 100,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter znode size")]
		[int]
		$znodesize = 100,

		[Parameter(Mandatory=$FALSE, HelpMessage="Zone")]
		[String]
		$zone = "us-east1-c"
	)

	$vms = Create-VMTable

	# empty array
	$ipsArray = @()

	1..$vms.count | foreach-object {$ipsArray = $ipsArray + ($vms[$_].EXTERNAL_IP + ":2181" )}

	$connectString = $ipsArray -Join ","
	gcloud compute --project "leaderless-zookeeper" instances create-with-container "zk-smoketest" `
	--container-image "docker.io/atopcu/zk-smoketest" --zone $zone --machine-type "n1-standard-2" `
	--subnet "default" --maintenance-policy "MIGRATE" --service-account "858944573210-compute@developer.gserviceaccount.com" `
	--scopes=default --tags "test-vm" --image "cos-stable-85-13310-1209-17" --image-project "cos-cloud" --boot-disk-size "10" `
	--boot-disk-type "pd-standard" --boot-disk-device-name "zk-smoketest" --container-env=^@^CONNECT_STRING=$connectString `
	--container-env=Z_NODE_COUNT=$znodecount --container-env=Z_NODE_SIZE=$znodesize
}

#run on linux
function Smoketest-Run-Cluster {
	Param (
		[Parameter(Mandatory=$FALSE, HelpMessage="Enter znode count")]
		[int]
		$znodecount = 100,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter znode size")]
		[int]
		$znodesize = 100
	)

	$vms = Create-VMTable

	# empty array
	$ipsArray = @()

	1..$vms.count | foreach-object {$ipsArray = $ipsArray + ($vms[$_].EXTERNAL_IP + ":2181" )}

	$connectString = $ipsArray -Join ","

	echo $connectString

	$existing_server_count = $vms.count

	python ../zk-smoketest/zk-latencies.py --servers "$connectString" --znode_count=$znodecount --znode_size=$znodesize --synchronous --verbose > "zk-latency-output-$existing_server_count.txt"
}


function Smoketest-All {

	Param (
		[Parameter(Mandatory=$FALSE, HelpMessage="Enter znode count")]
		[int]
		$znodecount = 100,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter znode size")]
		[int]
		$znodesize = 100,

		[Parameter(Mandatory=$TRUE,
				HelpMessage="Enter a docker hub image")]
		[Alias("c")]
		[String]
		$containerImage
	)

	# Iterate from n = 3 to 13
	for ($n = 3; $n -le 12; $n++) {
		echo "Starting ensemble of $n..."

		# Startup the cluster of size n
		start-many $n $containerImage

		# YCSB-Load-Local
		$vms = Create-VMTable
		$host_ip = $vms[1].EXTERNAL_IP

		echo "Host ip: $host_ip"

		echo "Waiting for 60 seconds..."
		Start-Sleep 60

		YCSB-Load-Local $host_ip 1000 1000

		Smoketest-Run-Cluster $znodecount $znodesize

		echo "Deleting ensemble of $n in 60 seconds..."
		Start-Sleep 60

		# Delete VMs
		Delete-Servers
		echo "Waiting for 60 seconds..."
		Start-Sleep 60
	}
}


# Assumes no vms are up
function YCSB-Smoketest-Test-All-Cluster {

	Param (
		[Parameter(Mandatory=$FALSE, HelpMessage="Enter record count")]
		[int]
		$recordcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter opeation count")]
		[int]
		$operationcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter znode count")]
		[int]
		$znodecount = 100,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter znode size")]
		[int]
		$znodesize = 100,

		[Parameter(Mandatory=$TRUE,
				HelpMessage="Enter a docker hub image")]
		[Alias("c")]
		[String]
		$containerImage
	)

	# Iterate from n = 3 to 13
	for ($n = 3; $n -le 12; $n++) {
		echo "Starting ensemble of $n..."

		# Startup the cluster of size n
		start-many $n $containerImage

		# YCSB-Load-Local
		$vms = Create-VMTable
		$host_ip = $vms[1].EXTERNAL_IP

		echo "Host ip: $host_ip"

		echo "Waiting for 600 seconds..."
		Start-Sleep 600

		YCSB-Load-Local $host_ip $recordcount $operationcount

		$workloads = (Get-ChildItem .\YCSB\workloads\*).Name

		# Iterate over all workloads
		foreach ($w in $workloads) {

			# YCSB-Run-Local
			YCSB-Run-Local-Cluster $recordcount $operationcount $w

		}

		Smoketest-Run-Cluster $znodecount $znodesize

		echo "Deleting ensemble of $n..."

		# Delete VMs
		Delete-Servers
		echo "Waiting for 60 seconds..."
		Start-Sleep 60
	}
}

# Assumes no vms are up
function YCSB-Smoketest-Test-All-Cluster-Remote {

	Param (
		[Parameter(Mandatory=$TRUE,
				HelpMessage="Enter a docker hub image")]
		[Alias("c")]
		[String]
		$containerImage,

		[Parameter(Mandatory=$TRUE,
				HelpMessage="Enter a prefix for each test output")]
		[Alias("p")]
		[String]
		$outputprefix,

		[Parameter(Mandatory=$TRUE,
				HelpMessage="Enter starting cluster size")]
		[Alias("n")]
		[int]
		$startingClusterSize,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter fail limit")]
		[int]
		$faillimit = 1,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter record count")]
		[int]
		$recordcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter opeation count")]
		[int]
		$operationcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter znode count")]
		[int]
		$znodecount = 100,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter znode size")]
		[int]
		$znodesize = 100
	)


	for ($n = $startingClusterSize; $n -le 12; $n++) {
		echo "Starting ensemble of $n..."

		# Startup the cluster of size n
		start-many $n $containerImage $faillimit

		# Create Vm Table
		$vms = Create-VMTable
		$host_ip = $vms[1].EXTERNAL_IP

		echo "Host ip: $host_ip"

		echo "Waiting for 600 seconds..."
		Start-Sleep 600

		echo "Running YCSB load..."

		YCSB-Remote "$($host_ip):2181" "us-east1-c" $recordcount $operationcount

		$vmt = Create-Test-VMTable

		echo "Attempting to download YCSB load results..."

		# Download result
		wget "http://$($vmt[1].EXTERNAL_IP)/run-cluster.load.workload_80_20.$recordcount.$operationcount.txt" -t 0 --retry-connrefused `
			--waitretry=10 -O ".\Test_Results\YCSB\$n\$outputprefix.run-cluster.load.workload_80_20.$recordcount.$operationcount.txt"

		$workloads = (Get-ChildItem .\YCSB\workloads\*).Name

		# Iterate over all workloads
		foreach ($w in $workloads) {

			echo "Attempting to download YCSB run $w results..."

			# Download result
			wget "http://$($vmt[1].EXTERNAL_IP)/run-cluster.run.$w.$recordcount.$operationcount.txt" -t 0 --retry-connrefused `
				--waitretry=10 -O ".\Test_Results\YCSB\$n\$outputprefix.run-cluster.run.$w.$recordcount.$operationcount.txt"

		}

		echo "Deleting YCSB test server..."

		# Delete Test vm
		Delete-Test-Servers

		echo "Doing ZK-Smoketest..."

		Smoketest-Run-Cluster-Remote $znodecount $znodesize
		$vmt = Create-Test-VMTable

		echo "Attempting to download Smoketest results..."

		# Download result
		wget "http://$($vmt[1].EXTERNAL_IP)/output.txt" -t 0 --retry-connrefused `
				--waitretry=10 -O ".\Test_Results\Zk-Smoketest\$n\$outputprefix.output.$znodecount.$znodesize.txt"

		echo "Waiting for 60 seconds before deleting all vms..."
		Start-Sleep 60

		echo "Deleting ensemble of $n..."

		# Delete VMs
		Delete-Servers

		echo "Deleting test server..."
		# Delete Test vm
		Delete-Test-Servers
	}
}

function YCSB-Smoketest-Test-FailLimit-Cluster-Remote {

	Param (
		[Parameter(Mandatory=$TRUE,
				HelpMessage="Enter a docker hub image")]
		[Alias("c")]
		[String]
		$containerImage,

		[Parameter(Mandatory=$TRUE,
				HelpMessage="Enter a prefix for each test output")]
		[Alias("p")]
		[String]
		$outputprefix,

		[Parameter(Mandatory=$TRUE,
				HelpMessage="Enter starting cluster size")]
		[Alias("n")]
		[int]
		$startingClusterSize,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter record count")]
		[int]
		$recordcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter opeation count")]
		[int]
		$operationcount = 1000,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter znode count")]
		[int]
		$znodecount = 100,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter znode size")]
		[int]
		$znodesize = 100
	)


	for ($n = 2; $n -le [math]::floor($startingClusterSize/2); $n++) {
		echo "Starting ensemble of $startingClusterSize..."

		# Startup the cluster of size n
		start-many $startingClusterSize $containerImage $n

		# Create Vm Table
		$vms = Create-VMTable
		$host_ip = $vms[1].EXTERNAL_IP

		echo "Host ip: $host_ip"

		echo "Waiting for 600 seconds..."
#		Start-Sleep 600

		echo "Running YCSB load..."

		YCSB-Remote "$($host_ip):2181" "us-east1-c" $recordcount $operationcount

		$vmt = Create-Test-VMTable

		echo "Attempting to download YCSB load results..."

		# Download result
		wget "http://$($vmt[1].EXTERNAL_IP)/run-cluster.load.workload_80_20.$recordcount.$operationcount.txt" -t 0 --retry-connrefused `
			--waitretry=10 -O ".\Test_Results\YCSB\$startingClusterSize\$outputprefix.$n.run-cluster.load.workload_80_20.$recordcount.$operationcount.txt"

		$workloads = (Get-ChildItem .\YCSB\workloads\*).Name

		# Iterate over all workloads
		foreach ($w in $workloads) {

			echo "Attempting to download YCSB run $w results..."

			# Download result
			wget "http://$($vmt[1].EXTERNAL_IP)/run-cluster.run.$w.$recordcount.$operationcount.txt" -t 0 --retry-connrefused `
				--waitretry=10 -O ".\Test_Results\YCSB\$startingClusterSize\$outputprefix.$n.run-cluster.run.$w.$recordcount.$operationcount.txt"

		}

		echo "Deleting YCSB test server..."

		# Delete Test vm
		Delete-Test-Servers

		echo "Doing ZK-Smoketest..."

		Smoketest-Run-Cluster-Remote $znodecount $znodesize
		$vmt = Create-Test-VMTable

		echo "Attempting to download Smoketest results..."

		# Download result
		wget "http://$($vmt[1].EXTERNAL_IP)/output.txt" -t 0 --retry-connrefused `
			--waitretry=10 -O ".\Test_Results\Zk-Smoketest\$startingClusterSize\$outputprefix.$n.output.$znodecount.$znodesize.txt"

		echo "Waiting for 60 seconds before deleting all vms..."
		Start-Sleep 60

		echo "Deleting ensemble of $startingClusterSize..."

		# Delete VMs
		Delete-Servers

		echo "Deleting test server..."
		# Delete Test vm
		Delete-Test-Servers
	}
}

