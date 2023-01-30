# justfile, see https://github.com/casey/just for more information
set dotenv-load := true

export APP_NAME = GO_PROJECT_NAME
export APP_VERSION = 1.0.0
export APP_COMMIT = $(shell git log -1 --format=%h)
export APP_COMMIT_DATE := $(shell TZ=UTC git log -1 --format=%cd --date=format:"%Y-%m-%d")
export APP_COMMIT_TIME := $(shell TZ=UTC git log -1 --format=%cd --date=format:"%H:%M:%S")

export GO_FLAGS = CGO_ENABLED=0
export GO_LDFLAGS = -ldflags="-X main.appName=$(APP_NAME) -X main.appVersion=$(APP_VERSION) -X main.appCommit=$(APP_COMMIT) -X main.appCommitDate=$(APP_COMMIT_DATE) -X main.appCommitTime=$(APP_COMMIT_TIME)"
export GO_BUILD_CMD = $(GO_FLAGS) go build $(GO_LDFLAGS)

export BINARY_NAME = $(APP_NAME)
export BUILD_DIR = build

#--------------------------------------
# Validation steps
#--------------------------------------

@test: pre-build
	echo "Running tests..."
	go test -short -coverprofile=build/coverage.txt -json ./... > build/test-report.json
	#go test -short -coverprofile=build/coverage.txt -covermode=atomic ./...

#--------------------------------------
# Code generation steps
#--------------------------------------

@code-gen:
	@echo "Generating code..."
	@go generate ./...

#--------------------------------------
# Build steps
#--------------------------------------

@pre-build:
	@mkdir -p $(BUILD_DIR)

@build-arm: pre-build
	@echo "Building ARM binary..."
	GOOS=linux GOARCH=arm64 $(GO_BUILD_CMD) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-arm64

@build-linux: pre-build
	@echo "Building Linux binary..."
	GOOS=linux GOARCH=amd64 $(GO_BUILD_CMD) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64

build build-all: build-arm build-linux

#--------------------------------------
# Package steps
#--------------------------------------

@package-arm:
	@echo "Packaging Linux binary..."
	tar -C $(BUILD_DIR) -zcf $(BUILD_DIR)/$(BINARY_NAME)-$(APP_VERSION)-linux-arm64.tar.gz $(BINARY_NAME)-linux-arm64

@package-linux:
	@echo "Packaging Linux binary..."
	tar -C $(BUILD_DIR) -zcf $(BUILD_DIR)/$(BINARY_NAME)-$(APP_VERSION)-linux-amd64.tar.gz $(BINARY_NAME)-linux-amd64

@package-all: package-arm package-linux

#--------------------------------------
# Docker steps
#--------------------------------------

@docker:
# Build a new image (delete old one)
	docker build --force-rm --build-arg GOPROXY -t $(BINARY_NAME) .

@build-in-docker: docker
# Force-stop any containers with this name
	docker rm -f $(BINARY_NAME) || true
# Create a new container with newly built image (but don't run it)
	docker create --name $(BINARY_NAME) $(BINARY_NAME)
# Copy over the binary to disk (from container)
	docker cp '$(BINARY_NAME):/opt/' $(BUILD_DIR)
# House-keeping: removing container
	docker rm -f $(BINARY_NAME)
