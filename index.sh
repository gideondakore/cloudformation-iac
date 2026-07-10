#!/bin/bash
set -euxo pipefail
dnf update -y

dnf install -y httpd stress-ng
systemctl enable --now httpd

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/instance-id)
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/local-ipv4)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/placement/availability-zone)

cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Auto Scaling Lab</title>
    <style>
    body { font-family: sans-serif; background: #0f172a; color: #e2e8f0;
            display: flex; align-items: center; justify-content: center;
            height: 100vh; margin: 0; }
    .card { background: #1e293b; padding: 2.5rem 3rem; border-radius: 12px;
            text-align: center; box-shadow: 0 10px 30px rgba(0,0,0,.4); }
    h1 { margin-top: 0; }
    .id { color: #38bdf8; font-size: 1.4rem; font-weight: bold; }
    </style>
</head>
<body>
    <div class="card">
    <h1>Auto Scaling Lab</h1>
    <p>Served by instance:</p>
    <p class="id">${INSTANCE_ID}</p>
    <p>Private IP: ${PRIVATE_IP}</p>
    <p>Availability Zone: ${AZ}</p>
    </div>
</body>
</html>
EOF


chown apache:apache /var/www/html/index.html
chmod 644 /var/www/html/index.html
chmod 755 /var/www/html
systemctl restart httpd