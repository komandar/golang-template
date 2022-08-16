MAKEFLAGS += --no-builtin-rules

APP_NAME=GO_PROJECT_NAME
APP_VERSION=1.0.0
APP_COMMIT=$(shell git log -1 --format=%h)
APP_COMMIT_DATE:=$(shell TZ=UTC git log -1 --format=%cd --date=format:"%Y-%m-%d")
APP_COMMIT_TIME:=$(shell TZ=UTC git log -1 --format=%cd --date=format:"%H:%M:%S")

GO_FLAGS= CGO_ENABLED=0
GO_LDFLAGS= -ldflags="-X main.appName=$(APP_NAME) -X main.appVersion=$(APP_VERSION) -X main.appCommit=$(APP_COMMIT) -X main.appCommitDate=$(APP_COMMIT_DATE) -X main.appCommitTime=$(APP_COMMIT_TIME)"
GO_BUILD_CMD=$(GO_FLAGS) go build $(GO_LDFLAGS)

BINARY_NAME=$(APP_NAME)
BUILD_DIR=build

.PHONY: all
all: clean generate-all lint test build-all package-all

#--------------------------------------
# Validation steps
#--------------------------------------

.PHONY: lint
lint: pre-build
	@echo "Linting code..."
	@sh hack/linter.sh

.PHONY: test
test: pre-build
	@echo "Running tests..."
ifeq ($(CI), true)
	@go test -short -coverprofile=build/coverage.txt -json ./... > build/test-report.json
else
	@go test -short -coverprofile=build/coverage.txt -covermode=atomic ./...
endif

#--------------------------------------
# Code generation steps
#--------------------------------------

.PHONY: code-gen
code-gen:
	@echo "Generating code..."
	@go generate ./...

.PHONY: generate-all
generate-all: code-gen

#--------------------------------------
# Build steps
#--------------------------------------

.PHONY: pre-build
pre-build:
	@mkdir -p $(BUILD_DIR)

.PHONY: build-arm
build-arm: pre-build
	@echo "Building ARM binary..."
	GOOS=linux GOARCH=arm64 $(GO_BUILD_CMD) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-arm64

.PHONY: build-linux
build-linux: pre-build
	@echo "Building Linux binary..."
	GOOS=linux GOARCH=amd64 $(GO_BUILD_CMD) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64

.PHONY: build-osx
build-osx: pre-build
	@echo "Building OSX binary..."
	GOOS=darwin GOARCH=amd64 $(GO_BUILD_CMD) -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-amd64

.PHONY: build build-all
build build-all: build-arm build-linux build-osx

#--------------------------------------
# Package steps
#--------------------------------------

.PHONY: package-arm
package-arm:
	@echo "Packaging Linux binary..."
	tar -C $(BUILD_DIR) -zcf $(BUILD_DIR)/$(BINARY_NAME)-$(APP_VERSION)-linux-arm64.tar.gz $(BINARY_NAME)-linux-arm64

.PHONY: package-linux
package-linux:
	@echo "Packaging Linux binary..."
	tar -C $(BUILD_DIR) -zcf $(BUILD_DIR)/$(BINARY_NAME)-$(APP_VERSION)-linux-amd64.tar.gz $(BINARY_NAME)-linux-amd64

.PHONY: package-osx
package-osx:
	@echo "Packaging OSX binary..."
	tar -C $(BUILD_DIR) -zcf $(BUILD_DIR)/$(BINARY_NAME)-$(APP_VERSION)-darwin-amd64.tar.gz $(BINARY_NAME)-darwin-amd64

.PHONY: package-all
package-all: package-arm package-linux package-osx

#--------------------------------------
# Docker steps
#--------------------------------------

.PHONY: docker
docker:
# Build a new image (delete old one)
	docker build --force-rm --build-arg GOPROXY -t $(BINARY_NAME) .

.PHONY: build-in-docker
build-in-docker: docker
# Force-stop any containers with this name
	docker rm -f $(BINARY_NAME) || true
# Create a new container with newly built image (but don't run it)
	docker create --name $(BINARY_NAME) $(BINARY_NAME)
# Copy over the binary to disk (from container)
	docker cp '$(BINARY_NAME):/opt/' $(BUILD_DIR)
# House-keeping: removing container
	docker rm -f $(BINARY_NAME)

#--------------------------------------
# Cleanup steps
#--------------------------------------

.PHONY: clean
clean:
	@echo "Cleaning..."
	@rm -Rf $(BUILD_DIR)

#--------------------------------------
# Help
#--------------------------------------

.DEFAULT_GOAL := show-help

.PHONY: show-help
show-help:
	@echo "$$(tput bold)Available rules:$$(tput sgr0)";echo;sed -ne"/^## /{h;s/.*//;:d" -e"H;n;s/^## //;td" -e"s/:.*//;G;s/\\n## /---/;s/\\n/ /g;p;}" ${MAKEFILE_LIST}|LC_ALL='C' sort -f|awk -F --- -v n=$$(tput cols) -v i=19 -v a="$$(tput setaf 6)" -v z="$$(tput sgr0)" '{printf"%s%*s%s ",a,-i,$$1,z;m=split($$2,w," ");l=n-i;for(j=1;j<=m;j++){l-=length(w[j])+1;if(l<= 0){l=n-i-length(w[j])-1;printf"\n%*s ",-i," ";}printf"%s ",w[j];}printf"\n";}'|more $(shell test $(shell uname) == Darwin && echo '-Xr')
