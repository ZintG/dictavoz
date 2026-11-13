# Atajos de desarrollo. Ejecuta `make help` para ver la lista.

SHELL := /bin/bash
PREFIX ?= $(HOME)/.local
PYTHON ?= python3

.PHONY: help test lint install uninstall check-secrets version

help:
	@echo "Objetivos disponibles:"
	@echo "  make test           ejecuta las pruebas unitarias"
	@echo "  make lint           comprueba sintaxis de Python y Bash"
	@echo "  make install        instala con ./install.sh"
	@echo "  make uninstall      desinstala conservando los datos"
	@echo "  make check-secrets  busca claves o datos personales antes de publicar"
	@echo "  make version        muestra la versión actual"

test:
	$(PYTHON) -m unittest discover -s tests -v
	bash tests/test_hotkey.sh

lint:
	$(PYTHON) -m py_compile bin/dictado scripts/opencode.py
	bash -n install.sh
	bash -n uninstall.sh
	bash -n scripts/hotkey.sh
	bash -n scripts/check-secrets.sh
	bash -n tests/test_hotkey.sh

install:
	./install.sh --prefix "$(PREFIX)"

uninstall:
	./install.sh --uninstall --prefix "$(PREFIX)"

check-secrets:
	bash scripts/check-secrets.sh

version:
	@cat VERSION
