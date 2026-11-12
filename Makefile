SHELL := /bin/bash
.DEFAULT_GOAL := help

PROJECT := macos/FuckingAdvice.xcodeproj
SCHEME := FuckingAdvice
CONFIGURATION ?= Release
VERSION ?= 0.1.1
BUILD_DIR := $(CURDIR)/build
DERIVED_DATA := $(BUILD_DIR)/DerivedData
UNSIGNED_DERIVED_DATA := $(BUILD_DIR)/DerivedDataUnsigned
APP := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/FuckingAdvice.app
UNSIGNED_APP := $(UNSIGNED_DERIVED_DATA)/Build/Products/$(CONFIGURATION)/FuckingAdvice.app
DMG := $(BUILD_DIR)/Fucking_Advice_$(VERSION).dmg
UNSIGNED_DMG := $(BUILD_DIR)/Fucking_Advice_$(VERSION)_UNSIGNED.dmg
ARCH ?= $(shell uname -m)
JOBS ?= $(shell sysctl -n hw.logicalcpu 2>/dev/null || echo 4)
BUNDLE_ID ?= com.nikitaparfenovich.FuckingAdvice
DEVELOPMENT_TEAM ?= $(shell scripts/team-id.sh)
APP_GROUP_ID ?= $(DEVELOPMENT_TEAM).fucking-advice-macos
XCODE_ARGS := -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) -jobs $(JOBS) MARKETING_VERSION=$(VERSION) HOST_BUNDLE_IDENTIFIER=$(BUNDLE_ID) WIDGET_BUNDLE_IDENTIFIER=$(BUNDLE_ID).Widgets APP_GROUP_ID=$(APP_GROUP_ID) DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) ADVICE_FETCHER_PATH=$(BUILD_DIR)/advice-fetcher
UNSIGNED_XCODE_ARGS := -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(UNSIGNED_DERIVED_DATA) -jobs $(JOBS) MARKETING_VERSION=$(VERSION) HOST_BUNDLE_IDENTIFIER=$(BUNDLE_ID) WIDGET_BUNDLE_IDENTIFIER=$(BUNDLE_ID).Widgets APP_GROUP_ID=$(APP_GROUP_ID) ADVICE_FETCHER_PATH=$(BUILD_DIR)/advice-fetcher

.PHONY: help preflight helper build build-unsigned run test lint package clean

help:
	@echo "Fucking Advice build targets"
	@echo "  make build          Signed app; emits DMG only for a runtime-validated binary"
	@echo "  make build-unsigned Compile-only diagnostic app; App Group/widget runtime will not work"
	@echo "  make run            Launch the signed build"
	@echo "  make test           Go and Swift unit tests"
	@echo "  make lint           Formatting, vet, plist, and project checks"
	@echo "  make package        ZIP the signed app"
	@echo "  make clean          Remove build products"

preflight:
	@BUNDLE_ID='$(BUNDLE_ID)' APP_GROUP_ID='$(APP_GROUP_ID)' DEVELOPMENT_TEAM='$(DEVELOPMENT_TEAM)' scripts/preflight.sh

helper:
	@mkdir -p $(BUILD_DIR)
	CGO_ENABLED=0 GOOS=darwin GOARCH=$(ARCH) go build -trimpath -ldflags='-s -w' -o $(BUILD_DIR)/advice-fetcher ./cmd/advice-fetcher

build: preflight helper
	@rm -f '$(DMG)' $(BUILD_DIR)/FuckingAdvice.app
	xcodebuild $(XCODE_ARGS) -allowProvisioningUpdates build
	@APP_GROUP_ID='$(APP_GROUP_ID)' DEVELOPMENT_TEAM='$(DEVELOPMENT_TEAM)' scripts/check-bundle.sh '$(APP)'
	@ln -sfn '$(APP)' $(BUILD_DIR)/FuckingAdvice.app
	@if scripts/runtime-validation.sh check '$(APP)'; then scripts/create-dmg.sh '$(APP)' '$(DMG)' '$(VERSION)'; else echo "Release DMG withheld: runtime validation is missing for this exact binary"; fi

build-unsigned: helper
	@rm -f '$(UNSIGNED_DMG)' $(BUILD_DIR)/FuckingAdvice_UNSIGNED.app
	xcodebuild $(UNSIGNED_XCODE_ARGS) CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
	@scripts/check-bundle.sh '$(UNSIGNED_APP)' --unsigned
	@ln -sfn '$(UNSIGNED_APP)' $(BUILD_DIR)/FuckingAdvice_UNSIGNED.app
	@scripts/create-dmg.sh '$(UNSIGNED_APP)' '$(UNSIGNED_DMG)' '$(VERSION)' --unsigned

run: build
	open '$(APP)'

test:
	go test ./...
	swift test --package-path macos --parallel

lint:
	@test -z "$$(gofmt -l cmd internal)" || { gofmt -d cmd internal; exit 1; }
	go vet ./...
	plutil -lint macos/Config/*.plist macos/Config/*.entitlements
	xcodebuild -project $(PROJECT) -list >/dev/null

package: build
	@scripts/runtime-validation.sh check '$(APP)'
	@test -f '$(DMG)' || scripts/create-dmg.sh '$(APP)' '$(DMG)' '$(VERSION)'
	@echo "Created $(DMG) (not notarized)"

clean:
	@rm -rf $(DERIVED_DATA) $(UNSIGNED_DERIVED_DATA) $(BUILD_DIR)/advice-fetcher $(BUILD_DIR)/FuckingAdvice.app $(BUILD_DIR)/FuckingAdvice_UNSIGNED.app $(BUILD_DIR)/Fucking_Advice_*.dmg $(BUILD_DIR)/dmg-staging
