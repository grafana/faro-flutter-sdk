.PHONY: help run-example run-webview-demo

help:
	@echo "Available targets:"
	@echo "  make run-example                  Run the Flutter example app"
	@echo "  make run-example ARGS='...'       Forward extra args to flutter run"
	@echo "  make run-webview-demo             Run the React WebView demo app"
	@echo "  make run-webview-demo ARGS='...'  Forward extra args to yarn dev"

run-example:
	./tool/run-example.sh $(ARGS)

run-webview-demo:
	cd example/webview_demo && yarn install && yarn dev $(ARGS)
