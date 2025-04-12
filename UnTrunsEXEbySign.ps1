Get-AuthenticodeSignature -FilePath $args[0] | ForEach-Object { $_.SignerCertificate } | Export-Certificate -FilePath "dis.cer" 
certutil -addstore -f "Disallowed" "dis.cer"
#del "dis.cer"

