<# 
Zabbix Agent PowerShell script for Hyper-V monitoring 

Copyright (c) 2015,2016 Dmitry Sarkisov <ait.meijin@gmail.com>
Changed for support russian counters by Rustavy Zhigulin <zro@mail.ru>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>

param(
	[Parameter(Mandatory=$False)]
	[string]$QueryName,
	[string]$VMName,
	[string]$VMObject
)

Clear-Variable hostname,From,To,encFrom,encTo,bytes,colItems,n,ItemType,Results,objItem -ErrorAction SilentlyContinue

$hostname = Get-WmiObject win32_computersystem | Select-Object -ExpandProperty name

$VMName = $VMName.Replace("_" + $hostname, '')

function ConvertTo-Encoding ([string]$From, [string]$To)
{
    Begin
    {
        $encFrom = [System.Text.Encoding]::GetEncoding($from)
        $encTo = [System.Text.Encoding]::GetEncoding($to)
    }
    Process
    {
        $bytes = $encTo.GetBytes($_)
        $bytes = [System.Text.Encoding]::Convert($encFrom, $encTo, $bytes)
        $encTo.GetString($bytes)
    }
}

<# Zabbix Hyper-V Virtual Machine Discovery #>
if ($QueryName -eq '') {
    
	
    $colItems = Get-VM

    write-host "{"
    write-host " `"data`":["
    write-host
	
    $n = $colItems.Count

    foreach ($objItem in $colItems) {
        $line =  ' { "{#VMNAME}":"' + $objItem.Name + '" ,"{#VMSTATE}":"' + $objItem.State  + '", "{#VMHOST}":"' + $hostname + '" }'
        if ($n -gt 1){
            $line += ","
        }
        write-host $line
        $n--
    }

    write-host " ]"
    write-host "}"
    write-host
    exit
}



<# Zabbix Hyper-V VM Perf Counter Discovery #>
if ($psboundparameters.Count -eq 2) {
    Clear-Variable ItemType,Results,line -ErrorAction SilentlyContinue

    switch ($QueryName)
        {
        
        ('GetVMDisks'){
            $ItemType = "VMDISK"
            $Results =  (Get-Counter -Counter '\Hyper-V Virtual Storage Device(*)\Read Bytes/sec').CounterSamples  | Where-Object  {$_.InstanceName -like '*-'+$VMName+'*'} | select InstanceName
        }

        ('GetVMNICs'){
            $ItemType = "VMNIC"
            $Results = (Get-Counter -Counter '\Виртуальный сетевой адаптер Hyper-V(*)\Отправлено пакетов/сек').CounterSamples | Where-Object  {$_.InstanceName -like $VMName+'_*'} | select InstanceName
        }

        ('GetVMCPUs'){
             $ItemType  ="VMCPU"
             $Results = (Get-Counter -Counter '\Виртуальный процессор низкоуровневой оболочки Hyper-V(*)\% общего времени работы').CounterSamples | Where-Object {$_.InstanceName -like $VMName+':*'} | select InstanceName
        }
            
        default {$Results = "Bad Request"; exit}
        }

    write-host "{"
    write-host " `"data`":["
    write-host      
               
       
    $n = ($Results | measure).Count

            foreach ($objItem in $Results) {
                $objItem = $objItem.InstanceName.Replace("_сетевой", "_Сетевой")
                $objItem = $objItem.InstanceName.Replace("_устаревший", "_Устаревший")
                $line = " { `"{#"+$ItemType+"}`":`""+@($objItem.InstanceName | ConvertTo-Encoding cp866 utf-8)+"`"}"
                 
                if ($n -gt 1 ){
                    $line += ","
                }

                write-host $line
                $n--
            }
    
    write-host " ]"
    write-host "}"
    write-host


    exit
}


<# Zabbix Hyper-V VM Get Performance Counter Value #>
if ($psboundparameters.Count -eq 3) {
    Clear-Variable ItemType,Results,VVMObject -ErrorAction SilentlyContinue

    switch ($QueryName){
            <# Disk Counters #>
            ('VMDISKBytesRead'){
                    $ItemType = $QueryName
                    $Results =  (Get-Counter -Counter "\Hyper-V Virtual Storage Device($VMObject)\Read Bytes/sec").CounterSamples

            }
            ('VMDISKBytesWrite'){
                    $ItemType = $QueryName
                    $Results =  (Get-Counter -Counter "\Hyper-V Virtual Storage Device($VMObject)\Write Bytes/sec").CounterSamples
            }
            ('VMDISKOpsRead'){
                    $ItemType = $QueryName
                    $Results =  (Get-Counter -Counter "\Hyper-V Virtual Storage Device($VMObject)\Read Operations/sec").CounterSamples

            }
            ('VMDISKOpsWrite'){
                    $ItemType = $QueryName
                    $Results =  (Get-Counter -Counter "\Hyper-V Virtual Storage Device($VMObject)\Write Operations/sec").CounterSamples

            }

            <# Network Counters #>
            ('VMNICSent'){
                    $ItemType = $QueryName
                    $Results = (Get-Counter -Counter "\Виртуальный сетевой адаптер Hyper-V($VMObject)\Отправлено байт/сек").CounterSamples
            }
            ('VMNICRecv'){
                    $ItemType = $QueryName
                    $Results = (Get-Counter -Counter "\Виртуальный сетевой адаптер Hyper-V($VMObject)\Получено байт/сек").CounterSamples
            }


            <# Virtual CPU Counters #>
            ('VMCPUTotal'){
                $ItemType = $QueryName
                $Results = (Get-Counter -Counter "\Виртуальный процессор низкоуровневой оболочки Hyper-V($VMObject)\% времени работы низкоуровневой оболочки").CounterSamples
            }



            default {$Results = "Bad Request"; exit}
    }

    
            foreach ($objItem in $Results) {
                $line = [int]$objItem.CookedValue
                write-host $line
            }

    exit
}
