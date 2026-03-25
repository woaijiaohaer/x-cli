#!/bin/bash

xc_xray_build_inbound_vless() {
    local port=$1
    local uuid=$2
    local domain=$3
    local private_key=$4
    local public_key=$5
    local short_ids_json=$6

    jq -n \
      --argjson port "${port}" \
      --arg uuid "${uuid}" \
      --arg domain "${domain}" \
      --arg private_key "${private_key}" \
      --arg public_key "${public_key}" \
      --argjson short_ids "${short_ids_json}" \
      '{
        port: $port,
        protocol: "vless",
        settings: {
          clients: [{id: $uuid, flow: "xtls-rprx-vision", level: 0}],
          decryption: "none"
        },
        streamSettings: {
          network: "tcp",
          security: "reality",
          realitySettings: {
            show: false,
            dest: ($domain + ":443"),
            serverNames: [$domain],
            privateKey: $private_key,
            publicKey: $public_key,
            shortIds: $short_ids
          }
        },
        sniffing: {enabled: true, destOverride: ["http", "tls"]}
      }'
}

xc_xray_build_inbound_vmess() {
    local port=$1
    local uuid=$2

    jq -n \
      --argjson port "${port}" \
      --arg uuid "${uuid}" \
      '{
        port: $port,
        protocol: "vmess",
        settings: {
          clients: [{id: $uuid, alterId: 0}],
          disableInsecureEncryption: true
        },
        streamSettings: {network: "tcp", security: "none"},
        sniffing: {enabled: true, destOverride: ["http", "tls"]}
      }'
}

xc_xray_build_inbound_trojan() {
    local port=$1
    local uuid=$2
    local domain=$3
    local private_key=$4
    local public_key=$5
    local short_ids_json=$6

    jq -n \
      --argjson port "${port}" \
      --arg password "${uuid}" \
      --arg domain "${domain}" \
      --arg private_key "${private_key}" \
      --arg public_key "${public_key}" \
      --argjson short_ids "${short_ids_json}" \
      '{
        port: $port,
        protocol: "trojan",
        settings: {
          clients: [{password: $password, level: 0}]
        },
        streamSettings: {
          network: "tcp",
          security: "reality",
          realitySettings: {
            show: false,
            dest: ($domain + ":443"),
            serverNames: [$domain],
            privateKey: $private_key,
            publicKey: $public_key,
            shortIds: $short_ids
          }
        },
        sniffing: {enabled: true, destOverride: ["http", "tls"]}
      }'
}

xc_xray_build_inbound() {
    local protocol=$1
    local port=$2
    local uuid=$3
    local domain=$4
    local private_key=$5
    local public_key=$6
    local short_ids_json=$7

    case "${protocol}" in
        vless)
            xc_xray_build_inbound_vless "${port}" "${uuid}" "${domain}" "${private_key}" "${public_key}" "${short_ids_json}"
            ;;
        vmess)
            xc_xray_build_inbound_vmess "${port}" "${uuid}"
            ;;
        trojan)
            xc_xray_build_inbound_trojan "${port}" "${uuid}" "${domain}" "${private_key}" "${public_key}" "${short_ids_json}"
            ;;
        *)
            log_error "Unsupported protocol: ${protocol}"
            return 1
            ;;
    esac
}

xc_xray_build_full_config() {
    local protocol=$1
    local api_port=$2
    local port=$3
    local uuid=$4
    local domain=$5
    local private_key=$6
    local public_key=$7
    local short_ids_json=$8

    local inbound
    if ! inbound=$(xc_xray_build_inbound \
      "${protocol}" \
      "${port}" \
      "${uuid}" \
      "${domain}" \
      "${private_key}" \
      "${public_key}" \
      "${short_ids_json}"); then
        return 1
    fi

    jq -n \
      --argjson api_port "${api_port}" \
      --argjson inbound "${inbound}" \
      '{
        log: {loglevel: "warning"},
        inbounds: [
          {
            listen: "127.0.0.1",
            port: $api_port,
            protocol: "dokodemo-door",
            settings: {address: "127.0.0.1"},
            tag: "api"
          },
          $inbound
        ],
        outbounds: [
          {protocol: "freedom", tag: "direct"},
          {protocol: "blackhole", tag: "blocked"}
        ]
      }'
}

xc_xray_write_config() {
    local output_path=$1
    local protocol=$2
    local api_port=$3
    local port=$4
    local uuid=$5
    local domain=$6
    local private_key=$7
    local public_key=$8
    local short_ids_json=$9

    local tmp_path
    tmp_path="${output_path}.tmp"

    if ! xc_xray_build_full_config \
      "${protocol}" \
      "${api_port}" \
      "${port}" \
      "${uuid}" \
      "${domain}" \
      "${private_key}" \
      "${public_key}" \
      "${short_ids_json}" > "${tmp_path}"; then
        rm -f "${tmp_path}"
        return 1
    fi

    mv "${tmp_path}" "${output_path}"
}
