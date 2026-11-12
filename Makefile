SHELL := /bin/bash
.DEFAULT_GOAL := help

PROJECT := macos/FuckingAdvice.xcodeproj
SCHEME := FuckingAdvice
CONFIGURATION ?= Release
VERSION ?= 0.1.1
BUILD_DIR := $(CURDIR)/build
ARM64_DERIVED_DATA := $(BUILD_DIR)/DerivedData-arm64
UNIVERSAL_DERIVED_DATA := $(BUILD_DIR)/DerivedData-universal
UNSIGNED_DERIVED_DATA := $(BUILD_DIR)/DerivedDataUnsigned
ARM64_APP := $(ARM64_DERIVED_DATA)/Build/Products/$(CONFIGURATION)/FuckingAdvice.app
UNIVERSAL_APP := $(UNIVERSAL_DERIVED_DATA)/Build/Products/$(CONFIGURATION)/FuckingAdvice.app
UNSIGNED_APP := $(UNSIGNED_DERIVED_DATA)/Build/Products/$(CONFIGURATION)/FuckingAdvice.app
ARM64_DMG := $(BUILD_DIR)/Fucking_Advice_$(VERSION)_arm64.dmg
UNIVERSAL_DMG := $(BUILD_DIR)/Fucking_Advice_$(VERSION)_universal.dmg
UNSIGNED_DMG := $(BUILD_DIR)/Fucking_Advice_$(VERSION)_arm64_UNSIGNED.dmg
ARM64_HELPER := $(BUILD_DIR)/helpers/advice-fetcher-arm64
AMD64_HELPER := $(BUILD_DIR)/helpers/advice-fetcher-amd64
UNIVERSAL_HELPER := $(BUILD_DIR)/helpers/advice-fetcher-universal
ARM64_STAMP := $(BUILD_DIR)/runtime-validation-arm64.sha256
UNIVERSAL_STAMP := $(BUILD_DIR)/runtime-validation-universal.sha256
JOBS ?= $(shell sysctl -n hw.logicalcpu 2>/dev/null || echo 4)
BUNDLE_ID ?= com.nikitaparfenovich.FuckingAdvice
DEVELOPMENT_TEAM ?= $(shell scripts/team-id.sh)
APP_GROUP_ID ?= $(DEVELOPMENT_TEAM).fucking-advice-macos
COMMON_XCODE_ARGS := -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -jobs $(JOBS) MARKETING_VERSION=$(VERSION) HOST_BUNDLE_IDENTIFIER=$(BUNDLE_ID) WIDGET_BUNDLE_IDENTIFIER=$(BUNDLE_ID).Widgets APP_GROUP_ID=$(APP_GROUP_ID)
SIGNED_XCODE_ARGS := $(COMMON_XCODE_ARGS) DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM)

.PHONY: help preflight helper-arm64 helper-amd64 helper-universal build build-arm64 build-universal build-all build-unsigned run test lint record-runtime-arm64 record-runtime-universal package package-arm64 package-universal package-all clean

help:
	@echo "Fucking Advice build targets"
	@echo "  make build            Alias for build-arm64"
	@echo "  make build-arm64      Apple Silicon app and runtime-gated DMG"
	@echo "  make build-universal  arm64+x86_64 app and runtime-gated DMG"
	@echo "  make build-all        Build both signed variants"
	@echo "  make build-unsigned   Compile-only arm64 diagnostic bundle"
	@echo "  make run              Launch the signed arm64 build"
	@echo "  make test             Run Go and Swift unit tests"
	@echo "  make lint             Formatting, vet, plist, and project checks"
	@echo "  make record-runtime-arm64      Record completed manual runtime validation"
	@echo "  make record-runtime-universal  Record completed manual runtime validation"
	@echo "  make package          Alias for package-arm64"
	@echo "  make package-all      Package both already-built, runtime-validated variants"
	@echo "  make clean            Remove build products"

preflight:
	@BUNDLE_ID='$(BUNDLE_ID)' APP_GROUP_ID='$(APP_GROUP_ID)' DEVELOPMENT_TEAM='$(DEVELOPMENT_TEAM)' scripts/preflight.sh

helper-arm64:
	@mkdir -p $(BUILD_DIR)/helpers
	CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -trimpath -ldflags='-s -w' -o $(ARM64_HELPER) ./cmd/advice-fetcher

helper-amd64:
	@mkdir -p $(BUILD_DIR)/helpers
	CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -trimpath -ldflags='-s -w' -o $(AMD64_HELPER) ./cmd/advice-fetcher

helper-universal: helper-arm64 helper-amd64
	lipo -create -output $(UNIVERSAL_HELPER) $(ARM64_HELPER) $(AMD64_HELPER)
	@scripts/check-architectures.sh '$(UNIVERSAL_HELPER)' arm64 x86_64

build: build-arm64

build-arm64: preflight helper-arm64
	@rm -f '$(ARM64_DMG)' $(BUILD_DIR)/FuckingAdvice.app $(BUILD_DIR)/FuckingAdvice_arm64.app
	xcodebuild $(SIGNED_XCODE_ARGS) -derivedDataPath $(ARM64_DERIVED_DATA) ADVICE_FETCHER_PATH=$(ARM64_HELPER) ARCHS=arm64 ONLY_ACTIVE_ARCH=NO -allowProvisioningUpdates build
	@APP_GROUP_ID='$(APP_GROUP_ID)' DEVELOPMENT_TEAM='$(DEVELOPMENT_TEAM)' scripts/check-bundle.sh '$(ARM64_APP)'
	@scripts/check-architectures.sh '$(ARM64_APP)' arm64
	@ln -sfn '$(ARM64_APP)' $(BUILD_DIR)/FuckingAdvice.app
	@ln -sfn '$(ARM64_APP)' $(BUILD_DIR)/FuckingAdvice_arm64.app
	@if scripts/runtime-validation.sh check '$(ARM64_APP)' '$(ARM64_STAMP)'; then scripts/create-dmg.sh '$(ARM64_APP)' '$(ARM64_DMG)' '$(VERSION)' arm64; else echo "ARM64 DMG withheld: runtime validation is missing for this exact binary"; fi

build-universal: preflight helper-universal
	@rm -f '$(UNIVERSAL_DMG)' $(BUILD_DIR)/FuckingAdvice_universal.app
	xcodebuild $(SIGNED_XCODE_ARGS) -derivedDataPath $(UNIVERSAL_DERIVED_DATA) ADVICE_FETCHER_PATH=$(UNIVERSAL_HELPER) ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO -allowProvisioningUpdates build
	@APP_GROUP_ID='$(APP_GROUP_ID)' DEVELOPMENT_TEAM='$(DEVELOPMENT_TEAM)' scripts/check-bundle.sh '$(UNIVERSAL_APP)'
	@scripts/check-architectures.sh '$(UNIVERSAL_APP)' arm64 x86_64
	@ln -sfn '$(UNIVERSAL_APP)' $(BUILD_DIR)/FuckingAdvice_universal.app
	@if scripts/runtime-validation.sh check '$(UNIVERSAL_APP)' '$(UNIVERSAL_STAMP)'; then scripts/create-dmg.sh '$(UNIVERSAL_APP)' '$(UNIVERSAL_DMG)' '$(VERSION)' universal; else echo "Universal DMG withheld: runtime validation is missing for this exact binary"; fi

build-all: build-arm64 build-universal

build-unsigned: helper-arm64
	@rm -f '$(UNSIGNED_DMG)' $(BUILD_DIR)/FuckingAdvice_UNSIGNED.app
	xcodebuild $(COMMON_XCODE_ARGS) -derivedDataPath $(UNSIGNED_DERIVED_DATA) ADVICE_FETCHER_PATH=$(ARM64_HELPER) ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
	@scripts/check-bundle.sh '$(UNSIGNED_APP)' --unsigned
	@ln -sfn '$(UNSIGNED_APP)' $(BUILD_DIR)/FuckingAdvice_UNSIGNED.app
	@scripts/create-dmg.sh '$(UNSIGNED_APP)' '$(UNSIGNED_DMG)' '$(VERSION)' arm64 --unsigned

run: build-arm64
	open '$(ARM64_APP)'

test:
	go test ./...
	swift test --package-path macos --parallel

lint:
	@test -z "$$(gofmt -l cmd internal)" || { gofmt -d cmd internal; exit 1; }
	go vet ./...
	plutil -lint macos/Config/*.plist macos/Config/*.entitlements
	jq empty macos/Assets.xcassets/Contents.json macos/Assets.xcassets/AppIcon.appiconset/Contents.json
	bash -n scripts/*.sh
	xcodebuild -project $(PROJECT) -list >/dev/null

package: package-arm64

record-runtime-arm64:
	@test "$(CONFIRM_RUNTIME_VALIDATION)" = YES || { echo "error: complete the manual app/widget runtime checklist, then rerun with CONFIRM_RUNTIME_VALIDATION=YES" >&2; exit 2; }
	@test -d '$(ARM64_APP)' || { echo "error: arm64 app is missing; run make build-arm64 first" >&2; exit 1; }
	@APP_GROUP_ID='$(APP_GROUP_ID)' DEVELOPMENT_TEAM='$(DEVELOPMENT_TEAM)' scripts/check-bundle.sh '$(ARM64_APP)'
	@scripts/check-architectures.sh '$(ARM64_APP)' arm64
	@scripts/runtime-validation.sh record '$(ARM64_APP)' '$(ARM64_STAMP)'

record-runtime-universal:
	@test "$(CONFIRM_RUNTIME_VALIDATION)" = YES || { echo "error: complete the manual app/widget runtime checklist, then rerun with CONFIRM_RUNTIME_VALIDATION=YES" >&2; exit 2; }
	@test -d '$(UNIVERSAL_APP)' || { echo "error: universal app is missing; run make build-universal first" >&2; exit 1; }
	@APP_GROUP_ID='$(APP_GROUP_ID)' DEVELOPMENT_TEAM='$(DEVELOPMENT_TEAM)' scripts/check-bundle.sh '$(UNIVERSAL_APP)'
	@scripts/check-architectures.sh '$(UNIVERSAL_APP)' arm64 x86_64
	@scripts/runtime-validation.sh record '$(UNIVERSAL_APP)' '$(UNIVERSAL_STAMP)'

package-arm64:
	@test -d '$(ARM64_APP)' || { echo "error: arm64 app is missing; run make build-arm64 first" >&2; exit 1; }
	@APP_GROUP_ID='$(APP_GROUP_ID)' DEVELOPMENT_TEAM='$(DEVELOPMENT_TEAM)' scripts/check-bundle.sh '$(ARM64_APP)'
	@scripts/check-architectures.sh '$(ARM64_APP)' arm64
	@scripts/runtime-validation.sh check '$(ARM64_APP)' '$(ARM64_STAMP)'
	@scripts/create-dmg.sh '$(ARM64_APP)' '$(ARM64_DMG)' '$(VERSION)' arm64
	@echo "Created $(ARM64_DMG) (not notarized)"

package-universal:
	@test -d '$(UNIVERSAL_APP)' || { echo "error: universal app is missing; run make build-universal first" >&2; exit 1; }
	@APP_GROUP_ID='$(APP_GROUP_ID)' DEVELOPMENT_TEAM='$(DEVELOPMENT_TEAM)' scripts/check-bundle.sh '$(UNIVERSAL_APP)'
	@scripts/check-architectures.sh '$(UNIVERSAL_APP)' arm64 x86_64
	@scripts/runtime-validation.sh check '$(UNIVERSAL_APP)' '$(UNIVERSAL_STAMP)'
	@scripts/create-dmg.sh '$(UNIVERSAL_APP)' '$(UNIVERSAL_DMG)' '$(VERSION)' universal
	@echo "Created $(UNIVERSAL_DMG) (not notarized)"

package-all: package-arm64 package-universal

clean:
	@rm -rf $(ARM64_DERIVED_DATA) $(UNIVERSAL_DERIVED_DATA) $(UNSIGNED_DERIVED_DATA) $(BUILD_DIR)/helpers $(BUILD_DIR)/FuckingAdvice.app $(BUILD_DIR)/FuckingAdvice_arm64.app $(BUILD_DIR)/FuckingAdvice_universal.app $(BUILD_DIR)/FuckingAdvice_UNSIGNED.app $(BUILD_DIR)/Fucking_Advice_*.dmg $(BUILD_DIR)/dmg-staging-* $(ARM64_STAMP) $(UNIVERSAL_STAMP)
