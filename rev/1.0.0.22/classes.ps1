
class adminPage{
    [string] $page
    [hashtable[]] $requestParams
    [hashtable] $links 
    [object] $response
    [string] $tokensPath
    [string] $currentToken
    hidden [string] $adminCommand
    adminPage($page,$requestParams,$tokensPath,$currentToken)
    {
        $this.requestParams = $requestParams
        $this.page = $page
        $this.tokensPath = $tokensPath
        $this.currentToken = $currentToken
        
        switch -Wildcard ($this.page)
        {
            '/stop' {$this.stop()}
            '/clearcache' {$this.clearcache()}
            "/user*" {$this.user()}
            default {$this.default()}
        }
        
    }
    [void] makeLinks([string]$thisPage,[array]$children)
    {
        $this.links = @{
            this = $thisPage
            children = $children
            parent = '/admin'
        }
        
    }
    [void] stop()
    {
        $this.adminCommand = 'stop'
        $this.makeLinks('/admin/stop',$null)
        $items = [pscustomobject] @{
            message = 'Server requested to stop listening'
        }
        #$this.response = New-Object adminResponse -ArgumentList ($items,$this.links,$null)
        $this.response = [adminResponse]::NEW($items,$this.links,$null)
    }
    [void] clearcache()
    {
        $this.adminCommand = 'clearcache'
        $this.makeLinks('/admin/clearcache',$null)
        $items = [pscustomobject] @{
            message = 'Clear Cache Initialised'
        }
        #$this.response = New-Object adminResponse -ArgumentList ($items,$this.links,$null)
        $this.response = [adminResponse]::NEW($items,$this.links,$null)
    }
    [void] default()
    {
        $children = @(
            '/stop',
            '/user/',
            '/user/new',
            '/user/disable',
            '/user/enable',
            '/user/revokeAdmin'
            '/user/grantAdmin'
            '/user/get',
            '/clearcache'
        )
        $this.makeLinks('/admin/',$children)
        $this.links.parent = '/'
        #$this.response = New-Object adminResponse -ArgumentList ($null,$this.links,$null)
        $this.response = [adminResponse]::NEW($null,$this.links,$null)
        
    }
    [void] user()
    {
        switch ($this.page)
        {
            '/user/new' {
                $inputs = @(
                    [pscustomobject] @{
                        name = 'username'
                        description = 'The associated username'
                        datatype = 'string'
                    },
                    [pscustomobject] @{
                        name = 'isadmin'
                        description = 'Should the user have elevated rights'
                        datatype = 'bool'
                    }
                )
                $this.makeLinks('/admin/user/new',$null)
                $username = $this.requestParams.username
                if($username)
                {
                    $adminValue = $this.requestParams.isAdmin
                    $acceptedValues = @(1,'true','yes','t','y')
                    try{
                        $currentTokens = Import-Clixml $this.tokensPath -ErrorAction Stop
                        if($($currentTokens|measure-Object).count -eq 1 )
                        {
                            #We have a single item and we need an array
                            write-verbose 'Converting To Array'
                            $currentTokens = @($currentTokens)
                        }
                    }catch{
                        $currentTokens = @()
                    }
                    
                    if($adminValue -in $acceptedValues)
                    {
                        write-verbose "$username will be created with Admin access"
                        $admin = $true
                    }else{
                        write-verbose "$username will be created with Std access"
                        $admin = $false
                    }
                    try{
                        
                        write-verbose 'Got the tokens'
                        $guid = $(new-guid).Guid
                        $h = [pscustomobject]@{event='created';by="$($this.currentToken)";date="$(get-date -format s)"}
                        write-verbose 'Making user object'
                        $newUser = [pscustomobject] @{
                            token = $guid
                            username = $username
                            isadmin = $admin
                            history = [array] @($h)
                            enabled = $true
                        }
                        write-verbose 'Adding Token to the list'
                        
                        $currentTokens += $newUser #Look, I know this is not the best way, but it works
                        write-verbose $($currentTokens|ConvertTo-Json -Depth 2)
                        write-verbose 'Exporting'
                        $currentTokens|Export-Clixml $this.tokensPath -Force
                        $this.adminCommand = 'updateUsers'
                        
                    }catch{
                        $currentTokens = $null
                        write-verbose 'DID NOT GET THE TOKENS'
                        $newUser = $null
                    }
                    
                }else{
                    $newUser = $null
                }
                #$this.response = new-object adminResponse -ArgumentList ($newUser,$this.links,$inputs)
                $this.response = [adminResponse]::NEW($newUser,$this.links,$inputs)
            }
            '/user/disable' {
                $inputs = @(
                    [pscustomobject] @{
                        name = 'username'
                        description = 'The username - to disable all associated tokens'
                        datatype = 'string'
                    },
                    [pscustomobject] @{
                        name = 'token'
                        description = 'Token to disable - not used if Username is specified'
                        datatype = 'string'
                    }
                )
                $this.makeLinks('/admin/user/disable',$null)
                $username = $this.requestParams.username
                $token = $this.requestParams.token
                if($username)
                {
                    $currentTokens = Import-Clixml $this.tokensPath
                    $return = foreach($user in $currentTokens)
                    {
                        if($user.username -eq $username)
                        {
                            $user.enabled = $false
                            $user.history += [pscustomobject]@{event='disabled';by=$this.currentToken;date=$(get-date -format s)}
                            $user
                        }
                    }
                    $currentTokens | Export-Clixml $this.tokensPath -Force
                }elseIf($token){
                    $currentTokens = Import-Clixml $this.tokensPath
                    $return = foreach($user in $currentTokens)
                    {
                        if($user.token -eq $token)
                        {
                            $user.enabled = $false
                            $user.history += [pscustomobject]@{event='disabled';by=$this.currentToken;date=$(get-date -format s)}
                            $user
                        }
                    }
                    $currentTokens | Export-Clixml $this.tokensPath -Force
                }else{
                    $return = $null
                }
                #$this.response = new-object adminResponse -ArgumentList ($return,$this.links,$inputs)
                $this.response = [adminResponse]::NEW($return,$this.links,$inputs)
                $this.adminCommand = 'updateUsers'
            }
            '/user/enable' {
                $inputs = @(
                    [pscustomobject] @{
                        name = 'username'
                        description = 'The username - to enable all associated tokens'
                        datatype = 'string'
                    },
                    [pscustomobject] @{
                        name = 'token'
                        description = 'Token to enable - not used if Username is specified'
                        datatype = 'string'
                    }
                )
                $this.makeLinks('/admin/user/enable',$null)
                $username = $this.requestParams.username
                $token = $this.requestParams.token
                if($username)
                {
                    $currentTokens = Import-Clixml $this.tokensPath
                    $return = foreach($user in $currentTokens)
                    {
                        if($user.username -eq $username)
                        {
                            $user.enabled = $true
                            $user.history += [pscustomobject]@{event='enabled';by=$this.currentToken;date=$(get-date -format s)}
                            $user
                        }
                    }
                    $currentTokens | Export-Clixml $this.tokensPath -Force
                }elseIf($token){
                    $currentTokens = Import-Clixml $this.tokensPath
                    $return = foreach($user in $currentTokens)
                    {
                        if($user.token -eq $token)
                        {
                            $user.enabled = $true
                            $user.history += [pscustomobject]@{event='enabled';by=$this.currentToken;date=$(get-date -format s)}
                            $user
                        }
                    }
                    $currentTokens | Export-Clixml $this.tokensPath -Force
                }else{
                    $return = $null
                }
                #$this.response = new-object adminResponse -ArgumentList ($return,$this.links,$inputs)
                $this.response = [adminResponse]::NEW($return,$this.links,$inputs)
                $this.adminCommand = 'updateUsers'
            }
            '/user/revokeAdmin' {
                $inputs = @(
                    [pscustomobject] @{
                        name = 'username'
                        description = 'The username - to revoke all associated tokens'
                        datatype = 'string'
                    },
                    [pscustomobject] @{
                        name = 'token'
                        description = 'Token to revoke Admin - not used if Username is specified'
                        datatype = 'string'
                    }
                )
                $this.makeLinks('/admin/user/revokeAdmin',$null)
                $username = $this.requestParams.username
                $token = $this.requestParams.token
                if($username)
                {
                    $currentTokens = Import-Clixml $this.tokensPath
                    $return = foreach($user in $currentTokens)
                    {
                        if($user.username -eq $username -and $user.isadmin -eq $true)
                        {
                            $user.isadmin = $false
                            $user.history += [pscustomobject]@{event='adminRevoked';by=$this.currentToken;date=$(get-date -format s)}
                            $user
                        }
                    }
                    $currentTokens | Export-Clixml $this.tokensPath -Force
                }elseIf($token){
                    $currentTokens = Import-Clixml $this.tokensPath
                    $return = foreach($user in $currentTokens)
                    {
                        if($user.token -eq $token -and $user.isadmin -eq $true)
                        {
                            $user.isadmin = $false
                            $user.history += [pscustomobject]@{event='adminRevoked';by=$this.currentToken;date=$(get-date -format s)}
                            $user
                        }
                    }
                    $currentTokens | Export-Clixml $this.tokensPath -Force
                }else{
                    $return = $null
                }
                #$this.response = new-object adminResponse -ArgumentList ($return,$this.links,$inputs)
                $this.response = [adminResponse]::NEW($return,$this.links,$inputs)
                $this.adminCommand = 'updateUsers'
            }
            '/user/grantAdmin' {
                $inputs = @(
                    [pscustomobject] @{
                        name = 'username'
                        description = 'The username - to elevate all associated tokens'
                        datatype = 'string'
                    },
                    [pscustomobject] @{
                        name = 'token'
                        description = 'Token to elevate - not used if Username is specified'
                        datatype = 'string'
                    }
                )
                $this.makeLinks('/admin/user/grantAdmin',$null)
                $username = $this.requestParams.username
                $token = $this.requestParams.token
                if($username)
                {
                    $currentTokens = Import-Clixml $this.tokensPath
                    $return = foreach($user in $currentTokens)
                    {
                        if($user.username -eq $username -and $user.isadmin -eq $false)
                        {
                            $user.isadmin = $true
                            $user.history += [pscustomobject]@{event='adminGranted';by=$this.currentToken;date=$(get-date -format s)}
                            $user
                        }
                    }
                    $currentTokens | Export-Clixml $this.tokensPath -Force
                }elseIf($token){
                    $currentTokens = Import-Clixml $this.tokensPath
                    $return = foreach($user in $currentTokens)
                    {
                        if($user.token -eq $token -and $user.isadmin -eq $false)
                        {
                            $user.isadmin = $true
                            $user.history += [pscustomobject]@{event='adminRevoked';by=$this.currentToken;date=$(get-date -format s)}
                            $user
                        }
                    }
                    $currentTokens | Export-Clixml $this.tokensPath -Force
                }else{
                    $return = $null
                }
                #$this.response = new-object adminResponse -ArgumentList ($return,$this.links,$inputs)
                $this.response = [adminResponse]::NEW($return,$this.links,$inputs)
                $this.adminCommand = 'updateUsers'
            }
            '/user/get' {
                $inputs = @(
                    [pscustomobject] @{
                        name = 'username'
                        description = 'The username to search for - accepts partial match'
                        datatype = 'string'
                    },
                    [pscustomobject] @{
                        name = 'token'
                        description = 'Token to search for - not used if Username is specified'
                        datatype = 'string'
                    },
                    [pscustomobject] @{
                        name = 'default'
                        description = 'If username/token not specified, all users will be retrieved'
                        datatype = 'none'
                    }
                )
                $this.makeLinks('/admin/user/get',$null)
                $username = $this.requestParams.username
                $token = $this.requestParams.token
                $currentTokens = Import-Clixml $this.tokensPath
                if($username)
                {
                    
                    $return = foreach($user in $currentTokens)
                    {
                        if($user.username -eq $username )
                        {
                            $user
                        }
                    }
                }elseIf($token){
                    $return = foreach($user in $currentTokens)
                    {
                        if($user.token -eq $token -and $user.isadmin -eq $false)
                        {
                            $user
                        }
                    }
                }else{
                    $return = $currentTokens
                }
                #$this.response = new-object adminResponse -ArgumentList ($return,$this.links,$inputs)
                $this.response = [adminResponse]::NEW($return,$this.links,$inputs)
            }
            '/user/'
            {
                $children = @(
                    '/new',
                    '/get',
                    '/grantAdmin',
                    '/revokeAdmin',
                    '/new',
                    '/disable',
                    '/enable'
                )
                $this.makeLinks('/admin/user/',$children)
                #$this.response = New-Object adminResponse -ArgumentList ($null,$this.links,$null)
                $this.response = [adminResponse]::NEW($null,$this.links,$null)
            }
        }
        
    }
}

class cacheObject
{
    [pageResponse]$response
    [datetime]$expires
    
    cacheObject([pageResponse]$response,[int]$cacheTime)
    {
        $this.response = $response
        $this.expires = $(get-date).AddMinutes($cacheTime)
    }
}

class ipAssist
{
    [string]$cidr
    [string]$subnetMask
    [int]$netBits
    [string]$networkId
    [string]$firstIpAddress
    [string]$lastIpAddress
    [long]$hostsPerNet
    [long]$startInteger
    [long]$endInteger
    [long]$addressInteger
    [string]$ipBinary
    [string]$smBinary
    [string]$broadcastBinary
    [string]$networkIdbinary
    
    [string]$cidrLookup
    
    ipAssist([string]$cidr)
    {
        $this.cidrLookup = $cidr
        $this.getNetworkDetails($cidr)
    }
    hidden [void] getNetworkDetails($cidr)
    {
        write-verbose 'Getting Network Details'
        $cidrSplit = $cidr.Split('/')
        $ipAddressBase  =$cidrSplit[0]
        $cidrInt = [convert]::toInt32($cidrSplit[1])
        if($cidrInt -gt 32 -or $cidrInt -lt 0)
        {
            throw 'CIDR Invalid'
        }
        write-verbose "Using cidr: $cidrInt and ipBase: $ipAddressBase"
        $this.ipBinary = $this.getBinary($ipAddressBase)
        $this.smBinary = $this.getCidrBinary($cidrInt)
        $this.netBits = $this.smBinary.indexOf('0')
        write-verbose "Netbit: $($this.netbits)"
        if(($this.netBits -gt 1) -and ($this.netbits -lt 32))
        {
            write-verbose 'Working out network values for multiple range'
            $this.firstIpAddress = $this.getDottedDecimal($($this.ipBinary.substring(0,$this.netBits).padRight(31,'0')+0))
            $this.lastIpAddress = $this.getDottedDecimal($($this.ipBinary.substring(0,$this.netBits).padRight(31,'1')+1))
            $this.networkIdbinary = $this.ipBinary.Substring('0',$this.netBits).padRight(32,'0')
            $this.broadcastBinary = $this.ipBinary.Substring('0',$this.netBits).padRight(32,'1')
            $this.networkId = $this.getDottedDecimal($this.networkIdbinary)
            $this.cidr = "$($this.networkId)/$($this.netBits)"
            $this.startInteger = $this.getIpInteger($this.firstIpAddress)
            $this.endInteger = $this.getIpInteger($this.lastIpAddress)
            $this.hostsPerNet = $($this.endInteger - $this.startInteger)+1
        }else{
            write-verbose 'Working out network values for single ip'
            $this.firstIpAddress =  $this.getDottedDecimal($this.ipBinary)
            $this.lastIpAddress = $this.firstIpAddress
            
            $this.startInteger = $this.getIpInteger($this.firstIpAddress)
            $this.endInteger = $this.startInteger
            $this.hostsPerNet = 1
            $this.cidr = $this.cidrLookup
        }
        write-verbose 'Getting actual CIDR and addressInt'
        $this.addressInteger = $([system.convert]::ToInt64("$($this.ipBinary)",2))
        
        $this.subnetMask = $this.getDottedDecimal($this.smBinary)
       
    }
    hidden [long] getIpInteger($ipAddress)
    {
        write-verbose "Getting IPInt for $ipAddress"
        $split = $ipAddress.split(".")
        write-verbose "Split1: $($split[0])"
        #write-host $split[0]
        $1 = $([int]$($split[0]) * 16777216) #[math]::pow(256,3)
        write-verbose "1: $1"
        $2 = $([int]$($split[1]) * 65536) #[math]::pow(256,2)
        $3 = $([int]$($split[2]) * 256)
        $4 = [int]$split[3]
        return $($1 + $2 + $3 + $4)
    }
    hidden [string] getCidrBinary($cidrInt)
    {
        write-verbose "Getting cidrBin for $cidrInt"
        [int[]]$array = (1..32)
        for($i=0;$i -lt $array.length;$i++)
        {
            if($array[$i] -gt $cidrInt)
            {
                $array[$i]='0'
            }else{
                $array[$i]=1
            }
        }
        return $array -join ''
    }
    hidden [string] getDottedDecimal($binary)
    {   
        write-verbose "Getting ipAddress dotNotation for $binary"
        $i = 0
        $dottedDecimal = while($i -le 24)
        {
            $convert = [string]$([convert]::toInt32($binary.substring($i,8),2))
            $convert
            $i+= 8
        }
        return $dottedDecimal -join '.'
    }
    hidden [string] getBinary($ipAddress)
    {
        write-verbose "Getting binary for $ipAddress"
        $split = $ipAddress.split('.')
        $parts =  foreach($part in $split)
        {
            $([convert]::ToString($part,2).padLeft(8,"0"))
        }
        return $($parts -join '')
    }
    static [long] convertIpToInt($ipAddress)
    {
        write-verbose "Getting IPInt for $ipAddress"
        $split = $ipAddress.split(".")
        write-verbose "Split1: $($split[0])"
        #write-host $split[0]
        $1 = $([int]$($split[0]) * 16777216) #[math]::pow(256,3)
        write-verbose "1: $1"
        $2 = $([int]$($split[1]) * 65536) #[math]::pow(256,2)
        $3 = $([int]$($split[2]) * 256)
        $4 = [int]$split[3]
        return $($1 + $2 + $3 + $4)
    }
}
<#Tests
$VerbosePreference = 'silentlycontinue'
[ipAssist]::New('10.0.0.0/8')
[ipAssist]::New('10.0.0.0/28')
[ipAssist]::New('10.0.0.0/32')
[ipAssist]::convertIpToInt('192.168.0.99')
#>

class listener
{
    [int]$port
    [string]$hostname
    [object]$httpListener
    [string]$apiPath
    [string]$serverPath
    [bool]$requireToken
    [int]$numberOfConnections = 0
    [int]$defaultCacheTime = 15
    [bool]$defaultCacheBehaviour = $true
    [bool]$defaultAuthBehaviour = $false
    hidden [string] $configPath
    hidden [string] $appPath 
    hidden [string] $tokensPath
    hidden [string] $logPath
    hidden [bool] $ok
    hidden [array] $currentTokens
    hidden [object] $user
    hidden [hashtable] $requestParams
    hidden [hashtable] $pageCache = @{}
    hidden [hashtable] $responseCache = @{}
    #CONSTRUCTORS DECONS AND INITS
    #LegacyConstructor
    #Uses defaults for cacheBehaviour etc
    #Required to leave it for compatibility reasons
    listener([int]$port,[string]$hostname,[string]$apiPath,[bool]$requireToken)
    {
        $this.verbose('====Listener Initialised: Legacy Constructor===')
        $this.verbose("Port:$Port;hostname:$hostname;apiPath:$apiPath;requireToken:$requireToken")
        $this.port = $port
        $this.hostname = $hostname
        $this.requireToken = $requireToken
        $this.serverPath = "http://$($this.hostname):$($this.port)/"
        $this.apiPath = $apiPath
        try{
            $winOS = [System.Boolean](Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop)
        }catch{
            $winOS = $false
        }
        if ($winOS)
        {
            $this.verbose('Server is Windows')
            $this.configPath = "$apiPath\config"
            $this.appPath = "$apiPath\api"
            $this.tokensPath = "$($this.configPath)\tokens.xml"
            $this.logPath = "$($this.configPath)\log.txt"
        }
        else
        {
            $this.verbose('Server is Not Windows')
            $this.configPath = "$apiPath/config"
            $this.appPath = "$apiPath/api"
            $this.tokensPath = "$($this.configPath)/tokens.xml"
            $this.logPath = "$($this.configPath)/log.txt"
        }
        if(Test-Path $apiPath)
        {            
            $this.initConfig()
            $this.verbose('starting listener Config')
            $this.configListener()
            $this.listen()
            
        }else{
            Write-Error 'There is a problem with your api Path'
            Write-Warning 'This Framework will not work with the current settings'
        }
        
        
    }
    #NewConstructor
    #Allows to set cacheBehaviour etc
    listener([int]$port,[string]$hostname,[string]$apiPath,[bool]$requireToken,[int]$defaultCacheTime,[bool]$defaultCacheBehaviour,[bool]$defaultAuthBehaviour)
    {
        $this.verbose('====Listener Initialised: New Constructor===')
        $this.verbose("Port:$Port;hostname:$hostname;apiPath:$apiPath;requireToken:$requireToken")
        $this.port = $port
        $this.hostname = $hostname
        $this.requireToken = $requireToken
        $this.serverPath = "http://$($this.hostname):$($this.port)/"
        $this.apiPath = $apiPath
        $this.defaultCacheTime = $defaultCacheTime
        $this.defaultCacheBehaviour = $defaultCacheBehaviour
        $this.defaultAuthBehaviour = $defaultAuthBehaviour
        try{
            $winOS = [System.Boolean](Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop)
        }catch{
            $winOS = $false
        }
        if ($winOS)
        {
            #windows
            $this.verbose('Server is Windows')
            $this.configPath = "$apiPath\config"
            $this.appPath = "$apiPath\api"
            $this.tokensPath = "$($this.configPath)\tokens.xml"
            $this.logPath = "$($this.configPath)\log.txt"
        }
        else
        {
            #Not windows
            $this.verbose('Server is Not Windows')
            $this.configPath = "$apiPath/config"
            $this.appPath = "$apiPath/api"
            $this.tokensPath = "$($this.configPath)/tokens.xml"
            $this.logPath = "$($this.configPath)/log.txt"
        }
        if(Test-Path $apiPath)
        {            
            $this.initConfig()
            $this.verbose('starting listener Config')
            $this.configListener()
            $this.listen()
            
        }else{
            Write-Error 'There is a problem with your api Path'
            Write-Warning 'This Framework will not work with the current settings'
        }
        
        
    }
    [void] initConfig()
    {
        $this.verbose('InitConfig')
        if(!(test-path $this.configPath))
        {
            
            try{
                New-Item -ItemType Directory -path $this.configPath
                New-Item -ItemType File -Path $this.logPath
                $this.ok = $true
                $this.verbose('config folder not found, created')
            }catch{
                Write-Error 'Unable to create configPath'
                $this.ok = $false
            }
        }else{
            $this.ok = $true
        }
        if(!(test-path $this.appPath))
        {
            $this.verbose('appPath folder not found, creating')
            try{
                New-Item -ItemType Directory -path $this.appPath
                $this.ok = $true
            }catch{
                Write-Error 'Unable to create appPath'
                $this.ok = $false
            }
        }else{
            $this.ok = $true
        }
        
        if(!(Test-path $this.tokensPath))
        {
            #We have no tokens yet
            #new-item -path $this.tokensPath
            
            $this.verbose("No tokens found, making one for the admin")
            #$newAdmin = new-object adminPage -ArgumentList @('/user/new',@{username='Administrator';isadmin=1},$this.tokensPath,'System')
            $newAdmin = [adminpage]::new('/user/new',@{username='Administrator';isadmin=1},$this.tokensPath,'System')
            
        }else{
            $this.verbose("Existing Tokens found, importing")
            $this.updateTokens()
        }
    }
    [void] configListener()
    {
        if($this.httpListener)
        {
            #Dispose the existing one
            #Need to make sure its closed
            if($this.httpListener.Listening -eq $true)
            {
                $this.verbose('Listener still listening, closing')
                $this.ForceCloseConnection()
            }
        }
        $this.verbose('Creating listener and basic config')
        try{
            $this.verbose('Substantiating listener')
            
            #$this.httpListener = $(new-object Net.HttpListener)
            $this.httpListener = [Net.HttpListener]::new()
        }catch{
            $this.verbose('Unable to substantate listener object')
            write-error 'Unable to substantiate listener object'
            
        }
        try{
            $this.verbose('Configuring listener')
            
            $this.httpListener.Prefixes.add($this.serverPath)
            $this.httpListener.AuthenticationSchemes = 'Anonymous'
            #$this.httpListener.AuthenticationSchemes = 'Basic'
            $this.verbose('Listener Config Finished')
        }catch{
            write-error 'Error configuring listener'
            $this.ForceCloseConnection()
        }
        try{
                
            $this.verbose('Starting the listener')
            $this.httpListener.Start()
        }Catch{
            write-error 'Unable to start listener'
            $this.ForceCloseConnection()
        }
    }
    [void] closeConnection()
    {
        $this.verbose('Resetting connection')
        $this.user = $null
        $this.requestParams = @{}
    }
    [void] ForceCloseConnection()
    {
        $this.verbose('Closing the connection')
        #Try and clear the params
        $this.user = $null
        $this.requestParams = @{}
        try{
            $this.httpListener.stop()
            $this.httpListener.Close()
        }catch{
            write-warning 'I was unable to stop the listener... HES A MAD-MAN'
        }
    }
   
    #LISTENER MAIN
    
    [void] listen()
    {
        #Try and clear the params
        #Essential to start from clean slate
        $this.requestParams = @{}
        $this.user = $null
        if($this.ok -eq $true)
        {
           
            try{
                
                #$this.verbose('Handling any requests')
                $this.getRequest()
            
            }catch{
                write-error 'unable to handle request'
              
                $this.ForceCloseConnection()
            }
        }else{
            $this.ForceCloseConnection()
            $this.verbose('Listener not started')
            Write-Warning 'The listener is not started, ok not true'
        }
    }
    #PARAM HELPERS
    [void] getQueryData($queryString)
    {
        $this.verbose('Getting GET Params')
        $this.requestParams = @{}
        foreach($get in $queryString)
        {
            $this.requestParams."$get" = $queryString[$get]
            
        }
        
    }
    [void] getPostData($inputstream,$ContentEncoding)
    {
        $this.verbose('Getting POST Params')
        try{
            ##$StreamReader = New-Object IO.StreamReader($inputstream,$ContentEncoding)
            $this.verbose('Creating Stream Reader')
            $StreamReader = [IO.StreamReader]::new($inputstream,$ContentEncoding)
            $this.verbose('Reading Stream')
            $read = $StreamReader.ReadToEnd()
            try{
                $readJson = $read|ConvertFrom-Json
                $this.verbose('Json POST data found')
                $properties = $($readJson | get-member -membertype NoteProperty).Name
                foreach($property in $properties)
                {
                    $this.verbose("Creating Property: $property")
                    $this.requestParams."$property" = $readJson."$property"
                }
            }catch{
                $this.verbose('Fallback to String POST data - using split to extract Params')
                foreach ($Post in $($read.Split('&')))
                {
                    $PostContent = $Post.Split("=")
                    $PostName = $PostContent[0]
                    $PostValue = $($PostContent[1..$($PostContent.count)] -join '=')
                    if($PostName.EndsWith("[]"))
                    {
                        $PostName = $PostName.Substring(0,$PostName.Length-2)
                    }
                    $this.verbose("Creating Property: $PostName")
                    $this.requestParams."$PostName" = $PostValue
                }
            }
        }catch{
            
            $this.verbose('Unable to read stream')
        }
    }
    #REQUEST HELPER
    #Probably the biggest function
    [void] getRequest()
    {
        
        $this.verbose('Awaiting Request')
        $context = $this.httpListener.GetContext()
        $this.numberOfConnections++
        $this.verbose("`n====START====`n`tConnection $($this.numberOfConnections)")
        $global:lastContectCheck = $context
        $request = $context.Request
        $identity = $context.User.Identity
        $r = $null
        
        #write-verbose "`n==`n$($request | format-list * | Out-String)`n==`n"
        if($request.HttpMethod -eq 'Post')
        {
            $this.getPostData($request.InputStream,$request.ContentEncoding)
        }else{
            $this.getQueryData($request.QueryString)
        }     
        
        $token = $request.headers['x-api-token']
        #$this.verbose("Token Obj : $($token)")
        
        $response = $context.Response
        $Response.Headers.Add('Accept-Encoding','gzip')
        $Response.Headers.Add('Server','psRapid')
        #Since this is an API, deal with CORS headers
        $Response.Headers.Add('Access-Control-Allow-Origin','*')
        
        $response.headers.add('Access-Control-Allow-Methods','GET,POST,HEAD,OPTIONS')
        $this.user = $this.getUser($token)
        $page = $request.RawUrl.Split('?')[0]
        $this.verbose("REQUEST DETAILS:`n`tRequested Page: $page`n`tToken: $($token)`n`tRefer: $($request.UrlReferrer)`n`tUserHostAddress: $($request.UserHostAddress)`n`tRemoteEndPoint: $($request.RemoteEndPoint)`n`tIsLocal:$($request.IsLocal)`n")
        $this.verbose("PARAMS: `n$($this.requestParams|format-list|out-string)`n")
        #ADMIN PAGE CHECK AND USER AUTH
        if($page -like '/admin*' -and $this.user.isAdmin -eq $true -and $this.user.enabled -eq $true)
        {
            $this.verbose("`n====ADMIN PAGE====`n`Token: $($this.user.token)")
            try{
                $response.StatusCode = '200'
                #$adminPage = new-object adminPage -ArgumentList @($($page -replace '/admin',''),$this.requestParams,$this.tokensPath,$this.user.token)
                $adminPage = [adminPage]::New($($page -replace '/admin',''),$this.requestParams,$this.tokensPath,$this.user.token)
                $r = $adminPage.response.json()
                if($adminPage.adminCommand -eq 'stop')
                {
                    $this.verbose('Request to stop server')
                    $this.ok = $false
                }
                if($adminPage.adminCommand -eq 'clearCache')
                {
                    $this.verbose('Request to clear cache')
                    $this.pageCache = @{}
                }
                if($adminPage.adminCommand -eq 'updateUsers')
                {
                    $this.verbose('Request to update users')
                    $this.updateTokens()
                }
                
            }catch{
                
                #$this.verbose('Error with Admin Page Creation')
                write-error 'Error with admin page creation'
                $adminPage = $null
                $response.StatusCode = 418
                $r = 'Im a Teapot - Error with admin page creation'
            }
        #GENERAL PAGE CHECK AND USER AUTH
        }elseif((($this.user.enabled -eq $true)-and($this.requireToken -eq $true))-or($this.requireToken -eq $false)){
            try{
                $authorized = $true
                #$this.verbose('Normal Page Request')
                $ext = if($page[-1] -eq '/'){''}else{'.ps1'}
                $requestedPagePath = "$($this.appPath)$($page.replace('/','\'))$($ext)"
                if(Test-Path $requestedPagePath){
                    $this.verbose("Path Valid - $requestedPagePath")
                }else{
                    $this.verbose("Path invalid, setting to default - $requestedPagePath")
                    $requestedPagePath = $this.appPath
                }
                $response.StatusCode = '200'
                $p = $this.pageCache."$requestedPagePath"
                if(!$p)
                {
                    #$this.verbose('Retrieving Page Details')
                    #$p = new-object page -ArgumentList ($requestedPagePath,$page)
                    #The below method works in linux, the above only works in windows, use the below for compatibility reasons
                    $p = [page]::new($requestedPagePath,$page,$this.defaultCacheTime,$this.defaultCacheBehaviour,$this.defaultAuthBehaviour)
                    $this.verbose('Page Retrieved - Saving Page to Cache')
                    $this.pageCache."$requestedPagePath" = $p
                    
                    #$this.verbose("Current Pages Cached: `n`n $($this.pageCache.keys)")
                }else{
                    $this.verbose('Page retrieved from Cache')
                }
                #This is where we check the user is authorised for the page network access restrictions and if auth is required
                
                if($p.ipRanges)
                {
                    #Whats this users IP Address as a decimal
                    #First need to handle if the request is local, maybe just make it loopback
                    #Then if its not, we need to separate the IP from the Port
                    #Then when we have an IP address, need to convert it to decimal for better maths
                    $authorized = $false
                    $ipAddress = 'a.b.c.d' #Need something because classes are so strict
                    $this.verbose('Need to confirm IP Range')
                    if($request.IsLocal -eq $true)
                    {
                        $ipAddress = '127.0.0.1'
                    }else{
                        #[::1]:59271
                        #10.123.42.27:80
                        $regex = '[^0-9.:]+'
                        $regexIPv4 = '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'
                        $ipAndPortOnly = $request.RemoteEndPoint -replace $regex
                        $ipTest = $($ipAndPortOnly.substring(0,$($ipAndPortOnly.indexOf(':')))).trim()
                        If($ipTest -match $regexIPv4 ){
                           #IPv4 looks ok 
                           $ipAddress = $ipTest
                        }else{
                            #Not an IP so throw unauth
                            $this.verbose('Not an IPAddress')
                            $authorized = $false
                        }
                    }
                    $this.verbose("Got this IP: $ipAddress")
                    try{
                        $ipCompare = [ipAssist]::convertIpToInt($ipAddress)
                        foreach($range in $p.ipRanges)
                        {
                            if($ipCompare -ge $range.min -and $ipCompare -le $range.max)
                            {
                                $this.verbose("IP in appropriate block, should authorize`n`tRange: $($range.firstIpAddress) <--> $($range.lastIpAddress)")
                                $authorized = $true
                            }
                        }
                    }catch{
                        $authorized = $false
                    }
                }else{
                    $this.verbose('Not checking IP Range')
                }
                if($p.auth -eq $true)
                {
                    $authorized = $false
                    if($this.user.enabled)
                    {
                        $this.verbose('User is enabled')
                        $authorized = $true
                    }
                }       
                if($authorized -eq $true)
                {
                    $this.verbose('Access is authorized')
                    #Ensure script is null
                    $script = $null
                    
                    #Check for headers hashable param in the page inputs
                    $headersInput = $p.inputs | Where-object {$_.name -eq 'headers' -and $_.datatype -eq 'hashtable'}
                    #$this.verbose("$($p.inputs|Format-Table|out-string)")
                    #This allows passing of headers from the request to the scriptblock if required
                    #Should mostly not need this
                    $this.verbose("HeadersInput: `t $(if($headersInput){$true}else{$false})")
                    if($headersInput)
                    {
                        $this.verbose("HeadersFound:`n$($headersInput|Format-Table|out-string)")
                        
                        $headerValuesHash = @{}
                        foreach($item in $context.request.Headers)
                        {
                            $headerValuesHash."$item" = $context.Request.Headers["$item"]
                        }
                        
                        $headerValuesHash.UserHostAddress = $context.request.UserHostAddress
                        $headerValuesHash.UserHostName = $context.request.UserHostName
                        $headerValuesHash.UrlReferrer = $context.request.UrlReferrer
                        $headerValuesHash.IsSecureConnection = $context.request.IsSecureConnection
                        $headerValuesHash.IsLocal = $context.request.IsLocal
                        $headerValuesHash.Cookies = $context.request.Cookies
                        $headerValuesHash.RemoteEndpoint = $context.request.RemoteEndPoint
                        
                        $this.requestParams.Headers = $headerValuesHash
                        #$this.verbose("HeadersPassed: $($headerValuesHash |Format-List|Out-String)")
                    }
                    #$this.verbose('+--=finished param building=--+')
                    #If we have a file, we need to execute it
                    #Check we have a response in the responseCache
                    
                    
                    if($p.cache -eq $true)
                    {
                        $this.verbose('Checking for cached result')
                        #Work out a cacheKey
                        #Should incorporate the page plus the params somehow
                        
                        #$cacheKey = "$($page)::$($($($this.requestParams.keys|sort-object) -join '').tolower())::$($($($this.requestParams.values|sort-object) -join '').tolower())"
                        $cachekeyParams = [array]$($($($this.requestParams.keys)|sort-object)|ForEach-Object{"$($_)$($this.requestParams.$_)"}) -join ''
                        
                        $cacheKey = "$($page)::$cachekeyParams"
                        $this.verbose("Using CacheKey:$cacheKey")
                        if($this.responseCache."$cacheKey")
                        {
                            $this.verbose('responseCache found for object, checking expiry')
                            
                            if($this.responseCache."$cacheKey".expires -gt $(get-date))
                            {
                                $this.verbose("Cache Valid until:  $($this.responseCache."$cacheKey".expires)")
                                $this.verbose('responseCache looks valid, returning cached result')
                                $responsepage = $this.responseCache."$cacheKey".response
                                $responsepage.fromCache()
                                $r = $responsepage.json()
                            }else{
                                $this.verbose("Cache Expired:  $($this.responseCache."$cacheKey".expires)")
                            }
                        }
                        if($r -eq $null)
                        {
                            $this.verbose('No valid cache found. Creating new response')
                            #No response json, make a new response
                            #Add it to the cache as well
                            try{
                                #$script = new-object script -ArgumentList @($p.filepath,$this.requestParams)
                                if($p.isFile -eq $true)
                                {
                                    $script = [script]::new($($p.filepath),$this.requestParams)
                                }
                                
                                $responsepage = [pageResponse]::new($p,$script)
                                $this.responseCache."$cacheKey" = [cacheObject]::New($responsepage,$p.cachetime)
                                $r = $responsepage.json()
                                $this.verbose('Script execution ok')
                            }catch{
                                $this.verbose('Bad script execution')
                                $r = 'Im a Teapot - Error with page Response'
                                $response.StatusCode = 418
                            }
                        }
                    }else{
                        $this.verbose('Cache for page set to false')
                        try{
                            #$script = new-object script -ArgumentList @($p.filepath,$this.requestParams)
                            if($p.isFile -eq $true)
                            {
                                $script = [script]::new($($p.filepath),$this.requestParams)
                            }
                            $responsepage = [pageResponse]::new($p,$script)
                            $r = $responsepage.json()
                            $this.verbose('Script execution ok')
                        }catch{
                            $this.verbose('Bad script execution')
                            $r = 'Im a Teapot - Error with page Response'
                            $response.StatusCode = 418
                        }
                    }
                }else{
                    #Return unauthorized
                    $this.verbose('User is unauthorized')
                    $response.StatusCode = '401'
                    $r = 'Access is denied - invalid token'
                }
            }catch{
                $this.verbose('Error with Page Creation')
                write-error 'Error with page creation'
                $response.StatusCode = 418
                $r = 'Im a Teapot - Error with page creation'
            }
        #ACCESS DENIED
        }else{
            $this.verbose('Creating a deny response')
            $response.StatusCode = '401'
            $r = 'Access is denied - invalid token'
        }
        
        $this.user = $null
        #$this.verbose('Encoding Response')
        #$this.verbose("RETURN OBJECT: `n$r`n`n")
        if($r)
        {
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($r)
            $response.ContentLength64 = $buffer.Length
        }else{
            $buffer=''
            $response.ContentLength64 = 0
        }
        
        $this.verbose('Sending response')
        $output = $response.OutputStream
        $output.Write($buffer,0,$response.ContentLength64)
        $output.Close()
        $this.closeConnection()
        $this.verbose("This connection is finished`n====END====")
        $this.listen()
    }
    #LOGGING HELPER
    [void] verbose([string]$message)
    {
        #Simple verbose helper to include the date
        $logAs = "[$(get-date -Format s)]`t $message"
        Write-Verbose $logAs
        if(!$this.logPath)
        {
            write-warning 'Not Logged to file'
        }else{
            try{
                $logAs|Out-File $this.logPath -Append -NoClobber -Force
                $xLogFile = $this.logPath
                if($xLogFile.length -gt 20mb)
                {
                    $newname = "$($xLogFile.basename)$(get-date -format yyyyMMdd.hhmmss).txt"
                    rename-item $this.logPath -NewName $newname
                }
            }catch{
                write-warning 'Error logging to file'
            }
        }
    }
    #User functions
    
    [void] updateTokens()
    {
        $this.verbose('Importing tokens')
        $this.currentTokens = Import-Clixml $this.tokensPath
    }
    
    [object] getUser($token)
    {
        
        $this.verbose("Checking Valid Token: $token")
        $findUser = $this.currentTokens|Where-Object {$_.token -eq $token}
        if(!$findUser)
        {
            $this.verbose('Token not found, refreshing token list')
            $this.updateTokens()
            $findUser = $this.currentTokens|Where-Object {$_.token -eq $token}
        }
        if($findUser -and $findUser.enabled -eq $true)
        {
            $this.verbose("Token valid")
            #$this.verbose("`n$($findUser|format-list|out-string)")
            return $findUser
        }else{
            $this.verbose("Token not valid")
            return $null
        }
    }
}

class page{
    [string]$filepath
    [hashtable] $links = @{}
    hidden [bool] $isFile
    hidden [string] $executePath
    hidden [string] $pathToReplace
    hidden [object] $targetFile
    hidden [int] $cacheTime
    hidden [bool] $cache
    hidden [bool] $auth
    hidden [array] $ipRanges
    hidden [array] $authGroups
    [object[]] $inputs
    page([string] $filepath,[string]$pageRef,[int]$defaultCacheTime,[bool]$defaultCacheBehaviour,[bool]$defaultAuthBehaviour)
    {
        $this.filepath = $filepath
        $this.links.this = $pageRef
        $this.cacheTime = $defaultCacheTime
        $this.cache = $defaultCacheBehaviour
        $this.auth = $defaultAuthBehaviour
        $endParent = if($pageRef[-1] -eq '/' -and $pageRef.length -gt 1){'/'}else{''}
        $this.links.parent = "/$($pageref.split('/')[-2])$endParent"
        try{
            $this.targetFile = get-item $filepath -ErrorAction stop
            if($this.targetFile.PSIsContainer -eq $true)
            {
                write-verbose 'Item is directory'
                $items = get-childitem $filepath -Recurse |where-object {$_.PsIsContainer -eq $true -or $_.Extension -eq '.ps1'}
                $this.pathToReplace = $this.targetFile.fullname
                if($this.pathToReplace[-1] -eq '\')
                {
                    $this.pathToReplace = $this.pathToReplace.Substring(0,$($this.pathToReplace.Length - 1))
                }
                $this.isFile = $false
                $this.getChildLinks($items)
            }elseif($this.targetFile.Extension -eq '.ps1'){
                write-verbose 'Item is file'
                $items = get-childItem $this.targetFile.Directory.FullName -Recurse | where-object {$_.PsIsContainer -eq $true -or $_.Extension -eq '.ps1' -and $_.FullName -ne $this.targetFile.fullname}
                $this.isFile = $true
                $this.pathToReplace = "$($this.targetFile.Directory.FullName)"
                
                $this.executePath = $this.targetFile.FullName
                $this.getChildLinks($items)
                $this.getInputs()
                $this.getAttribs()
            }else{
                Write-Warning 'Incorrect File Type'
            }
        }catch{
            write-warning 'unable to get the filepath'
        }
        
    }
    [void] getChildLinks($items)
    {
        write-verbose 'Get Child Links'
        Write-Verbose "Path to Replace: $($this.PathToReplace)"
        Write-Verbose "ParentPath: $($this.links.parent)"
        $children = foreach($item in $items)
        {
            if($item.PsIsContainer -eq $true)
            {
                $base = $item.fullname.replace($($this.PathToReplace),'')
                $basepath = "$($this.links.parent)$($base.replace('\','/'))/"
                if($basepath.substring(0,2) -eq '//')
                {
                    $basepath = $basepath.Substring(1)
                }
                
                write-verbose $basepath
                $basepath
                
            }else{
                $base = $item.Directory.fullname.replace($($this.PathToReplace),'')
                
                $base = $base.replace('\','/')
                Write-Verbose $base
                $basepath = "$($this.links.parent)$($base)/$($item.basename)"
                if($basepath.substring(0,2) -eq '//')
                {
                    $basepath = $basepath.Substring(1)
                }
                write-verbose $basepath
                $basepath
            }
            
            
        }
        Write-Verbose $($children | out-string)
        $this.links.children = $children
        
    }
    [void] getInputs()
    {
        write-verbose 'Get Inputs'
        try{
            $paramsBase = get-help  $this.executePath -Parameter * -ErrorAction Stop
            foreach($param in $paramsBase)
            {
                $this.inputs += [pscustomobject] @{
                    name = $param.name
                    description = $param.description.text
                    datatype = $param.type.name
                }
            }
        }catch{
            write-warning 'No Declared parameters'
        }
    }
    [void] getAttribs()
    {
        write-verbose 'Get Attribs'
        try{
            $command = get-command $this.executePath
            if($command)
            {
                $attribData = $command.ScriptBlock.Attributes|where-object{$_.typeid.name -eq 'PageControl'}
                if($attribData)
                {
                    write-verbose 'Got attrib data, adding to page details'
                    if($attribData.cacheMins)
                    {
                        write-verbose "Setting Cache Mins to: $($attribData.cacheMins)" 
                        $this.cacheTime = $attribData.cacheMins
                    }
                    if($attribData.cache -ne $null)
                    {
                        write-verbose "Setting Cache : $($attribData.cacheMins)" 
                        $this.cache = $attribData.cache
                    }
                    if($attribData.tokenRequired -ne $null)
                    {
                        write-verbose "Setting auth : $($attribData.tokenRequired)" 
                        $this.auth = $attribData.tokenRequired
                    }
                    if($attribData.networkRange)
                    {
                        $this.ipRanges = forEach($network in $attribData.networkRange)
                        {
                            write-verbose "Adding Netrange for : $network" 
                            $netData = [ipAssist]::new($network)
                            @{
                                first = $netData.firstIpAddress
                                last = $netData.lastIpAddress
                                min = $netData.startInteger
                                max = $netData.endInteger
                            }
                        }
                    }
                    if($attribData.authGroup)
                    {
                        $this.authGroups = $attribData.authGroup
                    }
                }else{
                    write-warning 'No attrib data found'
                }
                
            }else{
                write-warning 'Unable to get command data'
            }
        }catch{
            write-warning 'Unable to import command'
        }
    }
}

#Should we cache
#If so for how long should we cache
#Should we hide the link
#Should we restrict to CIDR
#Need a CIDR Helper
#Should be an attribute
#should cacheControl be separate from the functionControls?
#Needs more thought
#Auth Groups
#Should be in the page class
class PageControl : System.Attribute
{
    [int] $cacheMins
    [bool] $cache
    [array] $networkRange
    [array] $authGroup
    [bool] $tokenRequired
    
    PageControl()
    {
    }
}

class response{
    [hashtable] $links
    [object[]] $inputs
    [int] $itemCount
    [object[]] $items
    [string]$server = 'psRapid'
    [string]$timestamp = $(get-date -format s)
    [bool]$cachedResponse = $false
    
    respones()
    {
        $objType = $this.GetType()
        if($objType -eq [response])
        {
            throw "Parent Class $($objType.Name) Must be inherited"
        }
    }
    [string] json()
    {
        return $this|ConvertTo-Json -depth 10
    }
    [void] fromCache()
    {
        $this.timestamp = $(get-date -format s)
        $this.cachedResponse = $true
    }
}
class pageResponse : response
{
    pageResponse([object]$page,[object]$script)
    {
        $this.links = $page.links
        $this.inputs = $page.inputs
        if($script.results)
        {
            $this.itemCount = $($script.results |measure-object).count
            $this.items = $script.results
        }else{
            $this.itemCount = 0
            $this.items = $null
        }
       
    }
}
class adminResponse : response
{
    
    adminResponse($items,$links,$inputs)
    {
        $this.links = $links
        $this.items = $items
        $this.itemcount = $($items |measure-object).count
        $this.inputs = $inputs
    }
}
class accessDeniedResponse : response
{
}

class script
{
    [object[]]$results
    [hashtable]$params
    [string]$filepath
    script([string]$filepath,[hashtable]$params)
    {
        $this.filepath = $filepath
        $this.params = $params
        try{
            $file = get-item $this.filepath -ErrorAction stop
        }catch{
            Write-warning 'File not Found'
            $file = $null
        }
        if(($file -and $file.Extension -eq '.ps1'))
        {
            $this.execute()
        }else{
            write-warning 'Invalid FileType'
        }
        
        
    }
    [void] execute()
    {
        if($this.params.count -gt 0)
        {
            write-verbose 'Executing with params'
            $splat = $this.params
            $scriptResult = . $this.filepath @splat
        }else{
            write-verbose 'Executing wihtout params'
            $scriptResult = . $this.filepath
        }
        if($scriptResult)
        {
            Write-Verbose 'Saving Results'
            $this.results = $scriptResult
        }else{
            Write-Verbose 'No Results returned'
        }
    }
}

