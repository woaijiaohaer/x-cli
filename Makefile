SHELL := /bin/bash

.PHONY: build lint test

build:
	bash hack/build.sh

lint:
	shellcheck x-cli.sh src/**/*.sh hack/*.sh

test:
	bash tests/unit/test_log_platform.sh
	bash tests/unit/test_config.sh
	bash tests/unit/test_protocols.sh
	bash tests/unit/test_protocol_selection.sh
	bash tests/unit/test_xray_config_protocols.sh
	bash tests/unit/test_xray_full_config.sh
	bash tests/unit/test_xray_config_write.sh
	bash tests/unit/test_service_manager.sh
	bash tests/unit/test_service_systemd.sh
	bash tests/unit/test_install_flow.sh
	bash tests/unit/test_entrypoint_gen_config.sh
	bash hack/test.sh
	bash tests/compatibility/compare_baseline.sh
