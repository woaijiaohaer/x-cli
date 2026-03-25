#!/bin/bash

xc_service_render_systemd_unit() {
    local service_name=$1
    local binary_path=$2
    local config_path=$3

    cat <<EOF
[Unit]
Description=Xray Service
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=${binary_path} run -c ${config_path}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF
}

xc_service_write_systemd_unit() {
    local output_path=$1
    local service_name=$2
    local binary_path=$3
    local config_path=$4

    local tmp_path
    tmp_path="${output_path}.tmp"
    xc_service_render_systemd_unit "${service_name}" "${binary_path}" "${config_path}" > "${tmp_path}"
    mv "${tmp_path}" "${output_path}"
}
