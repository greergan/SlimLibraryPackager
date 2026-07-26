BUILD_DIR := build
INSTALL_PREFIX ?= /usr
CMAKE := cmake
LOCAL_SRC ?= ON
RELEASE_TYPE ?= DEBUG
SHARED_ONLY ?= ON
SLIM_GIT_URL ?= https://codeberg.org
SLIM_GIT_REPO_OWNER ?= greergan
NINJA := $(shell command -v ninja 2>/dev/null)
ifdef NINJA
CMAKE_GENERATOR := -G Ninja
else
CMAKE_GENERATOR :=
endif
IS_DEBIAN := $(shell test -f /etc/debian_version && echo "yes")
IS_REDHAT := $(shell test -f /etc/redhat-release && echo "yes")
ARCH_RAW := $(shell uname -m)
ifeq ($(ARCH_RAW),x86_64)
	ARCH := x86_64
else ifeq ($(ARCH_RAW),amd64)
	ARCH := x86_64
else ifeq ($(ARCH_RAW),i386)
	ARCH := x86
else ifeq ($(ARCH_RAW),i686)
	ARCH := x86
else ifeq ($(ARCH_RAW),aarch64)
	ARCH := arm64
else ifeq ($(ARCH_RAW),armv7l)
	ARCH := arm
else
	ARCH := unknown
endif
_THIS_DIR := $(notdir $(CURDIR))
ifeq ($(_THIS_DIR),SlimCommon)
.DEFAULT_GOAL := slimcommon
else
.DEFAULT_GOAL := build
endif
.PHONY: all configure build slimcommon install local test deb rpm packages clean version
all: $(.DEFAULT_GOAL)
configure:
	$(CMAKE) $(CMAKE_GENERATOR) -S . -B $(BUILD_DIR) \
		-DCMAKE_BUILD_TYPE=$(RELEASE_TYPE) \
		-DCMAKE_INSTALL_PREFIX=$(INSTALL_PREFIX) \
		-DCPACK_OUTPUT_FILE_PREFIX=$(DIST_DIR) \
		-DSLIM_USE_LOCAL_SOURCE=$(LOCAL_SRC) \
		-DSLIM_SHARED_ONLY=$(SHARED_ONLY) \
		-DSLIM_GIT_URL=$(SLIM_GIT_URL) \
		-DSLIM_GIT_REPO_OWNER=$(SLIM_GIT_REPO_OWNER)
build: configure
	$(CMAKE) --build $(BUILD_DIR)
slimcommon:
	$(CMAKE) $(CMAKE_GENERATOR) -S . -B $(BUILD_DIR) \
		-DCMAKE_BUILD_TYPE=$(RELEASE_TYPE) \
		-DCMAKE_INSTALL_PREFIX=$(INSTALL_PREFIX) \
		-DSLIM_USE_LOCAL_SOURCE=OFF \
		-DSLIM_SHARED_ONLY=OFF \
		-DSLIM_GIT_URL=$(SLIM_GIT_URL) \
		-DSLIM_GIT_REPO_OWNER=$(SLIM_GIT_REPO_OWNER)
	$(CMAKE) --build $(BUILD_DIR)
	cd $(BUILD_DIR) && cpack -G DEB
	@dpkg -l 'SlimCommon*' 2>/dev/null | awk '/^ii/{print $$2}' | xargs -r dpkg -r 2>/dev/null
	@PKG=$$(ls -1 dist/*.deb 2>/dev/null | sort -Vr | head -n 1); \
	if [ -n "$$PKG" ]; then \
		echo "Installing $$PKG"; \
		dpkg -i "$$PKG"; \
	else \
		echo "No .deb produced"; \
		exit 1; \
	fi
install:
	@if [ "$(IS_DEBIAN)" = "yes" ]; then \
		$(MAKE) LOCAL_SRC=OFF SHARED_ONLY=OFF deb; \
		PKG=$$(ls -1 dist/*.deb 2>/dev/null | sort -Vr | head -n 1); \
		if [ -n "$$PKG" ]; then \
			echo "Installing $$PKG"; \
			dpkg -i "$$PKG"; \
		else \
			echo "No .deb produced"; \
			exit 1; \
		fi; \
	elif [ "$(IS_REDHAT)" = "yes" ]; then \
		$(MAKE) LOCAL_SRC=OFF SHARED_ONLY=OFF rpm; \
		PKG=$$(ls -1 dist/*.rpm 2>/dev/null | sort -Vr | head -n 1); \
		if [ -n "$$PKG" ]; then \
			echo "Installing $$PKG"; \
			rpm -i "$$PKG"; \
		else \
			echo "No .rpm produced"; \
			exit 1; \
		fi; \
	else \
		echo "Unsupported platform"; \
		exit 1; \
	fi;
local:
	@if [ "$(IS_DEBIAN)" = "yes" ]; then \
		$(MAKE) LOCAL_SRC=ON SHARED_ONLY=OFF deb; \
		PKG=$$(ls -1 dist/*0.0.0*.deb 2>/dev/null | sort -Vr | head -n 1); \
		if [ -n "$$PKG" ]; then \
			echo "Installing $$PKG"; \
			dpkg -i "$$PKG"; \
		else \
			echo "No .deb produced"; \
			exit 1; \
		fi; \
	elif [ "$(IS_REDHAT)" = "yes" ]; then \
		$(MAKE) LOCAL_SRC=ON SHARED_ONLY=OFF rpm; \
		PKG=$$(ls -1 dist/*0.0.0*.rpm 2>/dev/null | sort -Vr | head -n 1); \
		if [ -n "$$PKG" ]; then \
			echo "Installing $$PKG"; \
			rpm -i "$$PKG"; \
		else \
			echo "No .rpm produced"; \
			exit 1; \
		fi; \
	else \
		echo "Unsupported platform"; \
		exit 1; \
	fi;
deb: build
	cd $(BUILD_DIR) && cpack -G DEB
rpm: build
	cd $(BUILD_DIR) && cpack -G RPM
packages:
	@echo "Building packages"
	$(MAKE) LOCAL_SRC=OFF SHARED_ONLY=OFF RELEASE_TYPE=RELEASE configure
	$(CMAKE) --build $(BUILD_DIR) --target dist
	@echo "Packaging DEB"
	cd $(BUILD_DIR) && cpack -G DEB
	@echo "Packaging RPM"
	cd $(BUILD_DIR) && cpack -G RPM

version:
ifeq ($(_THIS_DIR),SlimCommon)
	@if [ ! -f required_packages ]; then \
		echo "version: required_packages not found"; \
		exit 1; \
	fi; \
	LAST_TAG=$$(git describe --tags --abbrev=0 2>/dev/null); \
	if [ -z "$$LAST_TAG" ]; then \
		echo "version: no tags found, create an initial tag manually"; \
		exit 1; \
	fi; \
	LAST_BODY=$$(git cat-file tag "$$LAST_TAG" 2>/dev/null | sed '1,/^$$/d'); \
	MSGFILE=$$(mktemp); \
	PKGFILE=$$(mktemp); \
	while IFS= read -r line || [ -n "$$line" ]; do \
		line=$$(echo "$$line" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$$//'); \
		[ -z "$$line" ] && continue; \
		PKG=$$(echo "$$line" | awk '{print $$1}'); \
		RECORDED=$$(echo "$$LAST_BODY" | grep "^$$PKG v" | awk '{print $$2}'); \
		[ -z "$$RECORDED" ] && RECORDED="v0.0.0"; \
		PAGE=1; LIMIT=50; LATEST_TAG=""; STOP=0; \
		while [ "$$STOP" -eq 0 ]; do \
		    TMPOBJ=$$(mktemp); \
		    curl -sf "$(SLIM_GIT_URL)/api/v1/repos/$(SLIM_GIT_REPO_OWNER)/$$PKG/tags?limit=$$LIMIT&page=$$PAGE" 2>/dev/null | sed 's/},{/\n/g' > "$$TMPOBJ"; \
		    if [ ! -s "$$TMPOBJ" ] || grep -q '^\[\]$$' "$$TMPOBJ"; then rm -f "$$TMPOBJ"; break; fi; \
			COUNT=0; \
			while IFS= read -r OBJ; do \
				NAME=$$(echo "$$OBJ" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4); \
				MSG=$$(echo "$$OBJ" | tr '\n' '\001' | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4 | tr '\001' '\n'); \
				[ -z "$$NAME" ] && continue; \
				COUNT=$$((COUNT + 1)); \
				if [ "$$NAME" = "$$RECORDED" ]; then STOP=1; break; fi; \
				SORTED=$$(printf '%s\n' "$$RECORDED" "$$NAME" | sort -V | tail -1); \
				if [ "$$SORTED" != "$$NAME" ]; then STOP=1; break; fi; \
				[ -z "$$LATEST_TAG" ] && LATEST_TAG="$$NAME"; \
				MSGTMP=$$(mktemp); \
				printf '%b' "$$MSG" > "$$MSGTMP"; \
				PENDING=""; \
				while IFS= read -r subline || [ -n "$$subline" ]; do \
                    [ -z "$$(echo "$$subline" | tr -d '[:space:]')" ] && continue; \
                    if echo "$$subline" | grep -q '^[[:space:]]'; then \
                        PENDING="$$PENDING $$(echo "$$subline" | sed 's/^[[:space:]]*//')"; \
                    else \
                        if [ -n "$$PENDING" ]; then \
                            PENDING=$$(echo "$$PENDING" | sed 's/^v[0-9][^:]*: //'); \
                            [ -n "$$(echo "$$PENDING" | tr -d '[:space:]')" ] && printf '%s|%s\n' "$$PKG" "$$PENDING" >> "$$MSGFILE"; \
                        fi; \
                        PENDING=$$(echo "$$subline" | sed 's/^v[0-9][^:]*: //'); \
                    fi; \
				done < "$$MSGTMP"; \
				if [ -n "$$PENDING" ]; then \
                    PENDING=$$(echo "$$PENDING" | sed 's/^v[0-9][^:]*: //'); \
                    [ -n "$$(echo "$$PENDING" | tr -d '[:space:]')" ] && printf '%s|%s\n' "$$PKG" "$$PENDING" >> "$$MSGFILE"; \
				fi; \
				rm -f "$$MSGTMP"; \
			done < "$$TMPOBJ"; \
			rm -f "$$TMPOBJ"; \
			[ "$$STOP" -eq 1 ] && break; \
			[ "$$COUNT" -lt "$$LIMIT" ] && break; \
			PAGE=$$((PAGE + 1)); \
		done; \
		if [ -n "$$LATEST_TAG" ] && [ "$$LATEST_TAG" != "$$RECORDED" ]; then \
			printf 'CHANGED|%s|%s\n' "$$PKG" "$$LATEST_TAG" >> "$$PKGFILE"; \
		else \
			printf 'SAME|%s|%s\n' "$$PKG" "$$RECORDED" >> "$$PKGFILE"; \
		fi; \
	done < required_packages; \
	CHANGED_COUNT=$$(grep -c "^CHANGED|" "$$PKGFILE" 2>/dev/null || echo 0); \
	if [ "$$CHANGED_COUNT" -eq 0 ]; then \
		echo "version: no micro-library changes since $$LAST_TAG"; \
		rm -f "$$MSGFILE" "$$PKGFILE"; \
		exit 0; \
	fi; \
	BUMP=""; \
	CHANGELOG=""; \
	while IFS= read -r entry; do \
		PKG=$$(echo "$$entry" | cut -d'|' -f1); \
		MSG=$$(echo "$$entry" | cut -d'|' -f2-); \
		CLEAN=$$(echo "$$MSG" | sed 's/^v[0-9][^:]*: //'); \
		[ -z "$$(echo "$$CLEAN" | tr -d '[:space:]')" ] && continue; \
		MAYBE_PREFIX=$$(echo "$$CLEAN" | cut -d':' -f1); \
		if echo "$$CLEAN" | grep -q ':' && ! echo "$$MAYBE_PREFIX" | grep -q ' '; then \
			PREFIX="$$MAYBE_PREFIX"; \
			REST=$$(echo "$$CLEAN" | cut -d':' -f2- | sed 's/^ //'); \
		else \
			PREFIX=""; \
			REST="$$CLEAN"; \
		fi; \
		case "$$PREFIX" in \
			feature|refactor) \
				BUMP="minor"; \
				CHANGELOG="$${CHANGELOG}$${PREFIX}($${PKG}): $${REST}\n"; \
				;; \
			fix|docs) \
				[ -z "$$BUMP" ] && BUMP="patch"; \
				CHANGELOG="$${CHANGELOG}$${PREFIX}($${PKG}): $${REST}\n"; \
				;; \
			"") \
				CHANGELOG="$${CHANGELOG}($${PKG}): $${REST}\n"; \
				;; \
			*) \
				CHANGELOG="$${CHANGELOG}$${PREFIX}($${PKG}): $${REST}\n"; \
				;; \
		esac; \
	done < "$$MSGFILE"; \
	[ -z "$$BUMP" ] && BUMP="patch"; \
	VERSION=$$(echo "$$LAST_TAG" | sed 's/^v//'); \
	MAJOR=$$(echo "$$VERSION" | cut -d. -f1); \
	MINOR=$$(echo "$$VERSION" | cut -d. -f2); \
	PATCH=$$(echo "$$VERSION" | cut -d. -f3); \
	if [ "$$BUMP" = "minor" ]; then \
		MINOR=$$((MINOR + 1)); \
		PATCH=0; \
	else \
		PATCH=$$((PATCH + 1)); \
	fi; \
	NEW_TAG="v$$MAJOR.$$MINOR.$$PATCH"; \
	PKG_LINES=$$(awk -F'|' '{print $$2" "$$3}' "$$PKGFILE"); \
	TAG_BODY="$$NEW_TAG\n$${CHANGELOG}\n$${PKG_LINES}"; \
	printf '%b' "$$TAG_BODY" | git tag -a "$$NEW_TAG" -F -; \
	echo "version: tagged $$NEW_TAG"; \
	printf '%b\n' "$$TAG_BODY"; \
	rm -f "$$MSGFILE" "$$PKGFILE"
else
	@LAST_TAG=$$(git describe --tags --abbrev=0 2>/dev/null); \
	if [ -z "$$LAST_TAG" ]; then \
		echo "version: no tags found, create an initial tag manually"; \
		exit 0; \
	fi; \
	COMMITS=$$(git log "$$LAST_TAG"..HEAD --oneline 2>/dev/null); \
	if [ -z "$$COMMITS" ]; then \
		echo "version: no commits since $$LAST_TAG"; \
		exit 0; \
	fi; \
	TMPFILE=$$(mktemp); \
	printf '%s\n' "$$COMMITS" > "$$TMPFILE"; \
	BUMP=""; \
	BUMP_MSG=""; \
	while IFS= read -r commit; do \
		MSG=$$(echo "$$commit" | sed 's/^[0-9a-f]* //'); \
		PREFIX=$$(echo "$$MSG" | cut -d':' -f1); \
		case "$$PREFIX" in \
			feature|refactor) \
				if [ "$$BUMP" != "minor" ]; then \
					BUMP="minor"; \
					BUMP_MSG="$$MSG"; \
				fi; \
				;; \
			fix|docs) \
				if [ -z "$$BUMP" ]; then \
					BUMP="patch"; \
					BUMP_MSG="$$MSG"; \
				fi; \
				;; \
		esac; \
	done < "$$TMPFILE"; \
	rm -f "$$TMPFILE"; \
	if [ -z "$$BUMP" ]; then \
		echo "version: no version-bumping commits since $$LAST_TAG"; \
		exit 0; \
	fi; \
	VERSION=$$(echo "$$LAST_TAG" | sed 's/^v//'); \
	MAJOR=$$(echo "$$VERSION" | cut -d. -f1); \
	MINOR=$$(echo "$$VERSION" | cut -d. -f2); \
	PATCH=$$(echo "$$VERSION" | cut -d. -f3); \
	if [ "$$BUMP" = "minor" ]; then \
		MINOR=$$((MINOR + 1)); \
		PATCH=0; \
	else \
		PATCH=$$((PATCH + 1)); \
	fi; \
	NEW_TAG="v$$MAJOR.$$MINOR.$$PATCH"; \
	TAG_BODY="$$NEW_TAG: $$BUMP_MSG"; \
	git tag -a "$$NEW_TAG" -m "$$TAG_BODY"; \
	echo "version: tagged $$NEW_TAG"; \
	echo "$$TAG_BODY"
endif

clean:
	rm -rf $(BUILD_DIR)
	rm -rf dist
