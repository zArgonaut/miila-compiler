# Relatório de Desenvolvimento — Miila Compiler

Registro histórico de decisões técnicas. Cada entrada é imutável — apenas se adiciona.

---

### 2026-05-31 — Arquitetura inicial: Flex + Bison + C++

**Categoria:** Arquitetura
**Contexto:** Necessidade de implementar o compilador para a disciplina de Compiladores da UFRRJ com ferramentas clássicas da área.
**Decisão:** Usar Flex para análise léxica, Bison (LALR(1)) para análise sintática e C++ para as funções semânticas e de geração de código.
**Justificativa Técnica:** Flex e Bison são as ferramentas canônicas para ensino de compiladores; a combinação produz um parser LALR(1) eficiente e bem documentado. C++ permite usar `std::map`, `std::vector` e `std::string` sem overhead de gerenciamento de memória manual.
**Artefatos:** `src/lexico.l`, `src/sintatico.y`
**Impacto:** Define toda a cadeia de build: flex → bison → g++.
**Status:** [x] Implementado

---

### 2026-05-31 — Modelo de geração: código de três endereços em C

**Categoria:** Geração de Código
**Contexto:** A disciplina exige código intermediário legível e verificável.
**Decisão:** Gerar código C de três endereços com temporários explícitos `T1`, `T2`, ... em vez de bytecode ou IR próprio.
**Justificativa Técnica:** C como IR permite validação direta com GCC, facilita depuração e é legível por humanos. A restrição "uma operação por linha, resultado em temporário" impõe disciplina de representação equivalente a TAC (Three-Address Code).
**Artefatos:** `printProgram()` em `sintatico.y`
**Impacto:** Toda a estrutura de `attributes.translation` segue o padrão de acumulação de linha por linha.
**Status:** [x] Implementado

---

### 2026-05-31 — Representação de `boolean` como `int` no C gerado

**Categoria:** Sistema de Tipos
**Contexto:** C não tem tipo booleano nativo em C89/C90; usar `int` maximiza portabilidade.
**Decisão:** `boolean` e `bool` são aceitos como tipos na linguagem fonte, mantidos como `t_bool` internamente, mas emitidos como `int` no C intermediário. `true` → `1`, `false` → `0` na fase léxica.
**Justificativa Técnica:** Manter um tipo `t_bool` interno permite verificação semântica rigorosa (e.g., rejeitar `int && int`). A emissão como `int` garante compatibilidade com qualquer compilador C.
**Artefatos:** `typeToC()` — retorna `"int"` para `t_bool`; lexer mapeia literais booleanos.
**Impacto:** Operadores `&&`, `||`, `!` exigem `t_bool` internamente, mesmo que no C gerado os operandos sejam `int`.
**Status:** [x] Implementado

---

### 2026-05-31 — Criação implícita de variáveis como `int`

**Categoria:** Semântica
**Contexto:** A Tarefa 5 do curso exigia usar identificadores em expressões antes de declaração explícita.
**Decisão:** `getOrCreateSymbol()` cria implicitamente variáveis do tipo `int` para identificadores não declarados, anotando-as com `implicit = true` e comentário `"declaracao implicita int"` no C gerado.
**Justificativa Técnica:** Alternativa à emissão de erros que quebraria testes legados. Preserva a validade do C gerado sem exigir declaração explícita no programa fonte.
**Artefatos:** `getOrCreateSymbol()` em `sintatico.y`
**Impacto:** Permite programas sem declaração explícita, mas com risco de tipo incorreto. Declaração explícita é sempre preferida.
**Status:** [x] Implementado

---

### 2026-05-31 — Promoção implícita `int → float`

**Categoria:** Sistema de Tipos
**Contexto:** Linguagens imperativas clássicas promovem `int` para `float` automaticamente em contextos mistos.
**Decisão:** Em `makeBinary()` e `makeRelational()`, se o resultado deve ser `float` e um operando é `int`, inserir `Tn = (float) Tk;` antes da operação. Em `makeAssignment()`, se o alvo é `float` e a expressão é `int`, inserir a conversão.
**Justificativa Técnica:** A promoção é explicitada no C intermediário como um cast, tornando o código gerado transparente sobre cada conversão de tipo — importante para fins pedagógicos.
**Artefatos:** `makeBinary()`, `makeRelational()`, `makeAssignment()` em `sintatico.y`
**Impacto:** Aumenta a contagem de temporários em expressões mistas; cada promoção gera um temporário extra.
**Status:** [x] Implementado

---

### 2026-05-31 — Precedência de operadores via diretivas Bison

**Categoria:** Sintaxe
**Contexto:** A gramática tem ambiguidade de precedência sem diretivas explícitas.
**Decisão:** Usar `%left`, `%right` e `%prec UCAST` no Bison para definir a tabela de precedência completa, do menor (atribuição) ao maior (cast unário).
**Justificativa Técnica:** Diretivas de precedência no Bison resolvem conflitos shift/reduce sem modificar a gramática, mantendo as regras de produção limpas.
**Artefatos:** Seção de precedências em `sintatico.y` (linhas 70–78)
**Impacto:** Sem necessidade de gramáticas estratificadas; a gramática de expressões usa uma única regra `E` com todas as produções.
**Status:** [x] Implementado

---

### 2026-05-31 — Suite de testes com diff contra arquivos `.expected`

**Categoria:** Teste
**Contexto:** Necessidade de detectar regressões ao modificar o gerador de código.
**Decisão:** 12 pares `*.mila` / `*.expected` no diretório `tests/`. O Makefile compara a saída do compilador com `diff -u`; qualquer diferença (incluindo espaços) causa falha.
**Justificativa Técnica:** Testes de snapshot (golden files) são eficazes para compiladores porque a saída é determinística e qualquer mudança não intencional é imediatamente detectada.
**Artefatos:** `tests/`, alvo `make test` no Makefile
**Impacto:** Modificações no formato de saída (espaçamento, comentários) exigem atualização dos arquivos `.expected`.
**Status:** [x] Implementado

---

## STATUS DAS ETAPAS

### Etapa I — Expressões e Declarações
- [x] Tipos primitivos: `int`, `float`, `boolean`/`bool`, `char`
- [x] Literais: inteiro, real, booleano, char
- [x] Operadores aritméticos: `+`, `-`, `*`, `/`, `%`
- [x] Operadores relacionais: `<`, `<=`, `>`, `>=`, `==`, `!=`
- [x] Operadores lógicos: `&&`, `||`, `!`
- [x] Cast explícito: `(tipo) expr`
- [x] Declaração de variáveis: `TYPE ID ;`
- [x] Atribuição: `LVALUE = E`
- [x] Coerção implícita `int → float`
- [x] Geração de C de três endereços compilável
- [x] 12 testes com golden files

### Etapa II — Controle de Fluxo e I/O
- [ ] `if` / `else`
- [ ] `while`
- [ ] `do while`
- [ ] `for`
- [ ] `switch` / `case` / `default`
- [ ] `break` / `continue`
- [ ] `read` / `print`
- [ ] Geração de rótulos `L1`, `L2`, ...

### Etapa III — Funções (TBD)
- [ ] Declaração de função
- [ ] Chamada de função
- [ ] `return`
- [ ] Escopo léxico (pilha de tabelas de símbolos)
