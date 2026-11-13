if status is-interactive
    # Commands to run in interactive sessions can go here
end

# SJTU student VPN (existing swanctl configuration).
function sjtu_vpn_on --description 'Connect to SJTU student VPN'
    # Avoid waiting behind the known bypass-lan shutdown deadlock.
    if test (systemctl show strongswan.service --property=ActiveState --value) = deactivating
        echo "strongSwan is still stopping; retry after it has stopped (currently up to 90 seconds)." >&2
        return 1
    end

    sudo systemctl start strongswan.service; or return $status
    sudo swanctl --initiate --child vpn-student; or return $status
    echo "SJTU VPN ON"
end

function sjtu_vpn_off --description 'Disconnect from SJTU student VPN'
    sudo swanctl --terminate --ike vpn-student; or return $status
    # Queue the stop without blocking the shell; the daemon may take 90s to exit.
    sudo systemctl stop --no-block strongswan.service; or return $status
    echo "SJTU VPN OFF (strongSwan service is stopping in the background)"
end

# Environment variable required by pi-web-ui to use the current openai package
# set -gx PI_WEB_SDK bundled
