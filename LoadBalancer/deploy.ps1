
function Select-Option {
    param (
        [array]$items,
        [bool]$includeNetwork
    )

    if ($includeNetwork) {
        $border = "-------------------------------------------------------------------------------------------------------------"
        Write-Host "`n$border"
        Write-Host ("{0,-5} {1,-40} {2,-30} {3,-40}" -f "No.", "ID", "Name", "Network")
        Write-Host $border
    } else {
        $border = "-------------------------------------------------------------"
        Write-Host "`n$border"
        Write-Host ("{0,-5} {1,-40} {2,-30}" -f "No.", "ID", "Name")
        Write-Host $border
    }

    for ($i = 0; $i -lt $items.Count; $i++) {
        $item = $items[$i]
        if ($includeNetwork) {
            Write-Host ("{0,-5} {1,-40} {2,-30} {3,-40}" -f ($i+1), $item.id, $item.name, $item.network_id)
        } else {
            Write-Host ("{0,-5} {1,-40} {2,-30}" -f ($i+1), $item.id, $item.name)
        }
    }

    Write-Host "$border"

    $validInput = $false
    $choice = 0
    while (-not $validInput) {
        $input = Read-Host "Select an option (1-$($items.Count))"
        if ([int]::TryParse($input, [ref]$choice) -and $choice -ge 1 -and $choice -le $items.Count) {
            $validInput = $true
        } else {
            Write-Host "Invalid selection. Please choose a number between 1 and $($items.Count)."
        }
    }

    return $items[$choice - 1]
}

# Fetch Clusters
Write-Host "`nFetching available clusters..."
$clustersJson = openstack --insecure cluster list -f json | ConvertFrom-Json
$clusterSelection = Select-Option $clustersJson $false
$cluster_id = $clusterSelection.id

# Fetch Subnets
Write-Host "`nFetching available subnets..."
$subnetsJson = openstack --insecure subnet list -f json | ConvertFrom-Json
$subnetObjects = @()
foreach ($subnet in $subnetsJson) {
    $subnetObjects += [pscustomobject]@{
        id         = $subnet.ID
        name       = $subnet.Name
        network_id = $subnet.Network
    }
}

Write-Host "`nSelect VIP (External) Subnet:"
$vip_subnet_selection = Select-Option $subnetObjects $true
$vip_subnet = $vip_subnet_selection.id

Write-Host "`nSelect Pool (Internal) Subnet:"
$pool_subnet_selection = Select-Option $subnetObjects $true
$pool_subnet = $pool_subnet_selection.id

# Ask user for the stack name
$stack_name = Read-Host "Enter the stack name"

# Execute OpenStack command
Write-Host "`nDeploying Heat stack..."
openstack --insecure stack create -t lb_autoscale.yaml `
  --parameter cluster_id="$cluster_id" `
  --parameter vip_subnet="$vip_subnet" `
  --parameter pool_subnet="$pool_subnet" `
  --wait "$stack_name"

