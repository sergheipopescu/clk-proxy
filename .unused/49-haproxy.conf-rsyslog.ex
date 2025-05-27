# Send messages from haproxy to a seperate files and
# prevent them from being written to any other logfile

if $programname == 'haproxy' and $msg contains "~ backendName1/" then /var/log/haproxy/backendName1
& stop

if $programname == 'haproxy' and $msg contains " backendName2/" then /var/log/haproxy/backendName2
& stop