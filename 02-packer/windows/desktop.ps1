try {
    # Remove OCI console agent shortcut — end users don't need it on the desktop
    Remove-Item -Path "C:\Users\Administrator\Desktop\OCI*.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Users\Public\Desktop\OCI*.lnk" -Force -ErrorAction SilentlyContinue

    Write-Host "Desktop configuration complete."
}
catch {
    Write-Error "An error occurred configuring desktop icons."
    exit 1
}
