Function Split-Array {
    <#
    Splits an array into smaller arrays.
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true,
            Position = 1)]
        [ValidateNotNullOrEmpty()]
        $InputObject,

        [parameter(Mandatory = $true,
            Position = 2)]
        [ValidateNotNullOrEmpty()]
        [int]$NewArraySize
    )
    #https://powershell.org/forums/topic/splitting-an-array-in-smaller-arrays/

    #How many parts the array will be split into
    [int]$parts = [Math]::Round([Math]::Ceiling($InputObject.count / 10))

    [int]$ArrayStartPosition = 0
    [int]$ArrayEndPosition = $NewArraySize - 1

    for ( $i = 0; $i -lt $parts; $i++) {

        # the , stores the result in an array
        , $InputObject[$ArrayStartPosition..$ArrayEndPosition]

        $ArrayStartPosition += $NewArraySize
        $ArrayEndPosition += $NewArraySize

    }
}
