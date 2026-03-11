.PHONY: install test lint

install:
	uv pip install -e . --force-reinstall --quiet

test: install
	bash test_smoke.sh

lint: install
	uv run agents lint
