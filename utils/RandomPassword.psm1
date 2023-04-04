
function randomPassword {

    # 0..255 | Foreach-Object {"$_ : $([char]$_)"}
    $charlist = [char]97..[char]122 + [char]65..[char]90 + [char]47..[char]57
    # All uppercase and lowercase letters, all numbers and some special characters. 
   
    # Built in parameters from a native PowerShell cmdlet.
    $pwLength = (1..10 | Get-Random) + 24 

    #Create a new empty array to store the list of random characters 
    $pwdList = @()
    
    # Use a FOR loop to pick a character from the list one time for each count of the password length
    For ($i = 0; $i -lt $pwlength; $i++) {
    $pwdList += $charList | Get-Random
    }
    
    # Join all the individual characters together into one string using the -JOIN operator
    $pass = -join $pwdList
    return $pass
}
 
$myPassword = randomPassword
$myPassword
