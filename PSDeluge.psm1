Set-StrictMode -Version 1

###### HELPER FUNCTIONS ######
       # not exported #
##############################

function ConvertToDouble ([String]$sizeStr){
    [double]$size=-1
    $size=Invoke-Expression `
      -Command $sizeStr.Replace('i','').Replace(' ','') `
      -ErrorAction SilentlyContinue
    return $size
}

function GetFiles{
    [CmdletBinding()]
    Param(
        [Parameter(
            Position=0,
            ValueFromPipeline=$true         
        )]
        [Collections.ArrayList]$obj
    )
    Begin{
        [String]$pctRegex='(?<=Progress: )[0-9]{1,3}\.[0-9]{2}(?=\%)'
        [String]$sizeRegex='(?<=\()[[0-9]{1,4}\.[0-9]{1,2}\s(MiB|KiB|GiB|TiB)(?=\))'
        [String]$priorityRegex='(?<=Priority:)\s(Normal|Low|High)'
    }
    Process{
        [int]$findex=$obj.IndexOf('  ::Files')
        [int]$pindex=$obj.IndexOf('  ::Peers')
        if(($pindex - $findex) -eq 1){
            return $null
        }
        [int]$fcount=($pindex - $findex - 1)
        [Collections.ArrayList]$fileList=@()
        for ($i=$findex + 1; $i -le $findex + $fcount; $i++){
            [String]$line=$obj[$i]
            [float]$pct=[Regex]::Match($line,$pctRegex).Value
            [Text.RegularExpressions.Match]$sizeResult=[Regex]::Match(
                $line,$sizeRegex
            )
            [string]$sizeStr=$sizeResult.Value
            #[double]$size=Invoke-Expression `
            #  -Command $sizeStr.Replace('i','').Replace(' ','')
            [double]$size=ConvertToDouble -sizeStr $sizeStr
            [String]$priority=[Regex]::Match($line,$priorityRegex).Value
            $build=New-Object -TypeName Text.StringBuilder
            for($j=0;$j -lt ($sizeResult.Index -1);$j++){
                [void]$build.Append($line[$j])
            }
            [String]$fileName=$build.ToString().Trim()
            $file=New-Object -TypeName psobject -Property @{
                'FileName'=$fileName;
                'PercentComplete'=$pct;
                'Size'=$size;
                'Priority'=$priority;
            }
            [void]$fileList.Add($file)
        }
        return $fileList
    }
    End{}
}

function SplitTorrents{
    [CmdletBinding()]
    Param(
        [Collections.ArrayList]$list
    )
    $tcollection=New-Object -TypeName Collections.ArrayList
    [int]$newi=0
    [int]$reali=0
    [int]$lasti=$list.IndexOf(' ')
    [void]$tcollection.Add(@('wrk','arnd'))#if 1 torrent returned, cannot be piped to ParseTorrent command.Work around for now

    While($lasti -ne -1){
        $newi=$list[($lasti+1)..($list.count -1)].IndexOf(' ')
        if($newi -eq -1){
            [Array]$a=$list[$lasti..($list.Count-1)]
            [void]$tcollection.Add($a)
            return $tcollection
        }
        $reali=$newi+$lasti+1
        [Array]$a=$list[$lasti..($reali-1)]
        [void]$tcollection.Add($a)
        $lasti=$reali
    }
    return $null
}

function RegexGen ([String]$rowName){
    $rowName=$rowName.Replace(' ','\s')
    $build=New-Object -TypeName Text.StringBuilder
    [Void]$build.Append("(?<=^$rowName\:\s).+")
    return $build.ToString()
}

function GetRegexMatchValue {
    Param(
        [String]$l,
        
        [String]$regex
    )
    Try{
        [Text.RegularExpressions.Match]$result=[regex]::Match($l,$regex)
        return $result.Value
    }Catch{
        $e=$_
        Write-Error $e
    }
}

function ParseSize {
    [CmdletBinding()]
    Param(
        [Parameter(
            Position=0,
            ValueFromPipeline=$true
        )]
        [String]$line
    )
    Begin{
        [String]$dnRegex='\d{1,4}\.\d{1,2}\s(KiB|MiB|GiB|TiB)(?=\/)'
        [String]$sRegex='[0-9]{1,4}\.[0-9]{1,2}\s(KiB|MiB|GiB|TiB)(?=\sRatio:)'
        [String]$rRegex='(?<=Ratio:\s)[0-9]{1,10}\.[0-9]{1,4}$'
        #dnRegex Parses the downloaded size so far
        ## 1-4 digits with 1-2 decimal places, KiB, MiB,..; ends with '/'

        #sRegex Parses the total size of torrent
        ## 1-4 digits with 1-2 decimal places, KiB, MiB,..;ends with ' Ratio:'

        #rRegex Parses the ratio (upload/download)
        ## Starts with 'Ratio: '; 1-10 digits with 1-4 decimals; end of string
    }
    Process{
        [double]$ratio=GetRegexMatchValue -l $line -regex $rRegex
        [String]$downstr=GetRegexMatchValue -l $line -regex $dnRegex
        [double]$down=ConvertToDouble -sizeStr $downstr

        [String]$sizestr=GetRegexMatchValue -l $line -regex $sRegex
        [double]$size=ConvertToDouble -sizeStr $sizestr

        New-Object -TypeName psobject -Property @{
            Downloaded=$down;
            Size=$size;
            Ratio=$ratio;
        }
    }
    End{}   
}

function ParseProgress{ #I could calculate it but the work's already done
    [CmdletBinding()]
    Param(
        [String]$progressStr
    )
    return [float]$progressStr.Split('\%')[0]
}

function ParseTorrent {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline=$true)]
        [Array]$list
    )
    Begin{
        [String]$nRegex=RegexGen -rowName 'Name'
        [String]$iRegex=RegexGen -rowName 'ID'
        [String]$stateRegex=RegexGen -rowName 'State'
        [String]$sizeRegex=RegexGen -rowName 'Size'
        [String]$seedRegex=RegexGen -rowName 'Seed time'
        [String]$trackRegex=RegexGen -rowName 'Tracker status'
        [String]$prRegex=RegexGen -rowName 'Progress'
    }
    Process{
        [String]$n=''
        [String]$id=''
        [String]$st=''
        [String]$si=''
        [String]$st=''
        [String]$tr=''
        [String]$pr=''
        foreach($l in $list){
            switch -Regex ($l){
                $nRegex {
                    $n=GetRegexMatchValue -l $l -regex $nRegex
                }
                $iRegex {
                    $id=GetRegexMatchValue -l $l -regex $iRegex
                }
                $stateRegex {
                    $st=GetRegexMatchValue -l $l -regex $stateRegex
                }
                $sizeRegex {
                    $si=GetRegexMatchValue -l $l -regex $sizeRegex
                }
                $seedRegex {
                    $se=GetRegexMatchValue -l $l -regex $seedRegex
                }
                $trackRegex {
                    $tr=GetRegexMatchValue -l $l -regex $trackRegex
                }
                $prRegex {
                    $pr=GetRegexMatchValue -l $l -regex $prRegex
                }
                default {
                    continue
                }
            }
        }
        [PSObject]$sizeStats=ParseSize -line $si
        $pr=ParseProgress -progressStr $pr -ErrorAction SilentlyContinue
        $obj=New-Object -TypeName psobject -Property @{
            Name=$n;
            Id=$id;
            State=$st;
            Size=$sizeStats.Size;
            Downloaded=$sizeStats.Downloaded;
            Ratio=$sizeStats.Ratio;
            SeedStats=$se;
            Tracker=$tr;
            Progress=$pr;
            Files=GetFiles $list;
        }
        $obj.psobject.typenames.insert(0,'Brian.PSDeluge.Torrent')
        write-output $obj
    }
    End{}
}

#################################
##### END HELPER FUNCTIONS ######
#################################

function Get-DelugeTorrent {
    [CmdletBinding(DefaultParameterSetName='Name')]
    Param(
        [Parameter(
            Position=0,
            ValueFromPipelineByPropertyName=$true,
            ParameterSetName='Name'
        )]
        [AllowNull()]
        [String]$name=$null,

        [Parameter(
            Position=0,
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            ParameterSetName='Id'
        )]
        [String]$id
    )
    Begin{

    }
    Process{
        Try{
            [Collections.ArrayList]$list=@()
            [String]$torId=$PSBoundParameters.Values
            Write-Debug -Message "ID: $torId"
            if($PSCmdlet.ParameterSetName -eq 'Name' -and $name -like $null){
                Write-Debug -Message 'Name ->  $null'
                $list=deluge info -v
            }else{
                $list=deluge info $torId -v
            }
            [Collections.ArrayList]$splitList=SplitTorrents -list $list
            $splitList[1..($splitList.Count-1)] | ParseTorrent
        }Catch{
            $e=$_
            Write-Error $e
        }
    }
    End{}
}