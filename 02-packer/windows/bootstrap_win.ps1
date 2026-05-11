#ps1_sysnative

# OCI Windows images ship with WinRM pre-enabled on port 5986 for the opc user.
# This script only needs to activate the account and set a known password.
net user opc "${password}" /logonpasswordchg:no /active:yes
