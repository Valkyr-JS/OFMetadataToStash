param ([switch]$ignorehistory, [switch]$randomavatar, [switch]$v)
 
 <#
---OnlyFans Metadata DB to Stash PoSH Script 0.9---

AUTHOR
    JuiceBox
URL 
    https://github.com/ALonelyJuicebox/OFMetadataToStash

DESCRIPTION
    Using the metadata database from an OnlyFans scraper script, imports metadata such as the URL, post associated text, and creation date into your stash DB

REQUIREMENTS
    - The Powershell module "PSSQLite" must be installed https://github.com/RamblingCookieMonster/PSSQLite
       Download a zip of the PSSQlite folder in that repo, extract it, run an Admin window of Powershell
       in that directory then run 'install-module pssqlite' followed by the command 'import-module pssqlite'
 #>

 #Powershell Dependencies
#requires -modules PSGraphQL
#requires -modules PSSQLite
#requires -Version 7

#Import Modules now that we know we have them
Import-Module PSGraphQL
Import-Module PSSQLite

#Command Line Arguments



### Functions
#Set-Config is a wizard that walks the user through the configuration settings
function Set-Config{
    clear-host
    write-host "OnlyFans Metadata DB to Stash PoSH Script" -ForegroundColor Cyan
    write-output "Configuration Setup Wizard"
    write-output "--------------------------`n"
    write-output "(1 of 3) Define the URL to your Stash"
    write-output "Option 1: Stash is hosted on the computer I'm using right now (localhost:9999)"
    write-output "Option 2: Stash is hosted at a different address and/or port (Ex. 192.168.1.2:6969)`n"
    do{
        do {
            $userselection = read-host "Enter your selection (1 or 2)"
        }
        while (($userselection -notmatch "[1-2]"))

        if ($userselection -eq 1){
            $StashGQL_URL = "http://localhost:9999/graphql"
        }

        #Asking the user for the Stash URL, with some error handling
        else {
            while ($null -eq $StashGQL_URL ){
                $StashGQL_URL = read-host "`nPlease enter the URL to your Stash"
                $StashGQL_URL = $StashGQL_URL + '/graphql' #Tacking on the gql endpoint
        
                while (!($StashGQL_URL.contains(":"))){
                    write-host "Error: Oops, looks like you forgot to enter the port number (Ex. <URL>:9999)." -ForegroundColor red
                    $StashGQL_URL = read-host "`nPlease enter the URL to your Stash"
                }
        
                if (!($StashGQL_URL.contains("http"))){
                    $StashGQL_URL = "http://"+$StashGQL_URL
                }
            }
        }
        do{
            write-host "`nDo you happen to have a username/password configured on your Stash?"
            $userselection = read-host "Enter your selection (Y/N)"
        }
        while(($userselection -notlike "Y" -and $userselection -notlike "N"))
        if($userselection -like "Y"){
            write-host "As you have set a username/password on your Stash, You'll need to provide this script with your API key."
            write-host "Navigate to this page in your browser to generate one in Stash"
            write-host "$StashGQL_URL/settings?tab=security"
            write-host "`n- WARNING: The API key will be stored in cleartext in the config file of this script. - "
            write-host "If someone who has access to your Stash gets access to the config file, they may be able to use it to bypass the username and password you've set."
            $StashAPIKey = read-host "`nWhat is your API key?"
        }

        #Now we can check to ensure this address is valid-- we'll use a very simple GQL query and get the Stash version
        $StashGQL_Query = 'query version{version{version}}'
        try{
            $stashversion = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
        }
        catch{
            write-host "(0) Error: Could not communicate to Stash at the provided address ($StashGQL_URL)"
            read-host "No worries, press [Enter] to start from the top"
        }
    }
    while ($null -eq $stashversion)

    clear-host
    write-host "OnlyFans Metadata DB to Stash PoSH Script" -ForegroundColor Cyan
    write-output "Configuration Setup Wizard"
    write-output "--------------------------`n"
    write-output "(2 of 3) Define the path to your OnlyFans content`n"
    write-host "    * OnlyFans metadata database files are named 'user_data.db' and they are commonly `n      located under <performername> $directorydelimiter metadata $directorydelimiter , as defined by your OnlyFans scraper of choice"
    write-output "`n    * You have the option of linking directly to the 'user_data.db' file, `n      or you can link to the top level OnlyFans folder of several metadata databases."
    write-output "`n    * When multiple database are detected, this script can help you select one (or even import them all in batch!)`n"
    if ($null -ne $PathToOnlyFansContent){
        #If the user is coming to this function with this variable set, we set it to null so that there is better user feedback if a bad filepath is provided by the user.
        $PathToOnlyFansContent = $null
    }
    do{
        #Providing some user feedback if we tested the path and it came back as invalid
        if($null -ne $PathToOnlyFansContent){
            write-output "Oops. Invalid filepath"
        }
        if($IsWindows){
            write-output "Option 1: I want to point to a folder containing all my OnlyFans content/OnlyFans metadata databases"
            write-output "Option 2: I want to point to a single OnlyFans Metadata file (user_data.db)`n"

            do {
                $userselection = read-host "Enter your selection (1 or 2)"
            }
            while (($userselection -notmatch "[1-2]"))
         
            #If the user wants to choose a folder instead of a file there's a different Windows File Explorer prompt to bring up so we'll use this condition tree to sort that out
            if ($userselection -eq 1){
                Add-Type -AssemblyName System.Windows.Forms
                $FileBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
                $null = $FileBrowser.ShowDialog()
                $PathToOnlyFansContent = $FileBrowser.SelectedPath
            }
            else {
                Add-Type -AssemblyName System.Windows.Forms
                $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
                    Filter = 'OnlyFans Metadata Database File (*.db)|*.db'
                }
                $null = $FileBrowser.ShowDialog()
                $PathToOnlyFansContent = $FileBrowser.filename
            }
        }
        else{
            $PathToOnlyFansContent = read-host "Enter the folder containing your OnlyFans content or a direct link to your OnlyFans Metadata Database"
        }
    }
    while(!(test-path $PathToOnlyFansContent))

    clear-host
    write-host "OnlyFans Metadata DB to Stash PoSH Script" -ForegroundColor Cyan
    write-output "Configuration Setup Wizard"
    write-output "--------------------------`n"
    write-output "(3 of 3) Define your Metadata Match Mode"
    write-output "    * When importing OnlyFans Metadata, some users may want to tailor how this script matches metadata to files"
    write-output "    * If you are an average user, just set this to 'Normal'"
    write-output "`nOption 1: Normal - Will match based on Filesize and the Performer name being somewhere in the file path (Recommended)"
    write-output "Option 2: Low    - Will match based only on a matching Filesize"
    write-output "Option 3: High   - Will match based on Filename and a matching Filesize"


    $specificityselection = 0;
    do {
        $specificityselection = read-host "`nEnter selection (1-3)"
    }
    while (($specificityselection -notmatch "[1-3]"))

    #Code for parsing metadata files
    if($specificityselection -eq 1){
        $SearchSpecificity = "Normal"
    }
    elseif($specificityselection -eq 2){
        $SearchSpecificity = "Low"
    }
    else{
        $SearchSpecificity = "High"
    }

    clear-host
    write-host "OnlyFans Metadata DB to Stash PoSH Script" -ForegroundColor Cyan
    write-output "Configuration Setup Wizard"
    write-output "--------------------------`n"
    write-output "(Summary) Review your settings`n"

    write-output "URL to Stash API:`n - $StashGQL_URL`n"
    write-output "Path to OnlyFans Content:`n - $PathToOnlyFansContent`n"
    write-output "Metadata Match Mode:`n - $SearchSpecificity`n"

    read-host "Press [Enter] to save this configuration and return to the Main Menu"


    #Now to make our configuration file
    try { 
        Out-File $PathToConfigFile
    }
    catch{
        write-output "Error - Something went wrong while trying to save the config file to the filesystem ($PathToConfigFile)" -ForegroundColor red
        read-output "Press [Enter] to exit" -ForegroundColor red
        exit
    }

    try{ 
        Add-Content -path $PathToConfigFile -value "#### OFMetadataToStash Config File v1 ####"
        Add-Content -path $PathToConfigFile -value "------------------------------------------"
        Add-Content -path $PathToConfigFile -value "## URL to the Stash GraphQL API endpoint ##"
        Add-Content -path $PathToConfigFile -value $StashGQL_URL
        Add-Content -path $PathToConfigFile -value "## Direct Path to OnlyFans Metadata Database or top level folder containing OnlyFans content ##"
        Add-Content -path $PathToConfigFile -value $PathToOnlyFansContent
        Add-Content -path $PathToConfigFile -value "## Search Specificity mode. (Normal | High | Low) ##"
        Add-Content -path $PathToConfigFile -value $SearchSpecificity
        Add-Content -path $PathToConfigFile -value "## Stash API Key (Danger!)##"
        Add-Content -path $PathToConfigFile -value $StashAPIKey
    }
    catch {
        write-output "Error - Something went wrong while trying add your configurations to the config file ($PathToConfigFile)" -ForegroundColor red
        read-output "Press [Enter] to exit" -ForegroundColor red
        exit
    }
    
} #End Set-Config

#DatabaseHasBeenImported does a check to see if a particular metadata database file actually needs to be parsed based on a history file. Returns true if this database needs to be parsed
function DatabaseHasAlreadyBeenImported{
    if ($ignorehistory -eq $true){
        return $false
    }
    else{
        #Location for the history file to be stored
        $PathToHistoryFile = "."+$directorydelimiter+"Utilities"+$directorydelimiter+"imported_dbs.sqlite"

        #Let's go ahead and create the history file if it does not exist
        if(!(test-path $pathtohistoryfile)){
            try{
                new-item $PathToHistoryFile
            }
            catch{
                write-host "Error 1h - Unable to write the history file to the filesystem. Permissions issue?" -ForegroundColor red
                read-host "Press [Enter] to exit"
                exit
            }

            #Query for defining the schema of the SQL database we're creating
            $historyquery = 'CREATE TABLE "history" ("historyID" INTEGER NOT NULL UNIQUE,"performer"	TEXT NOT NULL UNIQUE COLLATE BINARY,"import_date" TEXT NOT NULL,PRIMARY KEY("historyID" AUTOINCREMENT));'

            try{
                Invoke-SqliteQuery -Query $historyQuery -DataSource $PathToHistoryFile
            }
            catch{
                write-host "Error 2h - Unable to create a history file using SQL." -ForegroundColor red
                read-host "Press [Enter] to exit"
                exit
            }
        }

        #First let's check to see if this performer is even in the history file
        try{
            $historyQuery = 'SELECT * FROM history WHERE history.performer = "'+$performername+'"'
            $performerFromHistory = Invoke-SqliteQuery -Query $historyQuery -DataSource $PathToHistoryFile
        }
        catch{
            write-host "Error 3h - Something went wrong while trying to read from history file ($PathToHistoryFile)" -ForegroundColor red
            read-host "Press [Enter] to exit"
            exit
        }

        #If this performer DOES exist in the history file...
        if ($performerFromHistory){

            #Let's get the timestamp from the metdata database file
            $metadataLastWriteTime = get-item $currentdatabase
            $metadataLastWriteTime = $metadataLastWriteTime.LastWriteTime

            #If the metdata database for this performer has been modified since the last time we read this metadata database in, let's go ahead and parse it
            if([datetime]$metadataLastWriteTime -gt [datetime]$performerFromHistory.import_date){
                $currenttimestamp = get-date -format o
                try { 
                    $historyQuery = 'UPDATE import_date SET import_date = "'+$currenttimestamp+'" WHERE history.performer = "'+$performername+'"'
                    Invoke-SqliteQuery -Query $historyQuery -DataSource $PathToHistoryFile    
                }
                catch{
                    write-host "Error 4h - Something went wrong while trying to update the history file ($PathToHistoryFile)" -ForegroundColor red
                    read-output "Press [Enter] to exit"
                    exit
                }
                return $false
            }
            else{
                write-host "- The metadata database for $performername hasn't changed since your last import! Skipping..."
                return $true
            }
        }
        #Otherwise, this performer is entirely new to us, so let's add the performer to the history file 
        else{
            $currenttimestamp = get-date -format o
            try { 
                $historyQuery = 'INSERT INTO history(performer, import_date) VALUES ("'+$performername+'", "'+$currenttimestamp+'")'
                Invoke-SqliteQuery -Query $historyQuery -DataSource $PathToHistoryFile    
            }
            catch{
                write-host "Error 5h - Something went wrong while trying to add this performer to the history file ($PathToHistoryFile)" -ForegroundColor red
                read-output "Press [Enter] to exit"
                exit
            }
            return $false
        }
    }
} #End DatabaseHasBeenImported

#Add-MetadataUsingOFDB adds metadata to Stash using metadata databases.
function Add-MetadataUsingOFDB{
    #Playing it safe and asking the user to back up their database first
    $backupConfirmation = Read-Host "`nBefore we begin, would you like to make a backup of your Stash Database? [Y/N] (Default is 'No')"

    if (($backupConfirmation -like "Y*")) {
        $StashGQL_Query = 'mutation BackupDatabase($input: BackupDatabaseInput!) {
            backupDatabase(input: $input)
          }'
        $StashGQL_QueryVariables = '{
            "input": {}
          }' 

        try{
            Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }}) | out-null
        }
        catch{
            write-host "(10) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
            write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
            read-host "Press [Enter] to exit"
            exit
        }
        write-output "...Done! A backup was successfully created."
    }
    else{
        write-output "OK, a backup will NOT be created." 

    }


    

    write-output "`nScanning for existing OnlyFans Metadata Database files..."

    #Finding all of our metadata databases. 
    $OFDatabaseFilesCollection = Get-ChildItem -Path $PathToOnlyFansContent -Recurse | where-object {$_.name -in "user_data.db","posts.db"}
        
    #For the discovery of a single database file
    if ($OFDatabaseFilesCollection.count -eq 1){

        #More modern OF DB schemas include the name of the performer in the profile table. If this table does not exist we will have to derive the performer name from the filepath, assuming the db is in a /metadata/ folder.
        $Query = "PRAGMA table_info(medias)"
        $OFDBColumnsToCheck = Invoke-SqliteQuery -Query $Query -DataSource $OFDatabaseFilesCollection[0].FullName
        #There's probably a faster way to do this, but I'm throwing the collection into a string, with each column result (aka table name) seperated by a space. 
        $OFDBColumnsToCheck = [string]::Join(' ',$OFDBColumnsToCheck.name) 

        $performername = $null
        if ($OFDBColumnsToCheck -match "profiles"){
            $Query = "SELECT username FROM profiles LIMIT 1" #I'm throwing that limit on as a precaution-- I'm not sure if multiple usernames will ever be stored in that SQL table
            $performername =  Invoke-SqliteQuery -Query $Query -DataSource $OFDatabaseFilesCollection[0].FullName
        }

        #Either the query resulted in null or the profiles table didnt exist, so either way let's use the alternative directory based method.
        if ($null -eq $performername){
            $performername = $OFDatabaseFilesCollection.FullName | split-path | split-path -leaf
            if ($performername -eq "metadata"){
                $performername = $OFDatabaseFilesCollection.FullName | split-path | split-path | split-path -leaf
            }
        }
        write-output "Discovered a metadata database for '$performername' "
    }

    #For the discovery of multiple database files
    elseif ($OFDatabaseFilesCollection.count -gt 1){
        
        $totalNumMetadataDatabases = $OFDatabaseFilesCollection.count
        write-host "...Discovered $totalnummetadatadatabases metadata databases."
        write-host "`nHow would you like to import metadata for these performers?"
        write-host "1 - Import metadata for all discovered performers"
        write-host "2 - Import metadata for a specific performer"
        write-host "3 - Import metadata for a range of performers"
        $selectednumberforprocess = read-host "Make your selection [Enter a number]"

        while([int]$selectednumberforprocess -notmatch "[1-3]" ){
            write-host "Invalid input"
            $selectednumberforprocess = read-host "Make your selection [Enter a number]"
        }

        if ([int]$selectednumberforprocess -eq 1){
            write-host "OK, all performers will be processed."
        }
        #Logic for handling the process for selecting a single performer
        elseif([int]$selectednumberforprocess -eq 2){
            write-host " " #Just adding a new line for a better UX
            #logic for displaying all found performers for user to select
            $i=1 # just used cosmetically
            Foreach ($OFDBdatabase in $OFDatabaseFilesCollection){
    
                #Getting the performer name from the profiles table (if it exists)
                $Query = "PRAGMA table_info(medias)"
                $OFDBColumnsToCheck = Invoke-SqliteQuery -Query $Query -DataSource $OFDBdatabase.FullName
    
                #There's probably a faster way to do this, but I'm throwing the collection into a string, with each column result (aka table name) seperated by a space. 
                $OFDBColumnsToCheck = [string]::Join(' ',$OFDBColumnsToCheck.name) 
                $performername = $null
                if ($OFDBColumnsToCheck -match "profiles"){
                    $Query = "SELECT username FROM profiles LIMIT 1" #I'm throwing that limit on as a precaution-- I'm not sure if multiple usernames will ever be stored in that SQL table
                    $performername =  Invoke-SqliteQuery -Query $Query -DataSource $OFDatabaseFilesCollection[0].FullName
                }
    
                #Either the query resulted in null or the profiles table didnt exist, so either way let's use the alternative directory based method.
                if ($null -eq $performername){
                    $performername = $OFDBdatabase.FullName | split-path | split-path -leaf
                    if ($performername -eq "metadata"){
                        $performername = $OFDBdatabase.FullName | split-path | split-path | split-path -leaf
                    }
                }
              
                write-output "$i - $performername"
                $i++
            }

            
            $selectednumber = read-host "`n# Which performer would you like to select? [Enter a number]"
            #Checking for bad input
            while ($selectednumber -notmatch "^[\d\.]+$" -or ([int]$selectednumber -gt $totalNumMetadataDatabases)){
                $selectednumber = read-host "Invalid Input. Please select a number between 0 and" $totalNumMetadataDatabases".`nWhich performer would you like to select? [Enter a number]"
            }

            $selectednumber = $selectednumber-1 #Since we are dealing with a 0 based array, i'm realigning the user selection
            $performername = $OFDatabaseFilesCollection[$selectednumber].FullName | split-path | split-path -leaf
            if ($performername -eq "metadata"){
                $performername = $OFDatabaseFilesCollection[$selectednumber].FullName | split-path | split-path | split-path -leaf #Basically if we hit the metadata folder, go a folder higher and call it the performer
            }
            
            #Specifically selecting the performer the user wants to parse.
            $OFDatabaseFilesCollection = $OFDatabaseFilesCollection[$selectednumber]

            write-output "OK, the performer '$performername' will be processed."

        }

        #Logic for handling the range process
        else{

            #Logic for displaying all found performers
            $i=1 # just used cosmetically
            write-host "`nHere are all the performers that you can import metadata for:"
            Foreach ($OFDBdatabase in $OFDatabaseFilesCollection){
    
                #Getting the performer name from the profiles table (if it exists)
                $Query = "PRAGMA table_info(medias)"
                $OFDBColumnsToCheck = Invoke-SqliteQuery -Query $Query -DataSource $OFDBdatabase.FullName
    
                #There's probably a faster way to do this, but I'm throwing the collection into a string, with each column result (aka table name) seperated by a space. 
                $OFDBColumnsToCheck = [string]::Join(' ',$OFDBColumnsToCheck.name) 
                $performername = $null
                if ($OFDBColumnsToCheck -match "profiles"){
                    $Query = "SELECT username FROM profiles LIMIT 1" #I'm throwing that limit on as a precaution-- I'm not sure if multiple usernames will ever be stored in that SQL table
                    $performername =  Invoke-SqliteQuery -Query $Query -DataSource $OFDatabaseFilesCollection[0].FullName
                }
    
                #Either the query resulted in null or the profiles table didnt exist, so either way let's use the alternative directory based method.
                if ($null -eq $performername){
                    $performername = $OFDBdatabase.FullName | split-path | split-path -leaf
                    if ($performername -eq "metadata"){
                        $performername = $OFDBdatabase.FullName | split-path | split-path | split-path -leaf
                    }
                }
              
                write-output "$i - $performername"
                $i++
            }

            #Some input handling/error handling for the user defined start of the range
            $StartOfRange = read-host "Which performer is the first in the range? [Enter a number]"
            $rangeInputCheck = $false

            while($rangeInputCheck -eq $false){
                if($StartOfRange -notmatch "^[\d\.]+$"){
                    write-host "`nInvalid Input: You have to enter a number"
                    $StartOfRange = read-host "Which performer is at the start of the range? [Enter a number]"
                }
                elseif($StartOfRange -le 0){
                    write-host "`nInvalid Input: You can't enter a number less than 1"
                    $StartOfRange = read-host "Which performer is at the start of the range? [Enter a number]"
                }
                elseif($StartOfRange -ge $totalNumMetadataDatabases){
                    write-host "`nInvalid Input: You can't enter a number greater than or equal to $totalNumMetadataDatabases"
                    $StartOfRange = read-host "Which performer is at the start of the range? [Enter a number]"
                }
                else{
                    $rangeInputCheck = $true
                }
            }

            #Some input handling/error handling for the user defined end of the range
            $endOfRange = Read-Host "Which performer is at the end of the range? [Enter a number]"
            $rangeInputCheck = $false

            while($rangeInputCheck -eq $false){
                if($EndOfRange -notmatch "^[\d\.]+$"){
                    write-host "`nInvalid Input: You have to enter a number"
                    $endOfRange = read-host "Which performer is at the end of the range? [Enter a number]"
                }
                elseif($EndOfRange -le 0){
                    write-host "`nInvalid Input: You can't enter a number less than 1"
                    $endOfRange = read-host "Which performer is at the end of the range? [Enter a number]"
                }
                elseif($endOfRange -gt $totalNumMetadataDatabases){
                    write-host "`nInvalid Input: You can't enter a number greater than $totalNumMetadataDatabases"
                    $endOfRange = read-host "Which performer is at the end of the range? [Enter a number]"
                }
                elseif($endOfRange -le $StartOfRange){
                    write-host "`nInvalid Input: Number has to be greater than $StartofRange"
                    $endOfRange = read-host "Which performer is at the end of the range? [Enter a number]"
                }
                else{
                    $rangeInputCheck = $true
                }
            }
            write-host "OK, all the performers between $startofrange and $endofrange will be processed."
            

            #We subtract 1 to account for us presenting the user with a 1 based start while PS arrays start at 0
            $endofrange = $endOfRange - 1 
            $StartOfRange = $StartOfRange - 1

            #Finally, let's define the new array of metadata databases based on the defined range
            $OFDatabaseFilesCollection = $OFDatabaseFilesCollection[$startofrange..$endOfRange]
            write-host $OFDatabaseFilesCollection
        }

        #Let's ask the user what type of media they want to parse
        write-host "`nWhich types of media do you want to import metadata for?"
        write-host "1 - Both Videos & Images`n2 - Only Videos`n3 - Only Images"

        $mediaToProcessSelector = 0;
        do {
            $mediaToProcessSelector = read-host "Make your selection [1-3]"
        }
        while (($mediaToProcessSelector -notmatch "[1-3]"))

        write-host "`nQuick Tips :" -ForegroundColor Cyan
        write-host "   * Be sure to run a Scan task in Stash of your OnlyFans content before running this script!`n   * Be sure your various OnlyFans metadata database(s) are located either at`n     <performername>"$directorydelimiter"user_data.db or at <performername>"$directorydelimiter"metadata"$directorydelimiter"user_data.db"
        read-host "`nPress [Enter] to begin"
    }

    #We use these values after the script finishes parsing in order to provide the user with some nice stats
    $numModified = 0
    $numUnmodified = 0
    $nummissingfiles = 0
    $scriptStartTime = get-date

    # --------------------------- Fetch FansDB API key --------------------------- #

    $FansDbGQL_URL = "https://fansdb.cc/graphql"

    # Fetch FansDB API key from the local Stash config
    $StashGQL_FansDBApiQuery = '
    query {
        configuration {
            general {
                stashBoxes {
                    endpoint
                    api_key
                }
            }
        }
    }' 
    try{
        $StashGQL_FansDBApiResult = Invoke-GraphQLQuery -Query $StashGQL_FansDBApiQuery -Uri $StashGQL_URL -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
    }
    catch{
        write-host "(1) Error: There was an issue with the GraphQL query." -ForegroundColor red
        write-host "Additional Error Info: `n`n$StashGQL_FansDBApiQuery"
        read-host "Press [Enter] to exit"
        exit
    }
    $FansDbGQL_ApiKey = ($StashGQL_FansDBApiResult.data.configuration.general.stashBoxes | where-object { $_.endpoint -eq $FansDbGQL_URL }).api_key

    # ------------------------- Get the OF network studio ------------------------ #

    $networkStudioName = "OnlyFans (network)"

    #Get the OnlyFans Studio ID
    $StashGQL_Query = '
    query FindStudios($filter: FindFilterType, $studio_filter: StudioFilterType) {
        findStudios(filter: $filter, studio_filter: $studio_filter) {
            count
            studios {
                id
                name
            }
        }
    }
    ' 
    $StashGQL_QueryVariables = '{
        "filter": {
          "q": ""
        },
        "studio_filter": {
          "name": {
            "value": "'+$networkStudioName+'",
            "modifier": "EQUALS"
          }
        }
      }'
    try{
        $StashGQL_Result = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
    }
    catch{
        write-host "(1) Error: There was an issue with the GraphQL query." -ForegroundColor red
        write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
        read-host "Press [Enter] to exit"
        exit
    }
    $networkStudioID = $StashGQL_Result.data.findStudios.Studios[0].id

    #If Stash returns with an ID for 'OnlyFans (network)', great. Otherwise, let's create a new studio
    if ($null -eq $networkStudioID){
        $FansDbNetworkName = "OnlyFans (network)"

        # Query FansDB for certain data, most importantly the studio stash ID.
        $FansDbGQL_Query = 'query {
            queryStudios(input: { name: "\"'+$FansDbNetworkName+'\"" }) {
                studios {
                    id
                    images { url }
                    name
                }
            }
        }'
        try{
            $FansDbGQL_Result = Invoke-GraphQLQuery -Query $FansDbGQL_Query -Uri $FansDbGQL_URL -Headers @{ApiKey = "$FansDbGQL_ApiKey" }
        }
        catch{
            write-host "Error: There was an issue with the FansDB GraphQL query." -ForegroundColor red
            write-host "Additional Error Info: `n`n$FansDbGQL_Query `n$FansDbGQL_QueryVariables"
            read-host "Press [Enter] to exit"
            exit
        }
    
        $StashGQL_Query = 'mutation StudioCreate($input: StudioCreateInput!) {
            studioCreate(input: $input) {
                aliases
                details
                name
                stash_ids {
                    endpoint
                    stash_id
                }
                url
            }
        }'
        $StashGQL_QueryVariables = '{
            "input": {
                "aliases": "OnlyFans",
                "details": "OnlyFans is the 18+ subscription platform empowering creators to own their full potential, monetize their content, and develop authentic connections with their fans.",
                "image": "'+$FansDbGQL_Result.data.queryStudios.studios[0].images[0].url+'",
                "name": "'+$networkStudioName+'",
                "stash_ids": [{
                    "endpoint": "'+$FansDbGQL_URL+'",
                    "stash_id": "'+$FansDbGQL_Result.data.queryStudios.studios[0].id+'"
                }],
                "url": "https://onlyfans.com/"
            }    
        }'
        try{
            $StashGQL_Result = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
        }
        catch{
            write-host "(9) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
            write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
            read-host "Press [Enter] to exit"
            exit
        }
        $StashGQL_Query = '
        query FindStudios($filter: FindFilterType, $studio_filter: StudioFilterType) {
            findStudios(filter: $filter, studio_filter: $studio_filter) {
                count
                studios {
                    id
                    name
                }
            }
        }'
        $StashGQL_QueryVariables = '{
            "filter": {
                "q": "'+$networkStudioName+'"
            }
        }'
        try{
            $StashGQL_Result = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
        }
        catch{
            write-host "(9a) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
            write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
            read-host "Press [Enter] to exit"
            exit
        }

        $networkStudioID = $StashGQL_Result.data.findStudios.Studios[0].id
        write-host "`nInfo: Added the 'OnlyFans (network)' studio to Stash's database." -ForegroundColor Cyan
    }

    # ----------------------------- Create the studio ---------------------------- #

    # Check if the studio exists
    $OnlyFansStudioName = "$performername (OnlyFans)"

    $StashGQL_Query = '
    query FindStudios($filter: FindFilterType, $studio_filter: StudioFilterType) {
        findStudios(filter: $filter, studio_filter: $studio_filter) {
            count
            studios {
                id
                name
            }
        }
    }
    ' 
    $StashGQL_QueryVariables = '{
        "filter": {
          "q": ""
        },
        "studio_filter": {
          "name": {
            "value": "'+$OnlyFansStudioName+'",
            "modifier": "EQUALS"
          }
        }
      }'
    try{
        $StashGQL_Result = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
    }
    catch{
        write-host "(1) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
        write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
        read-host "Press [Enter] to exit"
        exit
    }
    $OnlyFansStudioID = $StashGQL_Result.data.findStudios.Studios[0].id

    #If Stash returns with an ID for the page, great. Otherwise, let's create a new studio
    if ($null -eq $OnlyFansStudioID){
        # Get data from FansDB
        $FansDbStudioName = "$performername (OnlyFans)"

        # Query FansDB for certain data, most importantly the studio stash ID.
        $FansDbGQL_Query = 'query {
                queryStudios(input: { name: "\"'+$FansDbStudioName+'\"" }) {
                    studios {
                        id
                        name
                        urls {
                            url
                        }
                    }
                }
            }'
        try{
            $FansDbGQL_Result = Invoke-GraphQLQuery -Query $FansDbGQL_Query -Uri $FansDbGQL_URL -Headers @{ApiKey = "$FansDbGQL_ApiKey" }
        }
        catch{
            write-host "Error: There was an issue with the FansDB GraphQL query." -ForegroundColor red
            write-host "Additional Error Info: `n`n$FansDbGQL_Query `n$FansDbGQL_QueryVariables"
            read-host "Press [Enter] to exit"
            exit
        }
        
        # Create the studio
        $StashGQL_Query = 'mutation StudioCreate($input: StudioCreateInput!) {
            studioCreate(input: $input) {
                aliases
                name
                stash_ids {
                    endpoint
                    stash_id
                }
                url
            }
        }'

        # Format the URL for consistency
        $OnlyFansStudioURL = [string]$FansDbGQL_Result.data.queryStudios.studios[0].urls[0].url
        if($null -ne $OnlyFansStudioURL -and $OnlyFansStudioURL.Substring($OnlyFansStudioURL.Length - 1) -ne "/") {
            $OnlyFansStudioURL += "/"
        }

        $StashGQL_QueryVariables = '{
            "input": {
                "aliases": ["'+$performername+'"],
                "name": "'+$OnlyFansStudioName+'",
                "parent_id": '+$networkStudioID+',
                "stash_ids": [{
                    "endpoint": "'+$FansDbGQL_URL+'",
                    "stash_id": "'+$FansDbGQL_Result.data.queryStudios.studios[0].id+'"
                }],
                "url": "'+$OnlyFansStudioURL+'",
            }    
        }'

        try{
            $StashGQL_Result = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
        }
        catch{
            write-host "(9) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
            write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
            read-host "Press [Enter] to exit"
            exit
        }

        # Query the local Stash instance again to fetch the newly created studios ID.
        $StashGQL_Query = '
        query FindStudios($filter: FindFilterType, $studio_filter: StudioFilterType) {
            findStudios(filter: $filter, studio_filter: $studio_filter) {
                count
                studios {
                    id
                    name
                }
            }
        }' 
        $StashGQL_QueryVariables = '{
            "filter": {
                "q": "'+$OnlyFansStudioName+'"
            }
        }'
        try{
            $StashGQL_Result = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
        }
        catch{
            write-host "(9a) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
            write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
            read-host "Press [Enter] to exit"
            exit
        }

        $OnlyFansStudioID = $StashGQL_Result.data.findStudios.Studios[0].id
        write-host "`nInfo: Added the studio '$OnlyFansStudioName' to Stash's database" -ForegroundColor Cyan
    }

    function Get-StashMetaTagID {
        param (
            [string]$stashTagName
        )
        $stashTagID = $null

        $StashGQL_TagQuery = '
        query FindTags($tag_filter: TagFilterType) {
            findTags(tag_filter: $tag_filter) {
                tags {
                    id
                    name
                }
            }
        }
        ' 
        $StashGQL_TagQueryVariables = '{
            "tag_filter": {
              "name": {
                "value": "'+$stashTagName+'",
                "modifier": "EQUALS"
              }
            }
        }'
        try{
            $StashGQL_TagResult = Invoke-GraphQLQuery -Query $StashGQL_TagQuery -Uri $StashGQL_URL -Variables $StashGQL_TagQueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
        }
        catch{
            write-host "(9a) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
            write-host "Additional Error Info: `n`n$StashGQL_TagQuery `n$StashGQL_TagQueryVariables"
            read-host "Press [Enter] to exit"
            exit
        }

        $stashTagID = $StashGQL_TagResult.data.findTags.tags[0].id
        return $stashTagID
    }

    function Set-StashMetaTagID {
        param(
            [string]$thisStashTagName
        )

        $StashGQL_TagCreateQuery = 'mutation TagCreate($input: TagCreateInput!) {
            tagCreate(input: $input) {
                name
            }
        }'

        $StashGQL_TagCreateQueryVariables = '{
            "input": {
                "name": "'+$thisStashTagName+'",
            }    
        }' 
    
        try{
            Invoke-GraphQLQuery -Query $StashGQL_TagCreateQuery -Uri $StashGQL_URL -Variables $StashGQL_TagCreateQueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }}) | out-null
        }
        catch{
            write-host "(3) Error: There was an issue with the GraphQL mutation." -ForegroundColor red
            write-host "Additional Error Info: `n`n$StashGQL_TagCreateQuery `n$StashGQL_TagCreateQueryVariables"
            read-host "Press [Enter] to exit"
            exit
        }
    }

    $totalprogressCounter = 1 #Used for the progress UI

    foreach ($currentdatabase in $OFDatabaseFilesCollection) {
        #Let's help the user see how we are progressing through this metadata database (this is the parent progress UI, there's an additional child below as well)
        $currentTotalProgress = [int]$(($totalprogressCounter/$OFDatabaseFilesCollection.count)*100)
        Write-Progress -id 1 -Activity "Total Import Progress" -Status "$currentTotalProgress% Complete" -PercentComplete $currentTotalProgress
        $totalprogressCounter++


        #Gotta reparse the performer name as we may be parsing through a full collection of performers. 
        #Otherwise you'll end up with a whole bunch of performers having the same name
        #This is also where we will make the determination if this onlyfans database has the right tables to be used here
        #First step, let's check to ensure this OF db is valid for use
        $Query = "PRAGMA table_info(medias)"
        $OFDBColumnsToCheck = Invoke-SqliteQuery -Query $Query -DataSource $currentdatabase.FullName

        #There's probably a faster way to do this, but I'm throwing the collection into a string, with each column result (aka table name) seperated by a space. 
        #Then we use a match condition and a whole lot of or statements to determine if this db has all the right columns this script needs.
        $OFDBColumnsToCheck = [string]::Join(' ',$OFDBColumnsToCheck.name) 
        if (($OFDBColumnsToCheck -notmatch "media_id") -or ($OFDBColumnsToCheck -notmatch "post_id") -or ($OFDBColumnsToCheck -notmatch "directory") -or ($OFDBColumnsToCheck -notmatch "filename") -or ($OFDBColumnsToCheck -notmatch "size") -or ($OFDBColumnsToCheck -notmatch "media_type") -or ($OFDBColumnsToCheck -notmatch "created_at")){
            $SchemaIsValid = $false
        }
        else {
            $SchemaIsValid = $true
        }

        #If the OF metadata db is no good, tell the user and skip the rest of this very massive conditional block (I need to refactor this)
        if ((!$SchemaIsValid)){
            write-host "Error: The following OnlyFans metadata database doesn't contain the metadata in a format that this script expects." -ForegroundColor Red
            write-host "This can occur if you've scraped OnlyFans using an unsupported tool. " -ForegroundColor Red
            write-output $currentdatabase.FullName
            read-host "Press [Enter] to continue"
            
        }
        else{
            #More modern OF DB schemas include the name of the performer in the profile table. If this table does not exist we will have to derive the performer name from the filepath, assuming the db is in a /metadata/ folder.
            $performername = $null
            if ($OFDBColumnsToCheck -match "profiles"){
                $Query = "SELECT username FROM profiles LIMIT 1" #I'm throwing that limit on as a precaution-- I'm not sure if multiple usernames will ever be stored in that SQL table
                $performername =  Invoke-SqliteQuery -Query $Query -DataSource $currentdatabase.FullName
                
            }

            #Either the query resulted in null or the profiles table didnt exist, so either way let's use the alternative directory based method.
            if ($null -eq $performername){
                $performername = $currentdatabase.FullName | split-path | split-path -leaf
                
                if ($performername -eq "metadata"){
                    $performername = $currentdatabase.FullName | split-path | split-path | split-path -leaf
                }
            }

            #Let's see if we can find this performer in Stash
            $StashGQL_Query = '
            query FindPerformers($filter: FindFilterType, $performer_filter: PerformerFilterType) {
               findPerformers(filter: $filter, performer_filter: $performer_filter) {
                 count
                 performers {
                   id
                   name
                 }
               }
             }
            ' 
            $StashGQL_QueryVariables = '{
                "filter": {
                    "q": "'+$performername+'"
                }
            }'
            try{
                $StashGQL_Result = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
            }
            catch{
                write-host "(2) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
                write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
                read-host "Press [Enter] to exit"
                exit
            }
            $PerformerID = $StashGQL_Result.data.findPerformers.performers[0].id
            
            #If we had no luck finding the performer, lets create one, then get the ID
            if($null -eq $performerID){
       
                $StashGQL_Query = 'mutation PerformerCreate($input: PerformerCreateInput!) {
                    performerCreate(input: $input) {
                        name
                        url
                    }
                  }'

                $StashGQL_QueryVariables = '{
                    "input": {
                        "name": "'+$performername+'",
                        "url": "www.onlyfans.com/'+$performername+'"
                    }    
                }' 
            
                try{
                    Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }}) | out-null
                }
                catch{
                    write-host "(3) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
                    write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
                    read-host "Press [Enter] to exit"
                    exit
                }
                $StashGQL_Query = '
                query FindPerformers($filter: FindFilterType, $performer_filter: PerformerFilterType) {
                   findPerformers(filter: $filter, performer_filter: $performer_filter) {
                     count
                     performers {
                       id
                       name
                     }
                   }
                 }
                ' 
                $StashGQL_QueryVariables = '{
                    "filter": {
                        "q": "'+$performername+'"
                    }
                }'
                try{
                    $StashGQL_Result = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
                }
                catch{
                    write-host "(22) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
                    write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
                    read-host "Press [Enter] to exit"
                    exit
                }
                $PerformerID = $StashGQL_Result.data.findPerformers.performers[0].id
                $boolGetPerformerImage = $true #We'll use this to get an image to use for the profile picture
                
                
            }
            else{
                $boolGetPerformerImage = $false
            }

            #Let's check to see if we need to import this performer based on the history file using the DatabaseHasBeenImported function
            #The ignorehistory variable is a command line flag that the user may set if they want to have the script ignore the use of the history file
             
            if (!(DatabaseHasAlreadyBeenImported)){
                #Select all the media (except audio) and the text the performer associated to them, if available from the OFDB
                $Query = "SELECT messages.text, medias.directory, medias.filename, medias.size, medias.created_at, medias.post_id, medias.media_id, medias.api_type, medias.media_type FROM medias INNER JOIN messages ON messages.post_id=medias.post_id UNION SELECT posts.text, medias.directory, medias.filename, medias.size, posts.created_at, medias.post_id, medias.media_id, medias.api_type, medias.media_type FROM medias INNER JOIN posts ON posts.post_id=medias.post_id WHERE medias.media_type <> 'Audios'"
                $OF_DBpath = $currentdatabase.fullname 
                $OFDBQueryResult = Invoke-SqliteQuery -Query $Query -DataSource $OF_DBpath

                $progressCounter = 1 #Used for the progress UI
                foreach ($OFDBMedia in $OFDBQueryResult){

                    #Let's help the user see how we are progressing through this performer's metadata database
                    $currentProgress = [int]$(($progressCounter/$OFDBQueryResult.count)*100)
                    Write-Progress -parentId 1 -Activity "$performername Import Progress" -Status "$currentProgress% Complete" -PercentComplete $currentProgress
                    $progressCounter++
    
                    #Generating the URL for this post
                    $linktoOFpost = "https://www.onlyfans.com/"+$OFDBMedia.post_ID+"/"+$performername
                    
                    #Reformatting the date to something stash appropriate
                    $creationdatefromOF = $OFDBMedia.created_at
                    $creationdatefromOF = Get-Date $creationdatefromOF -format "yyyy-MM-dd"
                    
                    $OFDBfilesize = $OFDBMedia.size #filesize (in bytes) of the media, from the OF DB
                    $OFDBfilename = $OFDBMedia.filename #This defines filename of the media, from the OF DB
                    $OFDBdirectory = $OFDBMedia.directory #This defines the file directory of the media, from the OF DB
                    $OFDBFullFilePath = $OFDBdirectory+$directorydelimiter+$OFDBfilename #defines the full file path, using the OS appropriate delimeter
    
                    #Storing separate variants of these variables with apostrophy and backslash sanitization so they don't ruin our SQL/GQL queries
                    $OFDBfilenameForQuery = $OFDBfilename.replace("'","''") 
                    $OFDBfilenameForQuery = $OFDBfilename.replace("\","\\") 
    
                    #Note that the OF downloader quantifies gifs as videos for some reason
                    #Since Stash doesn't (and rightfully so), we need to account for this
                    if(($OFDBMedia.media_type -eq "videos") -and ($OFDBfilename -notlike "*.gif")){
                        $mediatype = "video"
                    }
                    #Condition for images. Again, we have to add an extra condition just in case the image is a gif due to the DG database
                    elseif(($OFDBMedia.media_type -eq "images") -or ($OFDBfilename -like "*.gif")){
                        $mediatype = "image"
                    }
    
                    #Depending on the user preference, we may not want to actually process the media we're currently looking at. Let's check before continuing.
                    if (($mediaToProcessSelector -eq 2) -and ($mediatype -eq "image")){
                        #There's a scenario where because the user has not pulled any images for this performer, there will be no performer image. In that scenario, lets pull exactly one image for this purpose
                        if ($boolGetPerformerImage){
                            $boolGetPerformerImage = $false #Let's make sure we don't pull any more photos
                        }
                        else{
                            continue #Skip to the next item in this foreach, user only wants to process videos
                        }
                    }
    
                    if (($mediaToProcessSelector -eq 3) -and ($mediatype -eq "video")){
                        continue #Skip to the next item in this foreach, user only wants to process images
                    }
                    
                    #Depending on user preference, we want to be more/less specific with our SQL queries to the Stash DB here, as determined by this condition tree (defined in order of percieved popularity)
                    #Normal specificity, search for videos based on having the performer name somewhere in the path and a matching filesize
                    if ($mediatype -eq "video" -and $searchspecificity -match "normal"){
                        $StashGQL_Query = 'mutation {
                            querySQL(sql: "SELECT folders.path, files.basename, files.size, files.id AS files_id, folders.id AS folders_id, scenes.id AS scenes_id, scenes.title AS scenes_title, scenes.details AS scenes_details FROM files JOIN folders ON files.parent_folder_id=folders.id JOIN scenes_files ON files.id = scenes_files.file_id JOIN scenes ON scenes.id = scenes_files.scene_id WHERE path LIKE ''%'+$performername+'%'' AND size = '''+$OFDBfilesize+'''") {
                            rows
                          }
                        }'             
                    }
                    #Normal specificity, search for images based on having the performer name somewhere in the path and a matching filesize
                    elseif ($mediatype -eq "image" -and $searchspecificity -match "normal"){
                        $StashGQL_Query = 'mutation {
                            querySQL(sql: "SELECT folders.path, files.basename, files.size, files.id AS files_id, folders.id AS folders_id, images.id AS images_id, images.title AS images_title FROM files JOIN folders ON files.parent_folder_id=folders.id JOIN images_files ON files.id = images_files.file_id JOIN images ON images.id = images_files.image_id WHERE path LIKE ''%'+$performername+'%'' AND size = '''+$OFDBfilesize+'''") {
                            rows
                          }
                        }'
                    }
                    #Low specificity, search for videos based on filesize only
                    elseif ($mediatype -eq "video" -and $searchspecificity -match "low"){
                        $StashGQL_Query = 'mutation {
                            querySQL(sql: "SELECT folders.path, files.basename, files.size, files.id AS files_id, folders.id AS folders_id, scenes.id AS scenes_id, scenes.title AS scenes_title, scenes.details AS scenes_details FROM files JOIN folders ON files.parent_folder_id=folders.id JOIN scenes_files ON files.id = scenes_files.file_id JOIN scenes ON scenes.id = scenes_files.scene_id WHERE size = '''+$OFDBfilesize+'''") {
                            rows
                          }
                        }'   
                    }
                    #Low specificity, search for images based on filesize only
                    elseif ($mediatype -eq "image" -and $searchspecificity -match "low"){
                        $StashGQL_Query = 'mutation {
                            querySQL(sql: "SELECT folders.path, files.basename, files.size, files.id AS files_id, folders.id AS folders_id, images.id AS images_id, images.title AS images_title FROM files JOIN folders ON files.parent_folder_id=folders.id JOIN images_files ON files.id = images_files.file_id JOIN images ON images.id = images_files.image_id WHERE size = '''+$OFDBfilesize+'''") {
                            rows
                          }
                        }'
                    }
    
                    #High specificity, search for videos based on matching file name between OnlyFans DB and Stash DB as well as matching the filesize. 
                    elseif ($mediatype -eq "video" -and $searchspecificity -match "high"){
                        $StashGQL_Query = 'mutation {
                            querySQL(sql: "SELECT folders.path, files.basename, files.size, files.id AS files_id, folders.id AS folders_id, scenes.id AS scenes_id, scenes.title AS scenes_title, scenes.details AS scenes_details FROM files JOIN folders ON files.parent_folder_id=folders.id JOIN scenes_files ON files.id = scenes_files.file_id JOIN scenes ON scenes.id = scenes_files.scene_id WHERE files.basename ='''+$OFDBfilenameForQuery+''' AND size = '''+$OFDBfilesize+'''") {
                            rows
                          }
                        }'
                    }
    
                    #High specificity, search for images based on matching file name between OnlyFans DB and Stash DB as well as matching the filesize. 
                    else{
                        $StashGQL_Query = 'mutation {
                            querySQL(sql: "SELECT folders.path, files.basename, files.size, files.id AS files_id, folders.id AS folders_id, images.id AS images_id, images.title AS images_title FROM files JOIN folders ON files.parent_folder_id=folders.id JOIN images_files ON files.id = images_files.file_id JOIN images ON images.id = images_files.image_id WHERE files.basename ='''+$OFDBfilenameForQuery+''' AND size = '''+$OFDBfilesize+'''") {
                            rows
                          }
                        }'
                    }
    
                    #Now lets try running the GQL query and see if we have a match in the Stash DB
                    try{
                        $StashGQL_Result = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
                    }
                    catch{
                        write-host "(4) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
                        write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
                        read-host "Press [Enter] to exit"
                        exit
                    }
    
                    if ($StashGQL_Result.data.querySQL.rows.length -ne 0){
    
                        #Because of how GQL returns data, these values are just positions in the $StashGQLQuery array. Not super memorable, so I'm putting them in variables. 
                        $CurrentFileID = $StashGQL_Result.data.querySQL.rows[0][5] #This represents either the scene ID or the image ID. To be generic, I'm defining it as "CurrentFileID"
                        $CurrentFileTitle = $StashGQL_Result.data.querySQL.rows[0][6]
                    }
                    
                    #If our search for matching media in Stash itself comes up empty, let's check to see if the file even exists on the file system 
                    if ($StashGQL_Result.data.querySQL.rows.length -eq 0 ){

                        #Let's be extra about this error message. If there's no match, swap the directory path delimeters and try again.
                        if (!(Test-Path $OFDBFullFilePath)){
                            if ($OFDBFullFilePath.Contains('/')){
                                $OFDBFullFilePath = $OFDBFullFilePath.Replace("/","\")
                            }
                            else{
                                $OFDBFullFilePath = $OFDBFullFilePath.Replace("\","/")
                            }
                            if (!(Test-Path $OFDBFullFilePath)){
                                write-host "`nInfo: There's a file in this OnlyFans metadata database that we couldn't find in your Stash database.`nThis file also doesn't appear to be on your filesystem (we checked with both Windows and *nix path delimeters).`nTry rerunning the script you used to scrape this OnlyFans performer and redownloading the file." -ForegroundColor Cyan
                                write-host "- Scan Specificity Mode: $SearchSpecificity"
                                write-host "- Filename: $OFDBfilename"
                                write-host "- Directory: $OFDBdirectory"
                                write-host "- Filesize: $OFDBfilesize"
                                write-host "^ (Filename, Directory and Filesize are as defined by the OF Metadata Database) ^"
                                Add-Content -Path $PathToMissingFilesLog -value " $OFDBFullFilePath"
                                $nummissingfiles++

                            }
                            else{
                                write-host "`nInfo: There's a file in this OnlyFans metadata database that we couldn't find in your Stash database but the file IS on your filesystem.`nTry running a Scan Task in Stash then re-running this script." -ForegroundColor Cyan
                                write-host "- Filename: $OFDBfilename"
                                write-host "- Directory: $OFDBdirectory"
                                write-host "- Filesize: $OFDBfilesize"
                                write-host "^ (Filename, Directory and Filesize are as defined by the OF Metadata Database) ^"
                                Add-Content -Path $PathToMissingFilesLog -value " $OFDBFullFilePath"
                                $nummissingfiles++
                            }
                        }
                    }
                    #Otherwise we have found a match! let's process the matching result and add the metadata we've found
                    else{
                        
                        #Before processing, and for the sake of accuracy, if there are multiple filesize matches (specifically for the normal specificity mode), add a filename check to the query to see if we can match more specifically. If not, just use whatever matched that initial query.
                        if (($StashGQL_Result.data.querySQL.rows.length -gt 1) -and ($searchspecificity -match "normal") ){
                            #Search for videos based on having the performer name somewhere in the path and a matching filesize (and filename in this instance)
                            if ($mediatype -eq "video"){
                               
                                $StashGQL_Query = 'mutation {
                                    querySQL(sql: "SELECT folders.path, files.basename, files.size, files.id AS files_id, folders.id AS folders_id, scenes.id AS scenes_id, scenes.title AS scenes_title, scenes.details AS scenes_details FROM files JOIN folders ON files.parent_folder_id=folders.id JOIN scenes_files ON files.id = scenes_files.file_id JOIN scenes ON scenes.id = scenes_files.scene_id path LIKE ''%'+$performername+'%'' AND files.basename ='''+$OFDBfilenameForQuery+''' AND size = '''+$OFDBfilesize+'''") {
                                    rows
                                  }
                                }'
                            }
    
                            #Search for images based on having the performer name somewhere in the path and a matching filesize (and filename in this instance)
                            elseif ($mediatype -eq "image" ){
                                
                                $StashGQL_Query = 'mutation {
                                    querySQL(sql: "SELECT folders.path, files.basename, files.size, files.id AS files_id, folders.id AS folders_id, images.id AS images_id, images.title AS images_title FROM files JOIN folders ON files.parent_folder_id=folders.id JOIN images_files ON files.id = images_files.file_id JOIN images ON images.id = images_files.image_id WHERE path LIKE ''%'+$performername+'%'' AND files.basename ='''+$OFDBfilenameForQuery+''' AND size = '''+$OFDBfilesize+'''") {
                                    rows
                                  }
                                }'
                            }
    
                            #Now lets try running the GQL query and try to find the file in the Stash DB
                            try{
                                $AlternativeStashGQL_Result = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
                            }
                            catch{
                                write-host "(5) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
                                write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
                                read-host "Press [Enter] to exit"
                                exit
                            }
    
                            #If we have a match, substitute it in and lets get that metadata into the Stash DB
                            if($StashGQL_Result_2.data.querySQL.rows -eq 1){
                                $StashGQL_Result = $AlternativeStashGQL_Result
                                $CurrentFileID = $StashGQL_Result.data.querySQL.rows[0][5] #This represents either the scene ID or the image ID
                                $CurrentFileTitle = $StashGQL_Result.data.querySQL.rows[0][6]
                            } 
                        }

                        # ----------------------------------- Title ---------------------------------- #
    
                        #Creating the title we want for the media, and defining Stash details for this media.
                        $mediaID = $OFDBMedia.media_id
                        $postID = $OFDBMedia.post_ID
                        $proposedtitleSuffix = "| $postID"

                        # Get the media type
                        $OFDBMediaType = $OFDBMedia.media_type

                        # If the media is one of several items of the same media type in the same post, add its position to the title.
                        $OFDBMultipostQuery = "SELECT medias.media_id FROM medias WHERE medias.post_id='$postID' AND medias.media_type='$OFDBMediaType'"
                        $OFDBMultipostQueryResult = Invoke-SqliteQuery -Query $OFDBMultipostQuery -DataSource $OF_DBpath

                        if($OFDBMultipostQueryResult.count -gt 1) {
                            # Get the position of this media in the array. Data is already in the correct order. 
                            $mediaPostPosition = [array]::indexof($OFDBMultipostQueryResult.media_id,$mediaID) + 1
                            $mediaPostLength = $OFDBMultipostQueryResult.count
                            $proposedtitleSuffix = $proposedtitleSuffix+" [$mediaPostPosition/$mediaPostLength]"
                        }

                        $proposedtitle = "$performername $proposedtitleSuffix"
                        $proposedtitle = $proposedtitle.replace("'","''")
                        $proposedtitle = $proposedtitle.replace("\","\\")
                        $proposedtitle = $proposedtitle.replace('"','\"')
                        $proposedtitle = $proposedtitle.replace('“','\"') #literally removing the curly quote entirely
                        $proposedtitle = $proposedtitle.replace('”','\"') #literally removing the curly quote entirely

                        # Details
                        $detailsToAddToStash = $OFDBMedia.text
                            
                        #Performers love to put links in their posts sometimes. Let's scrub those out in addition to any common HTML bits
                        $detailsToAddToStash = $detailsToAddToStash.Replace("<br />","")
                        $detailsToAddToStash = $detailsToAddToStash.Replace("<a href=","")
                        $detailsToAddToStash = $detailsToAddToStash.Replace("<a href =","")
                        $detailsToAddToStash = $detailsToAddToStash.Replace('"/',"")
                        $detailsToAddToStash = $detailsToAddToStash.Replace('">',"")
                        $detailsToAddToStash = $detailsToAddToStash.Replace("</a>"," ")
                        $detailsToAddToStash = $detailsToAddToStash.Replace('target="_blank"',"")
    
                        #For some reason the invoke-graphqlquery module doesn't quite escape single/double quotes ' " (or their curly variants) or backslashs \ very well so let's do it manually for the sake of our JSON query
                        $detailsToAddToStash = $detailsToAddToStash.replace("\","\\")
                        $detailsToAddToStash = $detailsToAddToStash.replace('"','\"')
                        $detailsToAddToStash = $detailsToAddToStash.replace('“','\"') #literally removing the curly quote entirely
                        $detailsToAddToStash = $detailsToAddToStash.replace('”','\"') #literally removing the curly quote entirely
    
                        #Let's check to see if this is a file that already has metadata.
                        #If any metadata is missing, we don't bother with updating a specific column, we just update the entire row
                        if ($mediatype -eq "video"){
                            #By default we will claim this file to be unmodified (we use this for user stats at the end of the script)
                            $filewasmodified = $false
    
                            #Let's determine if this scene already has the right performer associated to it
                            $StashGQL_Query = 'query FindScene($id:ID!) {
                                findScene(id: $id){
                                    performers {
                                        id 
                                    }
                                }
                            
                            }'
                            $StashGQL_QueryVariables = '{
                                    "id": "'+$CurrentFileID+'"
                            }' 
                            
                            try{
                                $DiscoveredPerformerIDFromStash = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
                            }
                            catch{
                                write-host "(6) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
                                write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
                                read-host "Press [Enter] to exit"
                                exit
                            }
    
                            $performermatch = $false
                            if ($null -ne $DiscoveredPerformerIDFromStash.data.findscene.performers.length){
                                foreach ($performer in $DiscoveredPerformerIDFromStash.data.findscene.performers.id){
                                    if($performer -eq $performerid){  
                                        $performermatch = $true
                                        break
                                    }
                                }
                            }
                            if (!$performermatch){
                                $filewasmodified = $true
                                $StashGQL_Query = 'mutation sceneUpdate($sceneUpdateInput: SceneUpdateInput!){
                                    sceneUpdate(input: $sceneUpdateInput){
                                        id
                                        performers{
                                            id
                                        }
                                    }
                                }'
                                $StashGQL_QueryVariables = ' {
                                    "sceneUpdateInput": {
                                        "id": "'+$CurrentFileID+'",
                                        "performer_ids": "'+$performerID+'"
                                    }
                                }'
                                try{
                                    Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }}) | out-null
                                }
                                catch{
                                    write-host "(7) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
                                    write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
                                    read-host "Press [Enter] to exit"
                                    exit
                                }
                            }

                            # Check for an affiliated gallery that has already been created
                            $StashGQL_Query = 'query FindPostGallery($filter: FindFilterType, $gallery_filter: GalleryFilterType) {
                                findGalleries(filter: $filter, gallery_filter: $gallery_filter) {
                                    galleries { id }
                                }
                            }'
                            $StashGQL_QueryVariables = '{
                                "filter": {
                                  "q": ""
                                },
                                "gallery_filter": {
                                  "code": {
                                    "value": "'+$postID+'",
                                    "modifier": "EQUALS"
                                  }
                                }
                              }'
                            try{
                                $StashGQL_Result = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
                            }
                            catch{
                                write-host "(1) Error: There was an issue with the GraphQL query." -ForegroundColor red
                                write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
                                read-host "Press [Enter] to exit"
                                exit
                            }
                            $postGalleryID = $StashGQL_Result.data.findGalleries.galleries[0].id
    
                            #If it's necessary, update the scene by modifying the title and adding details
                            if($CurrentFileTitle -ne $proposedtitle -or $ignorehistory -eq $true){
                                $StashGQL_Query = 'mutation sceneUpdate($sceneUpdateInput: SceneUpdateInput!){
                                    sceneUpdate(input: $sceneUpdateInput){
                                      code
                                      date
                                      details
                                      galleries { id }
                                      id
                                      studio { id }
                                      title
                                      urls
                                    }
                                  }'  
                                $StashGQL_QueryVariables = '{
                                    "sceneUpdateInput": {
                                        "code": "'+$mediaID+'",
                                        "date": "'+$creationdatefromOF+'",
                                        "details": "'+$detailsToAddToStash+'",
                                        "gallery_ids": ['+$postGalleryID+'],
                                        "id": "'+$CurrentFileID+'",
                                        "studio_id": "'+$OnlyFansStudioID+'",
                                        "title": "'+$proposedtitle+'",
                                        "urls": "'+$linktoOFpost+'",
                                    }
                                }'
    
                                try{
                                    Invoke-GraphQLQuery -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }}) -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -escapehandling EscapeNonAscii | out-null
                                }
                                catch{
                                    write-host "(8) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
                                    write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
                                    read-host "Press [Enter] to exit" 
                                    exit
                                }
    
                                $filewasmodified = $true
                            }
    
                            #Provide user feedback on what has occured and add to the "file modified" counter for stats later
                            if ($filewasmodified){
                                if ($v){
                                    write-output "- Added metadata to Stash's database for the following file:`n   $OFDBFullFilePath" 
                                }
                                $numModified++  
                            }
                            else{
                                if ($v){
                                    write-output "- This file already has metadata, moving on...`n   $OFDBFullFilePath"
                                }
                                $numUnmodified++
                            }
                        }
    
                        #For images
                        else{
                            #By default we will claim this file to be unmodified (we use this for user stats at the end of the script)
                            $filewasmodified = $false
    
                            #Let's determine if this Image already has the right performer associated to it
                            $StashGQL_Query = 'query FindImage($id:ID!) {
                                findImage(id: $id){
                                    performers {
                                        id 
                                    }
                                }
                            
                            }'
                            $StashGQL_QueryVariables = '{
                                    "id": "'+$CurrentFileID+'"
                            }' 
                            
                            try{
                                $DiscoveredPerformerIDFromStash = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
                            }
                            catch{
                                write-host "(6) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
                                write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
                                read-host "Press [Enter] to exit"
                                exit
                            }
    
                            $performermatch = $false
                            if ($null -ne $DiscoveredPerformerIDFromStash.data.findimage.performers.length){
                                foreach ($performer in $DiscoveredPerformerIDFromStash.data.findimage.performers.id){
                                    if($performer -eq $performerid){       
                                        $performermatch = $true
                                        break
                                    }
                                }
                            }
                            if (!$performermatch){
                                $filewasmodified = $true
                                $StashGQL_Query = 'mutation imageUpdate($imageUpdateInput: ImageUpdateInput!){
                                    imageUpdate(input: $imageUpdateInput){
                                        id
                                        performers{
                                            id
                                        }
                                    }
                                }'
                                $StashGQL_QueryVariables = ' {
                                    "imageUpdateInput": {
                                        "id": "'+$CurrentFileID+'",
                                        "performer_ids": "'+$performerID+'"
                                    }
                                }'
                                try{
                                    Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }}) | out-null
                                }
                                catch{
                                    write-host "(7) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
                                    write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
                                    read-host "Press [Enter] to exit"
                                    exit
                                }
                                
                            }

                            # ----------------------------- Add metadata tags ---------------------------- #

                            $postType = $OFDBMedia.api_type

                            $stashTagName_availability_archived = "[Meta] availability: archived"
                            $stashTagID_availability_archived = Get-StashMetaTagID -stashTagName $stashTagName_availability_archived

                            $stashTagName_postType_message = "[Meta] post type: message"
                            $stashTagName_postType_story = "[Meta] post type: story"
                            $stashTagName_postType_wallPost = "[Meta] post type: wall post"
                            $stashTagID_postType_message = Get-StashMetaTagID -stashTagName $stashTagName_postType_message
                            $stashTagID_postType_story = Get-StashMetaTagID -stashTagName $stashTagName_postType_story
                            $stashTagID_postType_wallPost = Get-StashMetaTagID -stashTagName $stashTagName_postType_wallPost

                            $stashTagName_price_free = "[Meta] pricing: free"
                            $stashTagID_price_free = Get-StashMetaTagID -stashTagName $stashTagName_price_free
                            $stashTagName_price_paid = "[Meta] pricing: paid"
                            $stashTagID_price_paid = Get-StashMetaTagID -stashTagName $stashTagName_price_paid

                            $stashTagName_scraper_ofdl = "[Meta] scraper: OFDL"
                            $stashTagID_scraper_ofdl = Get-StashMetaTagID -stashTagName $stashTagName_scraper_ofdl

                            # Tag everything with an OFDL tag
                            if($null -eq $stashTagID_scraper_ofdl) {
                                Set-StashMetaTagID -thisStashTagName $stashTagName_scraper_ofdl
                                $stashTagID_scraper_ofdl = Get-StashMetaTagID -stashTagName $stashTagName_scraper_ofdl
                            }
                            $tagIDsToAdd = @($stashTagID_scraper_ofdl)

                            # Post type tags
                            if($postType -eq "Messages") {
                                # Check if the tag ID we got earlier is null. If so, create a new tag.
                                if($null -eq $stashTagID_postType_message) {
                                    Set-StashMetaTagID -thisStashTagName $stashTagName_postType_message
                                    $stashTagID_postType_message = Get-StashMetaTagID -stashTagName $stashTagName_postType_message
                                }
                                $tagIDsToAdd += $stashTagID_postType_message
                            } elseif($postType -eq "Posts") {
                                # Check if the tag ID we got earlier is null. If so, create a new tag.
                                if($null -eq $stashTagID_postType_wallPost) {
                                    Set-StashMetaTagID -thisStashTagName $stashTagName_postType_wallPost
                                    $stashTagID_postType_wallPost = Get-StashMetaTagID -stashTagName $stashTagName_postType_wallPost
                                }
                                $tagIDsToAdd += $stashTagID_postType_wallPost
                            } elseif($postType -eq "Stories") {
                                # Check if the tag ID we got earlier is null. If so, create a new tag.
                                if($null -eq $stashTagID_postType_story) {
                                    Set-StashMetaTagID -thisStashTagName $stashTagName_postType_story
                                    $stashTagID_postType_story = Get-StashMetaTagID -stashTagName $stashTagName_postType_story
                                }
                                $tagIDsToAdd += $stashTagID_postType_story
                            }

                            # Pricing tags
                            if($OFDBdirectory.contains("/Free/")) {
                                # Check if the tag ID we got earlier is null. If so, create a new tag.
                                if($null -eq $stashTagID_price_free) {
                                    Set-StashMetaTagID -thisStashTagName $stashTagName_price_free
                                    $stashTagID_price_free = Get-StashMetaTagID -stashTagName $stashTagName_price_free
                                }
                                $tagIDsToAdd += $stashTagID_price_free
                            } elseif($OFDBdirectory.contains("/Paid/")) {
                                # Check if the tag ID we got earlier is null. If so, create a new tag.
                                if($null -eq $stashTagID_price_paid) {
                                    Set-StashMetaTagID -thisStashTagName $stashTagName_price_paid
                                    $stashTagID_price_paid = Get-StashMetaTagID -stashTagName $stashTagName_price_paid
                                }
                                $tagIDsToAdd += $stashTagID_price_paid
                            }

                            # Availability tags
                            if($OFDBdirectory.contains("/Archived/")) {
                                # Check if the tag ID we got earlier is null. If so, create a new tag.
                                if($null -eq $stashTagID_availability_archived) {
                                    Set-StashMetaTagID -thisStashTagName $stashTagName_availability_archived
                                    $stashTagID_availability_archived = Get-StashMetaTagID -stashTagName $stashTagName_availability_archived
                                }
                                $tagIDsToAdd += $stashTagID_availability_archived
                            }

                            # Once we have all the appropriate tags, update the Stash database
                            if($tagIDsToAdd.count -gt 0) {
                                if($mediatype -eq "video") {
                                    $updateType = "sceneUpdate"
                                    $updateTypeCapped = "SceneUpdate"
                                } elseif($mediatype -eq "image") {
                                    $updateType = "imageUpdate"
                                    $updateTypeCapped = "ImageUpdate"
                                }
                                $StashGQL_SceneTagsQuery = 'mutation '+$updateTypeCapped+'($'+$updateType+'Input: '+$updateTypeCapped+'Input!){
                                    '+$updateType+'(input: $'+$updateType+'Input){
                                        id
                                        tags {
                                            id
                                        }
                                    }
                                }'
                                $StashGQL_SceneTagsQueryVariables = ' {
                                    "'+$updateType+'Input": {
                                        "id": "'+$CurrentFileID+'",
                                        "tag_ids": ['+($tagIDsToAdd -join ",")+']
                                    }
                                }'
                                try{
                                    Invoke-GraphQLQuery -Query $StashGQL_SceneTagsQuery -Uri $StashGQL_URL -Variables $StashGQL_SceneTagsQueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }}) | out-null
                                }
                                catch{
                                    write-host "(7) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
                                    write-host "Additional Error Info: `n`n$StashGQL_SceneTagsQuery `n$StashGQL_SceneTagsQueryVariables"
                                    read-host "Press [Enter] to exit"
                                    exit
                                }
                            }

                            # ------------------------- Create or add to gallery ------------------------- #

                            # Check if a gallery has already been created
                            $StashGQL_Query = 'query FindPostGallery($filter: FindFilterType, $gallery_filter: GalleryFilterType) {
                                findGalleries(filter: $filter, gallery_filter: $gallery_filter) {
                                    galleries { id }
                                }
                            }'
                            $StashGQL_QueryVariables = '{
                                "filter": {
                                  "q": ""
                                },
                                "gallery_filter": {
                                  "code": {
                                    "value": "'+$postID+'",
                                    "modifier": "EQUALS"
                                  }
                                }
                              }'
                            try{
                                $StashGQL_Result = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
                            }
                            catch{
                                write-host "(1) Error: There was an issue with the GraphQL query." -ForegroundColor red
                                write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
                                read-host "Press [Enter] to exit"
                                exit
                            }
                            $postGalleryID = $StashGQL_Result.data.findGalleries.galleries[0].id

                            # If no gallery exists, create one
                            if($null -eq $postGalleryID) {
                                # Check for affiliated scenes that have already been created
                                $StashGQL_Query = 'query FindPostScenes($filter: FindFilterType, $scene_filter: SceneFilterType) {
                                    findScenes(filter: $filter, scene_filter: $scene_filter) {
                                        scenes { id }
                                    }
                                }'
                                $StashGQL_QueryVariables = '{
                                    "filter": {
                                      "q": ""
                                    },
                                    "scene_filter": {
                                      "title": {
                                        "value": "\"| '+$postID+'\"",
                                        "modifier": "INCLUDES"
                                      }
                                    }
                                  }'
                                try{
                                    $StashGQL_Result = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
                                }
                                catch{
                                    write-host "(1) Error: There was an issue with the GraphQL query." -ForegroundColor red
                                    write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
                                    read-host "Press [Enter] to exit"
                                    exit
                                }

                                $postGalleryTitle = "$performername | $postID"
                                $postGalleryScenes = $StashGQL_Result.data.findScenes.scenes.id
                                $StashGQL_Query = 'mutation PostGalleryCreate($input: GalleryCreateInput!) {
                                    galleryCreate(input: $input) {
                                        code
                                        date
                                        details
                                        performers { id }
                                        scenes { id }
                                        studio { id }
                                        tags { id }
                                        title
                                        urls
                                    }
                                }'
                                $StashGQL_QueryVariables = '{
                                    "input": {
                                        "code": "'+$postID+'",
                                        "date": "'+$creationdatefromOF+'",
                                        "details": "'+$detailsToAddToStash+'",
                                        "performer_ids": ['+$PerformerID+'],
                                        "scene_ids": ['+($postGalleryScenes -join ",")+'],
                                        "studio_id": "'+$OnlyFansStudioID+'",
                                        "tag_ids": ['+($tagIDsToAdd -join ",")+'],
                                        "title": "'+$postGalleryTitle+'",
                                        "urls": "'+$linktoOFpost+'",
                                    }    
                                }'
                                try{
                                    Invoke-GraphQLQuery -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }}) -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -escapehandling EscapeNonAscii | out-null
                                }
                                catch{
                                    write-host "(8) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
                                    write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
                                    read-host "Press [Enter] to exit" 
                                    exit
                                }
                                $StashGQL_Query = 'query FindPostGallery($filter: FindFilterType, $gallery_filter: GalleryFilterType) {
                                    findGalleries(filter: $filter, gallery_filter: $gallery_filter) {
                                        galleries { id }
                                    }
                                }'
                                $StashGQL_QueryVariables = '{
                                    "filter": {
                                      "q": ""
                                    },
                                    "gallery_filter": {
                                      "code": {
                                        "value": "'+$postID+'",
                                        "modifier": "EQUALS"
                                      }
                                    }
                                  }'
                                try{
                                    $StashGQL_Result = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
                                }
                                catch{
                                    write-host "(1) Error: There was an issue with the GraphQL query." -ForegroundColor red
                                    write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
                                    read-host "Press [Enter] to exit"
                                    exit
                                }
                                $postGalleryID = $StashGQL_Result.data.findGalleries.galleries[0].id    
                            }
    
                            #If it's necessary, update the image by modifying the title and adding details
                            if($CurrentFileTitle -ne $proposedtitle -or $ignorehistory -eq $true){
                                if ($boolSetImageDetails -eq $true){
                                    $StashGQL_Query = 'mutation imageUpdate($imageUpdateInput: ImageUpdateInput!){
                                        imageUpdate(input: $imageUpdateInput){
                                          code
                                          date
                                          details
                                          id
                                          studio { id }
                                          title
                                          urls
                                        }
                                      }'  
    
                                    $StashGQL_QueryVariables = '{
                                        "imageUpdateInput": {
                                            "code": "'+$mediaID+'",
                                            "date": "'+$creationdatefromOF+'",
                                            "details": "'+$detailsToAddToStash+'",
                                            "gallery_ids": ["'+$postGalleryID+'"],
                                            "id": "'+$CurrentFileID+'",
                                            "studio_id": "'+$OnlyFansStudioID+'",
                                            "title": "'+$proposedtitle+'",
                                            "urls": "'+$linktoOFpost+'",
                                        }
                                    }'
                                }
                                else{
                                    $StashGQL_Query = 'mutation imageUpdate($imageUpdateInput: ImageUpdateInput!){
                                        imageUpdate(input: $imageUpdateInput){
                                          code
                                          date
                                          id
                                          studio { id }
                                          title
                                          urls
                                        }
                                      }'  
    
                                    $StashGQL_QueryVariables = '{
                                        "imageUpdateInput": {
                                            "code": "'+$mediaID+'",
                                            "date": "'+$creationdatefromOF+'",
                                            "gallery_ids": ["'+$postGalleryID+'"],
                                            "id": "'+$CurrentFileID+'",
                                            "studio_id": "'+$OnlyFansStudioID+'",
                                            "title": "'+$proposedtitle+'",
                                            "urls": "'+$linktoOFpost+'",
                                        }
                                    }'
                                }
                                
                                try{
                                    Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Variables $StashGQL_QueryVariables -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }}) | out-null
                                }
                                catch{
                                    write-host "(8) Error: There was an issue with the GraphQL query/mutation." -ForegroundColor red
                                    write-host "Additional Error Info: `n`n$StashGQL_Query `n$StashGQL_QueryVariables"
                                    read-host "Press [Enter] to exit"
                                    exit
                                }
    
                                $filewasmodified = $true
                            }
    
                            #Provide user feedback on what has occured and add to the "file modified" counter for stats later
                            if ($filewasmodified){
                                if ($v){
                                    write-output "- Added metadata to Stash's database for the following file:`n   $OFDBFullFilePath" 
                                }
                                $numModified++  
                            }
                            else{
                                if ($v){
                                    write-output "- This file already has metadata, moving on...`n   $OFDBFullFilePath"
                                }
                                $numUnmodified++
                            }
                        } 
                    }
                }
            }
        }
    }

    ## Finished scan, let's let the user know what the results were
    
    if ($nummissingfiles -gt 0){
        write-host "`n- Missing Files -" -ForegroundColor Cyan
        write-output "There is available metadata for $nummissingfiles files in your OnlyFans Database that cannot be found in your Stash Database."
        write-output "    - Be sure to review the MissingFiles log."
        write-output "    - There's a good chance you may need to rescan your OnlyFans folder in Stash and/or redownload those files"
    }

    write-host "`n****** Import Complete ******"-ForegroundColor Cyan
    write-output "- Modified Scenes/Images: $numModified`n- Scenes/Images that already had metadata: $numUnmodified" 
    #Some quick date arithmetic to calculate elapsed time
    $scriptEndTime = Get-Date
    $scriptduration = ($scriptEndTime-$scriptStartTime).totalseconds
    if($scriptduration -ge 60){
        [int]$Minutes = $scriptduration / 60
        [int]$seconds = $scriptduration % 60
        if ($minutes -gt 1){
            write-output "- This script took $minutes minutes and $seconds seconds to execute"
        }
        else{
            write-output "- This script took $minutes minute and $seconds seconds to execute"
        }
    }
    else{
        write-output "- This script took $scriptduration seconds to execute"
    }
} #End Add-MetadataUsingOFDB 

function Add-MetadataWithoutOFDB{
    write-host "`n Dev here-- I haven't finished re-writing this feature yet. Sorry! - JuiceBox"
    read-host "Press [Enter] to exit"
}


#Main Script

#This script should be OS agnostic-- because Windows likes to be special, let's determine which delimeter is appropriate for file paths.
if($IsWindows){
    $directorydelimiter = '\'
}
else{
    $directorydelimiter = '/'
}

$pathtoconfigfile = "."+$directorydelimiter+"OFMetadataToStash_Config"

#If there's no configuration file, send the user to create one
if (!(Test-path $PathToConfigFile)){
    Set-Config
}
$ConfigFileVersion = (Get-Content $pathtoconfigfile)[0]
if ($ConfigFileVersion -ne "#### OFMetadataToStash Config File v1 ####"){
    Set-Config
}

## Global Variables ##
$StashGQL_URL = (Get-Content $pathtoconfigfile)[3]
$PathToOnlyFansContent = (Get-Content $pathtoconfigfile)[5]
$SearchSpecificity = (Get-Content $pathtoconfigfile)[7]
$StashAPIKey = (Get-Content $pathtoconfigfile)[9]

$PathToMissingFilesLog = "."+$directorydelimiter+"OFMetadataToStash_MissingFiles.txt"
$pathToSanitizerScript = "."+$directorydelimiter+"Utilities"+$directorydelimiter+"OFMetadataDatabase_Sanitizer.ps1"


#Before we continue, let's make sure everything in the configuration file is good to go
#This query also serves a second purpose-- as of Stash v0.24, images will support details. We'll check for that and add details if possible.
$StashGQL_Query = 'query version{version{version}}'
try{
    $StashGQL_Result = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $StashGQL_URL -Headers $(if ($StashAPIKey){ @{ApiKey = "$StashAPIKey" }})
}
catch{
    write-host "Hmm...Could not communicate to Stash using the URL in the config file ($StashGQL_URL)"
    write-host "Are you sure Stash is running?"
    read-host "If Stash is running like normal, press [Enter] to recreate the configuration file for this script"
    Set-Config
}

$boolSetImageDetails = $StashGQL_Result.data.version.version.split(".")
if(($boolSetImageDetails[0] -eq "v0") -and ($boolSetImageDetails[1] -lt 24)){ #checking for 'v0' as I assume stash will go to version 1 at some point.
    $boolSetImageDetails = $false
}
else {
    $boolSetImageDetails = $true
}

if (!(test-path $PathToOnlyFansContent)){
    #Couldn't find the path? Send the user to recreate their config file with the set-config function
    read-host "Hmm...The defined path to your OnlyFans content does not seem to exist at the location specified in your config file.`n($PathToOnlyFansContent)`n`nPress [Enter] to run through the config wizard"
    Set-Config
}

if(($SearchSpecificity -notmatch '\blow\b|\bnormal\b|\bhigh\b')){
    #Something goofy with the variable? Send the user to recreate their config file with the set-config function
    read-host "Hmm...The Metadata Match Mode parameter isn't well defined in your configuration file. No worries!`n`nPress [Enter] to run through the config wizard"
    Set-Config
}
else {
    clear-host
    write-host "- OnlyFans Metadata DB to Stash PoSH Script 0.9 - `n(https://github.com/ALonelyJuicebox/OFMetadataToStash)`n" -ForegroundColor cyan
    write-output "By JuiceBox`n`n----------------------------------------------------`n"
    write-output "* Path to OnlyFans Media:     $PathToOnlyFansContent"
    write-output "* Metadata Match Mode:        $searchspecificity"
    write-output "* Stash URL:                  $StashGQL_URL`n"
    if($v){
        write-host "Special Mode Enabled: Verbose Output"
    }
    if($ignorehistory){
        write-host "Special Mode Enabled: Ignore History File"
    }
    if($randomavatar){
        write-host "Special Mode Enabled: Random Avatar "
    }
    write-output "----------------------------------------------------`n"
    write-output "What would you like to do?"
    write-output " 1 - Add Metadata to my Stash using OnlyFans Metadata Database(s)"
    write-output " 2 - Add Metadata to my Stash without using OnlyFans Metadata Database(s)"
    write-output " 3 - Generate a redacted, sanitized copy of my OnlyFans Metadata Database file(s)"
    write-output " 4 - Change Settings"
}

$userscanselection = 0;
do {
    $userscanselection = read-host "`nEnter selection"
}
while (($userscanselection -notmatch "[1-4]"))

switch ($userscanselection){
    1 {Add-MetadataUsingOFDB}
    2 {Add-MetadataWithoutOFDB}
    3 {invoke-expression $pathtosanitizerscript}
    4 {Set-Config}
}
