BASE_DIR         = $(shell pwd)
export TAGS     ?= rel
PACKAGE_VERSION ?= 0.2.0
BUILD_DIR       ?= $(BASE_DIR)/_build
export PROJECT_BASE    ?= riak-mesos
export DEPLOY_BASE     ?= riak-tools/$(PROJECT_BASE)
export DEPLOY_OS       ?= coreos
export OS_ARCH		   ?= linux_amd64
# The project is actually cross platform, but this is the current repository location for all packages.

.PHONY: all clean clean_bin package clean_package sync
all: clean_bin framework director tools
rebuild_all: clean build_artifacts build_schroot framework director tools
rebuild_all_native: clean build_artifacts_native framework director tools
clean: clean_package clean_bin
package: clean_package

## Godeps begin
.godep: Godeps/Godeps.json
	godep restore
	touch .godep
## Godeps end

### Framework begin
.PHONY: framework clean_framework
# Depends on artifacts, because it depends on scheduler which depends on artifacts
.bin.framework_$(OS_ARCH):
	go build -o bin/framework_$(OS_ARCH) -tags=$(TAGS) ./framework/
	$(shell touch .bin.framework_$(OS_ARCH))
framework: .godep schroot artifacts cepm executor scheduler .bin.framework_$(OS_ARCH)
clean_bin: clean_framework
clean_framework:
	-rm -f .bin.framework_$(OS_ARCH) bin/framework_$(OS_ARCH)
### Framework end

### Scheduler begin
.PHONY: scheduler clean_scheduler
.scheduler.bindata_generated: .scheduler.data.executor_$(OS_ARCH) .process_manager.bindata_generated  scheduler/data/advanced.config scheduler/data/riak.conf
	go generate -tags=$(TAGS) ./scheduler
	$(shell touch .scheduler.bindata_generated)
scheduler: .scheduler.bindata_generated
clean_bin: clean_scheduler
clean_scheduler:
	-rm -rf .scheduler.bindata_generated scheduler/bindata_generated.go
### Scheduler end

### Executor begin
.PHONY: executor clean_executor .scheduler.data.executor_$(OS_ARCH)
executor: .scheduler.data.executor_$(OS_ARCH)
.scheduler.data.executor_$(OS_ARCH): cepm .process_manager.bindata_generated
	GOOS=linux GOARCH=amd64 go build -o scheduler/data/executor_$(OS_ARCH) -tags=$(TAGS) ./executor/
	$(shell touch .scheduler.data.executor_$(OS_ARCH))
clean_bin: clean_executor
clean_executor:
	-rm -f .executor.bindata_generated executor/bindata_generated.go
	-rm -f .scheduler.data.executor_$(OS_ARCH) scheduler/data/executor_$(OS_ARCH)
### Executor end

### Artifact begin
.PHONY: build_artifacts build_artifacts_native artifacts clean_artifacts
build_artifacts_native:
	cd artifacts/data && $(MAKE) native
	go generate -tags=$(TAGS) ./artifacts
build_artifacts:
	cd artifacts/data && $(MAKE)
	go generate -tags=$(TAGS) ./artifacts
artifacts:
	cd artifacts/data && $(MAKE) -f download.make
	go generate -tags=$(TAGS) ./artifacts
sync: sync_artifacts
sync_artifacts:
	cd artifacts/data/ && \
		s3cmd put --acl-public riak-bin.tar.gz s3://$(DEPLOY_BASE)/$(DEPLOY_OS)/artifacts/$(PACKAGE_VERSION)/ && \
		s3cmd put --acl-public riak_mesos_director-bin.tar.gz s3://$(DEPLOY_BASE)/$(DEPLOY_OS)/artifacts/$(PACKAGE_VERSION)/ && \
		s3cmd put --acl-public trusty.tar.gz s3://$(DEPLOY_BASE)/$(DEPLOY_OS)/artifacts/$(PACKAGE_VERSION)/
clean: clean_artifacts
clean_artifacts:
	cd artifacts/data && $(MAKE) clean
	-rm -rf artifacts/bindata_generated.go
### Artifact end

### Tools begin
.PHONY: tools clean_tools .bin.tools_$(OS_ARCH)
.bin.tools_$(OS_ARCH):
	go build -o bin/tools_$(OS_ARCH) -tags=$(TAGS) ./tools/
	$(shell touch .bin.tools_$(OS_ARCH))
.bin.zktool_$(OS_ARCH):
	go build -o bin/zktool_$(OS_ARCH) -tags=$(TAGS) ./tools/zk/
	$(shell touch .bin.zktool_$(OS_ARCH))
.bin.riak-mesos:
	cp tools/riak-mesos.py bin/riak-mesos
	$(shell touch .bin.riak-mesos)
tools: .bin.zktool_$(OS_ARCH) .bin.tools_$(OS_ARCH) .bin.riak-mesos
clean_bin: clean_tools
clean_tools:
	-rm -rf .bin.tools_$(OS_ARCH) bin/tools_$(OS_ARCH) .bin.zktool_$(OS_ARCH) bin/zktool_$(OS_ARCH) .bin.riak-mesos bin/riak-mesos
### Tools end

### Director begin
.PHONY: director clean_director
.director.bindata_generated: .process_manager.bindata_generated
	go generate -tags=$(TAGS) ./director
	$(shell touch .director.bindata_generated)
director: artifacts .director.bindata_generated
	GOOS=linux GOARCH=amd64 go build -o bin/director_$(OS_ARCH) -tags=$(TAGS) ./director/
clean_bin: clean_director
clean_director:
	-rm -rf .director.bindata_generated director/bindata_generated.go bin/director_$(OS_ARCH)
### Scheduler end

### Schroot begin
.PHONY: build_schroot schroot clean_schroot
build_schroot:
	cd process_manager/schroot/data && $(MAKE)
schroot:
	cd process_manager/schroot/data && $(MAKE) -f download.make
sync: sync_schroot
sync_schroot:
	cd process_manager/schroot/data/ && \
		s3cmd put --acl-public plain_chroot s3://$(DEPLOY_BASE)/$(DEPLOY_OS)/artifacts/$(PACKAGE_VERSION)/ && \
		s3cmd put --acl-public super_chroot s3://$(DEPLOY_BASE)/$(DEPLOY_OS)/artifacts/$(PACKAGE_VERSION)/
clean: clean_schroot
clean_schroot:
	cd process_manager/schroot/data && $(MAKE) clean
### Schroot end

### Process Manager begin
.PHONY: .process_manager.bindata_generated
.process_manager.bindata_generated:
	go generate -tags=$(TAGS) ./process_manager/...
	$(shell touch .process_manager.bindata_generated)
clean_bin: clean_process_manager
clean_process_manager:
	rm -rf .process_manager.bindata_generated process_manager/bindata_generated.go
### Process Manager end

### CEPMd begin
.PHONY: cepm clean_cepmd erl_dist
erl_dist:
	cd erlang_dist && $(MAKE)
.cepmd.cepm.bindata_generated: erl_dist
	go generate -tags=$(TAGS) ./cepmd/cepm
	$(shell touch .cepmd.cepm.bindata_generated)
cepm: .cepmd.cepm.bindata_generated
clean_bin: clean_cepmd
clean_cepmd:
	-rm -f .cepmd.cepm.bindata_generated cepmd/cepm/bindata_generated.go
### CEPMd end

### Go Tools begin
test:
	go test ./...
# http://godoc.org/code.google.com/p/go.tools/cmd/vet
# go get code.google.com/p/go.tools/cmd/vet
vet:
	-go vet ./...
# https://github.com/golang/lint
# go get github.com/golang/lint/golint
lint:
	golint ./...
# http://golang.org/cmd/go/#hdr-Run_gofmt_on_package_sources
fmt:
	go fmt ./...
### Go Tools end

### Framework Package begin
.PHONY: package_framework sync_framework clean_framework_package sync_framework_test
package: package_framework
package_framework: $(BUILD_DIR)/riak_mesos_$(OS_ARCH)_$(PACKAGE_VERSION).tar.gz
$(BUILD_DIR)/riak_mesos_$(OS_ARCH)_$(PACKAGE_VERSION).tar.gz:
	-rm -rf $(BUILD_DIR)/riak_mesos_framework
	mkdir -p $(BUILD_DIR)/riak_mesos_framework
	cp bin/framework_$(OS_ARCH) $(BUILD_DIR)/riak_mesos_framework/
	cp bin/tools_$(OS_ARCH) $(BUILD_DIR)/riak_mesos_framework/
	echo "Thank you for downloading Riak Mesos Framework. Please visit https://github.com/basho-labs/riak-mesos for usage information." > $(BUILD_DIR)/riak_mesos_framework/INSTALL.txt
	cd $(BUILD_DIR) && tar -zcvf riak_mesos_$(OS_ARCH)_$(PACKAGE_VERSION).tar.gz riak_mesos_framework
sync: sync_framework
sync_framework:
	cd $(BUILD_DIR)/ && \
		s3cmd put --acl-public riak_mesos_$(OS_ARCH)_$(PACKAGE_VERSION).tar.gz s3://$(DEPLOY_BASE)/$(DEPLOY_OS)/
sync_framework_test:
	cd $(BUILD_DIR)/ && \
		s3cmd put --acl-public riak_mesos_$(OS_ARCH)_$(PACKAGE_VERSION).tar.gz s3://$(DEPLOY_BASE)/$(DEPLOY_OS)/test/
clean_package: clean_framework_package
clean_framework_package:
	-rm $(BUILD_DIR)/riak_mesos_$(OS_ARCH)_$(PACKAGE_VERSION).tar.gz
### Framework Package end

### Director Package begin
.PHONY: package_director sync_director clean_director_package
package: package_director
package_director: $(BUILD_DIR)/riak_mesos_director_$(OS_ARCH)_$(PACKAGE_VERSION).tar.gz
$(BUILD_DIR)/riak_mesos_director_$(OS_ARCH)_$(PACKAGE_VERSION).tar.gz:
	-rm -rf $(BUILD_DIR)/riak_mesos_director
	mkdir -p $(BUILD_DIR)/riak_mesos_director
	cp bin/director_$(OS_ARCH) $(BUILD_DIR)/riak_mesos_director/
	echo "Thank you for downloading Riak Mesos Framework. Please visit https://github.com/basho-labs/riak-mesos for usage information." > $(BUILD_DIR)/riak_mesos_director/INSTALL.txt
	cd $(BUILD_DIR) && tar -zcvf riak_mesos_director_$(OS_ARCH)_$(PACKAGE_VERSION).tar.gz riak_mesos_director
sync: sync_director
sync_director:
	cd $(BUILD_DIR)/ && \
		s3cmd put --acl-public riak_mesos_director_$(OS_ARCH)_$(PACKAGE_VERSION).tar.gz s3://$(DEPLOY_BASE)/$(DEPLOY_OS)/
sync_director_test:
	cd $(BUILD_DIR)/ && \
		s3cmd put --acl-public riak_mesos_director_$(OS_ARCH)_$(PACKAGE_VERSION).tar.gz s3://$(DEPLOY_BASE)/$(DEPLOY_OS)/test/
clean_package: clean_director_package
clean_director_package:
	-rm $(BUILD_DIR)/riak_mesos_director_$(OS_ARCH)_$(PACKAGE_VERSION).tar.gz
### Director Package end

### CLI Package end
.PHONY: package_cli sync_cli clean_cli_package
#package: package_cli
package_cli: $(BUILD_DIR)/riak_mesos_cli_$(PACKAGE_VERSION).tar.gz
$(BUILD_DIR)/riak_mesos_cli_$(PACKAGE_VERSION).tar.gz:
	-rm -rf $(BUILD_DIR)/riak_mesos_cli
	mkdir -p $(BUILD_DIR)/riak_mesos_cli
	cp bin/riak-mesos $(BUILD_DIR)/riak_mesos_cli/
	cp bin/zktool_linux_amd64 $(BUILD_DIR)/riak_mesos_cli/
	cp bin/zktool_darwin_amd64 $(BUILD_DIR)/riak_mesos_cli/
	cd $(BUILD_DIR)/riak_mesos_cli/ && ./riak-mesos config --json | python -m json.tool > tmp.json
	mv $(BUILD_DIR)/riak_mesos_cli/tmp.json $(BUILD_DIR)/riak_mesos_cli/config.json
	echo "Thank you for downloading Riak Mesos Framework CLI tools. Run './riak-mesos --help' to get started. Please visit https://github.com/basho-labs/riak-mesos for usage information." > $(BUILD_DIR)/riak_mesos_cli/INSTALL.txt
	cd $(BUILD_DIR) && tar -zcvf riak_mesos_cli_$(PACKAGE_VERSION).tar.gz riak_mesos_cli
#sync: sync_cli
sync_cli:
	cd $(BUILD_DIR)/ && \
		s3cmd put --acl-public riak_mesos_cli_$(PACKAGE_VERSION).tar.gz s3://$(DEPLOY_BASE)/$(DEPLOY_OS)/
#clean_package: clean_cli_package
clean_cli_package:
	-rm -rf $(BUILD_DIR)/riak_mesos_cli
	-rm $(BUILD_DIR)/riak_mesos_cli_$(PACKAGE_VERSION).tar.gz
### CLI Package end

### DCOS Package begin
.PHONY: package_dcos sync_dcos clean_dcos_package
#package: package_dcos
package_dcos: $(BUILD_DIR)/dcos-riak-$(PACKAGE_VERSION).tar.gz
$(BUILD_DIR)/dcos-riak-$(PACKAGE_VERSION).tar.gz:
	-rm -rf $(BUILD_DIR)/dcos-riak-*
	mkdir -p $(BUILD_DIR)/
	cp -R dcos/dcos-riak $(BUILD_DIR)/dcos-riak-$(PACKAGE_VERSION)
	cd $(BUILD_DIR) && tar -zcvf dcos-riak-$(PACKAGE_VERSION).tar.gz dcos-riak-$(PACKAGE_VERSION)
#sync: sync_dcos
sync_dcos:
	cd $(BUILD_DIR)/ && \
		s3cmd put --acl-public dcos-riak-$(PACKAGE_VERSION).tar.gz s3://$(DEPLOY_BASE)/
sync_dcos_test:
	cd $(BUILD_DIR)/ && \
		s3cmd put --acl-public dcos-riak-$(PACKAGE_VERSION).tar.gz s3://$(DEPLOY_BASE)/test/
#clean_package: clean_dcos_package
clean_dcos_package:
	-rm $(BUILD_DIR)/dcos-riak-$(PACKAGE_VERSION).tar.gz
### DCOS Package end

### DCOS Repository Package begin
.PHONY: package_repo sync_repo clean_repo_package
package: package_repo
package_repo: $(BUILD_DIR)/dcos-repo-$(PACKAGE_VERSION).zip
$(BUILD_DIR)/dcos-repo-$(PACKAGE_VERSION).zip:
	-rm -rf $(BUILD_DIR)/dcos-repo-*
	mkdir -p $(BUILD_DIR)/
	git clone https://github.com/mesosphere/universe.git $(BUILD_DIR)/dcos-repo-$(PACKAGE_VERSION)
	cp -R dcos/repo/* $(BUILD_DIR)/dcos-repo-$(PACKAGE_VERSION)/repo/
	cd $(BUILD_DIR) && zip -r dcos-repo-$(PACKAGE_VERSION).zip dcos-repo-$(PACKAGE_VERSION)
sync: sync_repo
sync_repo:
	cd $(BUILD_DIR)/ && \
		s3cmd put --acl-public dcos-repo-$(PACKAGE_VERSION).zip s3://$(DEPLOY_BASE)/
clean_package: clean_repo_package
clean_repo_package:
	-rm $(BUILD_DIR)/dcos-repo-$(PACKAGE_VERSION).zip
### DCOS Repository Package end
