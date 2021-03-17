


function Start-VM {
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
		
		[Parameter(Mandatory=$FALSE, 
			HelpMessage="Enter the path to the environment file.")]
		[Alias("p")]
		[String]
		$env_file_path = ".\Environment_Files",
		
		[Parameter(Mandatory=$FALSE, 
			HelpMessage="Enter the environment file name.")]
		[Alias("e")]
		[String]
		$env_file = "env_file"
	)
	
	gcloud compute --project "leaderless-zookeeper" instances create-with-container "zook$('{0:d3}' -f $number)" `
	--container-image "docker.io/zookeeper:3.6.2" --zone $zone --machine-type "n1-standard-8" `
	--subnet "default" --maintenance-policy "MIGRATE" --service-account "858944573210-compute@developer.gserviceaccount.com" `
	--scopes=default --tags "http-server" --image "cos-stable-85-13310-1209-17" --image-project "cos-cloud" --boot-disk-size "10" `
	--boot-disk-type "pd-standard" --boot-disk-device-name "zook$('{0:d3}' -f $number)" --container-env=ZOO_MY_ID=$number --container-env-file="$($env_file_path)\$env_file"
}


function Update-VM {
	Param (
		[Parameter(Mandatory=$TRUE, 
			HelpMessage="Enter an integer to identify the vm.")] 
		[Alias("n")]
		[int]
		$number,
		
		[Parameter(Mandatory=$FALSE, 
			HelpMessage="Enter the path to the environment file.")]
		[Alias("p")]
		[String]
		$env_file_path = ".\Environment_Files",
		
		[Parameter(Mandatory=$FALSE, 
			HelpMessage="Enter the environment file name.")]
		[Alias("e")]
		[String]
		$env_file = "env_file"
	)
	
	gcloud compute --project "leaderless-zookeeper" instances update-container "zook$('{0:d3}' -f $number)" `
	--container-env=ZOO_MY_ID=$number --container-env-file="$($env_file_path)\$env_file"
}


function Update-VM {
	Param (
		[Parameter(Mandatory=$TRUE, 
			HelpMessage="Enter a number of machines.")] 
		[Alias("n")]
		[int]
		$number,
		
		[Parameter(Mandatory=$FALSE, 
			HelpMessage="Enter the path to the environment file.")]
		[Alias("p")]
		[String]
		$env_file_path = ".\Environment_Files",
		
		[Parameter(Mandatory=$FALSE, 
			HelpMessage="Enter the environment file name.")]
		[Alias("e")]
		[String]
		$env_file = "env_file"
	)
	
	gcloud compute --project "leaderless-zookeeper" instances update-container "zook$('{0:d3}' -f $number)" `
	--container-env=ZOO_MY_ID=$number --container-env-file="$($env_file_path)\$env_file"
}
