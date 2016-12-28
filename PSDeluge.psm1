function GetFiles{
    [CmdletBinding()]
    Param(
        [Parameter(
            ValueFromPipeline=$true,
            Mandatory=$true            
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
            [PSObject]$sizeResult=[Regex]::Match($line,$sizeRegex)
            [string]$sizeStr=$sizeResult.Value
            [double]$size=Invoke-Expression `
              -Command $sizeStr.Replace('i','').Replace(' ','')
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

function Get-DelugeTasks {
    [CmdletBinding(DefaultParameterSetName='Name')]
    Param(
        [Parameter(
            Position=0,
            ValueFromPipelineByPropertyName=$true,
            ParameterSetName='Name'
        )]
        [String]$name,

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
            [Collections.ArrayList]$list=deluge info $name -v
            foreach($line in $list){
                
            }
        }Catch{
            $e=$_
            Write-Error $e
        }
    }
    End{}
}

Get-DelugeTasks -name 'Sully  2016 720p BrRip x264 - 2HD'