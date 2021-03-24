


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
		$zone

	)

	$env_file_path = ".\Environment_Files\env_file"

	gcloud compute --project "leaderless-zookeeper" instances create-with-container "zook$('{0:d3}' -f $number)" `
	--container-image "docker.io/zookeeper:3.6.2" --zone $zone --machine-type "n1-standard-2" `
	--subnet "default" --maintenance-policy "MIGRATE" --service-account "858944573210-compute@developer.gserviceaccount.com" `
	--scopes=default --tags "zook-server" --image "cos-stable-85-13310-1209-17" --image-project "cos-cloud" --boot-disk-size "10" `
	--boot-disk-type "pd-standard" --boot-disk-device-name "zook$('{0:d3}' -f $number)" --container-env=ZOO_MY_ID=$number `
	--container-env-file=$env_file_path
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

	$env_file_path = ".\Environment_Files\env_file"

	gcloud compute --project "leaderless-zookeeper" instances update-container "zook$('{0:d3}' -f $number)" `
	--container-env=ZOO_MY_ID=$number  --container-env-file=$env_file_path --zone=$zone
}

function Update-Servers {
	
	$existing_server_count = $(gcloud compute instances list --filter="tags:zook-server" | measure-object -line).Lines - 1
	
	$zones_file_path = ".\Zones_Files\zones_file$existing_server_count"
	
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

	$env_file_template_path = ".\Environment_Files\env_file$number"
	$env_file_path = ".\Environment_Files\env_file"

	cp -Force $env_file_template_path $env_file_path



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
		$number = 3
	)
	$zones_file_path = ".\Zones_Files\zones_file$number"
	
	[string[]]$zones = Get-Content -Path $zones_file_path

	prep-env $number $zones_file_path

	$scriptBlock = {
		param($n, $z)
		Write-Host $n $z
		Start-Server $n $z
	}

	1..$number | ForEach-Object {
		Start-Job -ScriptBlock $scriptBlock -ArgumentList  $_, $zones[$($_-1)]
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
		
		[Parameter(Mandatory=$TRUE,
			HelpMessage="Enter zone to identify the vm.")]
		[Alias("z")]
		[string]
		$zone
	)

	gcloud compute instances delete $name --zone=$zone
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
		$zone
	)
	gcloud compute --project "leaderless-zookeeper" instances create-with-container "zook-client$('{0:d3}' -f $number)" `
	--container-image "docker.io/zookeeper:3.6.2" --zone $zone --machine-type "n1-standard-2" `
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
		$number = 1
	)

	$existing_server_count = $(gcloud compute instances list --filter="tags:zook-server" | measure-object -line).Lines - 1
	
	if ($existing_server_count -lt 3) {
		echo "ERROR: make sure there's at least 3 servers already running"
		return
	}
	
	$new_cluster_size = $existing_server_count + $number
	
	$zones_file_path = ".\Zones_Files\zones_file$new_cluster_size"
	
	[string[]]$zones = Get-Content -Path $zones_file_path

	prep-env $new_cluster_size $zones_file_path
	
	Update-Servers

	$scriptBlock = {
		param($n, $z)
		Write-Host $n $z
		Start-Server $n $z
	}

	($existing_server_count + 1)..$new_cluster_size | ForEach-Object {
		Start-Job -ScriptBlock $scriptBlock -ArgumentList  $_, $zones[$($_-1)]
	}

	get-job

	While (Get-Job -State "Running")
	{
	  Start-Sleep 5
	}

	Get-Job | % { Receive-Job $_.Id; Remove-Job $_.Id }

}

function YCSB-Load-Local {
	Param (
		[Parameter(Mandatory=$TRUE, HelpMessage="Enter target host:port")]
		[String]
		$target_host,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter record count")]
		[int]
		$recordcount = 100,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter opeation count")]
		[int]
		$operationcount = 100,

		[Parameter(Mandatory=$FALSE, HelpMessage="Workload")]
		[String]
		$workload = "workload_80_20"
	)

	$existing_server_count = $(gcloud compute instances list --filter="tags:zook-server" | measure-object -line).Lines - 1

	.\YCSB\YCSB-master\bin\ycsb.bat load zookeeper -s -P ".\YCSB\workloads\$workload" -p zookeeper.connectString="$target_host" -p recordcount="$recordcount" > .\YCSB\outputs\load-"$workload"-"$existing_server_count"-"$recordcount"-"$operationcount".txt
}

function YCSB-Run-Local {
	Param (
		[Parameter(Mandatory=$TRUE, HelpMessage="Enter target host:port")]
		[String]
		$target_host,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter record count")]
		[int]
		$recordcount = 100,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter opeation count")]
		[int]
		$operationcount = 100,

		[Parameter(Mandatory=$FALSE, HelpMessage="Workload")]
		[String]
		$workload = "workload_80_20"
	)

	$existing_server_count = $(gcloud compute instances list --filter="tags:zook-server" | measure-object -line).Lines - 1

	.\YCSB\YCSB-master\bin\ycsb.bat run zookeeper -s -P ".\YCSB\workloads\$workload" -p zookeeper.connectString="$target_host" -p recordcount="$recordcount" > .\YCSB\outputs\run-"$workload"-"$existing_server_count"-"$recordcount"-"$operationcount".txt
}



# Assumes no vms are up 
function YCSB-Test-All {

	Param (
		[Parameter(Mandatory=$FALSE, HelpMessage="Enter record count")]
		[int]
		$recordcount = 100,

		[Parameter(Mandatory=$FALSE, HelpMessage="Enter opeation count")]
		[int]
		$operationcount = 100
	)

	# Iterate from n = 3 to 13
	for ($n = 3; $n -le 13; $n++) {
		echo "Starting ensemble of $n..."
	
		# Startup the cluster of size n
		start-many $n
		
		# YCSB-Load-Local
		$vms = Create-VMTable
		$host_ip = $vms[1].EXTERNAL_IP
		
		echo "Host ip: $host_ip"
		echo $running_machines
		
		echo "Waiting for 60 seconds..."
		Start-Sleep 60
		
		YCSB-Load-Local $host_ip $recordcount $operationcount
		
		$workloads = (ls .\YCSB\workloads\*).Name
		
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