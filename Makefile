CXX       ?= g++
CC        ?= gcc
CXXFLAGS  ?= -Wall -Wextra -g -std=c++17
CFLAGS_GEN ?= -Wall -Wextra -std=c11

# Fix: MSYS2 via Claude Code não herda TMP do Windows; sem isso g++ falha
export TMPDIR := /tmp
export TMP    := /tmp
export TEMP   := /tmp

FLEX       ?= flex
BISON      ?= bison
BISON_FLAGS = -d

LEXER_SRC   = src/lexico.l
PARSER_SRC  = src/sintatico.y
LEXER_OUT   = src/lex.yy.c
PARSER_OUT  = src/sintatico.tab.c
PARSER_HDR  = src/sintatico.tab.h

TARGET = mila-compiler
FILE ?= tests/01_soma.mila
GENERATED_C ?= /tmp/mila_intermediario.c
GENERATED_BIN ?= /tmp/mila_intermediario

.PHONY: all run generate verify test test-% debug clean

all: $(TARGET)

$(TARGET): $(PARSER_OUT) $(LEXER_OUT)
	$(CXX) $(CXXFLAGS) -o $@ $(PARSER_OUT)

$(LEXER_OUT): $(LEXER_SRC)
	$(FLEX) -o $(LEXER_OUT) $(LEXER_SRC)

$(PARSER_OUT) $(PARSER_HDR): $(PARSER_SRC)
	$(BISON) $(BISON_FLAGS) -o $(PARSER_OUT) $(PARSER_SRC)

run: $(TARGET)
	./$(TARGET) < $(FILE)

generate: $(TARGET)
	./$(TARGET) < $(FILE) > $(GENERATED_C)
	@echo "Arquivo gerado: $(GENERATED_C)"

verify: generate
	$(CC) $(CFLAGS_GEN) $(GENERATED_C) -o $(GENERATED_BIN)
	$(GENERATED_BIN)

test: $(TARGET)
	@pass=0; fail=0; \
	for input in tests/*.mila; do \
		name=$$(basename $$input .mila); \
		expected="tests/$$name.expected"; \
		output="/tmp/$$name.out"; \
		if [ ! -f "$$expected" ]; then \
			echo "FAIL: $$name (arquivo expected ausente)"; \
			fail=$$((fail + 1)); \
		elif ./$(TARGET) < $$input > $$output; then \
			if diff -u --strip-trailing-cr $$expected $$output > /tmp/$$name.diff; then \
				echo "PASS: $$name"; \
				pass=$$((pass + 1)); \
			else \
				echo "FAIL: $$name"; \
				cat /tmp/$$name.diff; \
				fail=$$((fail + 1)); \
			fi; \
		else \
			echo "FAIL: $$name (erro de execucao do compilador)"; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "Resultado: $$pass passou, $$fail falhou"; \
	test $$fail -eq 0

test-%: $(TARGET)
	@input=$$(ls tests/$*_*.mila 2>/dev/null | head -1); \
	if [ -z "$$input" ]; then \
		echo "Teste nao encontrado: $*"; \
		exit 1; \
	fi; \
	expected="$${input%.mila}.expected"; \
	output="/tmp/mila_test_$*.out"; \
	./$(TARGET) < $$input > $$output; \
	diff -u --strip-trailing-cr $$expected $$output

debug: BISON_FLAGS += -Wcounterexamples

debug: clean all

clean:
	rm -f $(LEXER_OUT) $(PARSER_OUT) $(PARSER_HDR) $(TARGET)
	rm -f $(GENERATED_C) $(GENERATED_BIN)
