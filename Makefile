
.DEFAULT_GOAL := build_spec

SHELL := /bin/bash

CURR_DIR := $(shell realpath ./)

/opt/wasi-sdk/bin/clang:
	wget https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-10/wasi-sdk-10.0-linux.tar.gz -P /tmp/ && \
	tar -xzf /tmp/wasi-sdk-10.0-linux.tar.gz && \
	sudo mv wasi-sdk-10.0 /opt/wasi-sdk

libnsl:
	git clone https://github.com/thkukuk/libnsl

lucet-spectre:
	git clone https://github.com/bytecodealliance/lucet $@
	cd $@ && git submodule update --init --recursive

lucet/target/release/lucetc: lucet-spectre
	cd lucet-spectre && cargo build --release

libnsl/build/lib/libnsl.so: libnsl
	cd ./libnsl && \
	autoreconf -fi && \
	./configure --prefix "$(CURR_DIR)/libnsl/build" && \
	make -j8 all && \
	make install

libnsl/build/lib/libnsl.so.1: libnsl/build/lib/libnsl.so
	cp $< $@

sfi-spectre-spec: libnsl/build/lib/libnsl.so.1
	git clone git@github.com:PLSysSec/sfi-spectre-spec.git
	cd sfi-spectre-spec && LD_LIBRARY_PATH="$(CURR_DIR)/libnsl/build/lib/" SPEC_INSTALL_NOCHECK=1 SPEC_FORCE_INSTALL=1 sh install.sh -f
	cd sfi-spectre-spec/benchspec/CPU2006/450.soplex/data/ref/input && tar -zxvf data.tar.gz

build_spec: /opt/wasi-sdk/bin/clang lucet/target/release/lucetc sfi-spectre-spec 
	export LD_LIBRARY_PATH="$(CURR_DIR)/libnsl/build/lib/" && \
	cd sfi-spectre-spec && source shrc && \
	cd config && \
	echo "Cleaning dirs" && \
	runspec --config=wasm_lucet --action=clobber oakland


run_spec:
	export LD_LIBRARY_PATH="$(CURR_DIR)/libnsl/build/lib/" && \
	sh cp_spec_data_into_tmp.sh && \
	cd sfi-spectre-spec && source shrc && cd config && \
	runspec --config=wasm_lucet --iterations=1 --noreportable --size=ref --wasm oakland

