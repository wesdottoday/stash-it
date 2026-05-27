APP = stash-it.app

.PHONY: build run install debug clean

build:
	@./scripts/build.sh release

debug:
	@./scripts/build.sh debug

run: build
	open $(APP)

install: build
	@rm -rf /Applications/$(APP)
	@cp -R $(APP) /Applications/
	@echo "Installed to /Applications/$(APP)"

clean:
	rm -rf .build $(APP)
