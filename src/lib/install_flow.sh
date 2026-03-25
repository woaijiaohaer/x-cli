#!/bin/bash

xc_install_write_protocol_config() {
    local output_path=$1
    local requested_protocol=$2
    local api_port=$3
    local port=$4
    local uuid=$5
    local domain=$6
    local private_key=$7
    local public_key=$8
    local short_ids_json=$9

    local protocol
    if ! protocol=$(xc_protocol_resolve "${requested_protocol}"); then
        return 1
    fi

    xc_xray_write_config \
      "${output_path}" \
      "${protocol}" \
      "${api_port}" \
      "${port}" \
      "${uuid}" \
      "${domain}" \
      "${private_key}" \
      "${public_key}" \
      "${short_ids_json}"
}
