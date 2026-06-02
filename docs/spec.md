# Especificação da Linguagem Miila  (v1.0 — Etapa I)

## 1. Visão Geral do Projeto

### 1.1 Contexto Acadêmico

Miila Compiler é desenvolvido para a disciplina de Compiladores da UFRRJ como uma reformulação do projeto FOCA. O objetivo pedagógico é implementar, etapa por etapa, todas as fases clássicas de um compilador: análise léxica, análise sintática, análise semântica e geração de código.

O compilador lê programas escritos na linguagem `mila-lang` (extensão `.mila`) e produz código intermediário em C válido e compilável com GCC.

### 1.2 Objetivo do Compilador

Transformar programas `mila-lang` em código C intermediário com representação explícita de temporários. O C gerado não é o destino final — é um código intermediário de três endereços expresso em sintaxe C, que serve tanto como saída legível quanto como entrada para validação via GCC.

### 1.3 Pipeline de Compilação

```
Programa .mila
    ↓
[Analisador Léxico — Flex / lexico.l]
    ↓  tokens com atributos semânticos
[Analisador Sintático e Semântico — Bison / sintatico.y]
    ↓  atributos de tradução dirigida por sintaxe
[Gerador de Código — printProgram()]
    ↓
Código C intermediário (stdout)
    ↓  (opcional)
[GCC — validação e execução]
```

### 1.4 Ferramentas do Projeto

| Ferramenta | Versão | Papel |
|---|---|---|
| Flex | ≥ 2.6 | Scanner léxico — gera `lex.yy.c` |
| Bison | ≥ 3.x | Parser LALR(1) — gera `sintatico.tab.c` e `sintatico.tab.h` |
| G++ | C++17 | Compila o parser e as funções semânticas |
| GCC | C11 | Valida e executa o C intermediário gerado |
| Make | GNU Make | Automação de build e teste |

---

## 2. Modelo de Geração de Código

### 2.1 Código de Três Endereços em C

O compilador produz código de três endereços expresso em sintaxe C. Cada operação binária gera um temporário explícito. Nenhuma subexpressão é embutida dentro de outra — cada passo de computação ocupa uma linha própria.

**Exemplo:**

```c
// Entrada mila-lang:
// float F; int I; F = I + 2.5;

// Saída C intermediária:
#include <stdio.h>

int main(void) {
    float T1; /* F */
    int T2;   /* I */
    float T3;
    float T4;
    float T5;

    T3 = 2.5;
    T4 = (float) T2;
    T5 = T4 + T3;
    T1 = T5;
    return 0;
}
```

### 2.2 Temporários

- Nomes de temporários: `T1`, `T2`, `T3`, ... sempre em maiúsculo.
- Variáveis do usuário são mapeadas para temporários nomeados; o nome original aparece em comentário.
- Temporários são gerados em ordem de avaliação, da folha para a raiz da árvore de expressão.
- A contagem de temporários é global e nunca reiniciada entre declarações.

### 2.3 Estrutura do Programa Gerado

```c
#include <stdio.h>

int main(void) {
    // Bloco de declarações — todas as variáveis e temporários
    // na ordem em que foram encontrados durante a análise

    // Corpo — sequência de instruções de três endereços

    return 0;
}
```

### 2.4 Atributos de Tradução

Cada nó da gramática carrega um registro `attributes`:

```cpp
struct attributes {
    string label;        // nome do temporário ou variável que contém o resultado
    string translation;  // código C acumulado para computar esse nó
    types  type;         // tipo do resultado
};
```

A tradução é construída de forma ascendente (bottom-up): cada regra gramatical concatena as traduções dos filhos e adiciona a instrução de três endereços própria.

---

## 3. Sistema de Tipos

### 3.1 Tipos Primitivos

| Tipo mila-lang | Alias | Tipo no C intermediário | Notas |
|---|---|---|---|
| `int` | — | `int` | Inteiro de 32 bits |
| `float` | — | `float` | Ponto flutuante simples |
| `boolean` | `bool` | `int` | Emitido como `int` no C gerado |
| `char` | — | `char` | Caractere único |

### 3.2 Representação de Booleanos

O tipo `boolean` (também aceito como `bool`) é representado internamente como `t_bool`. No C intermediário, toda variável ou temporário do tipo `boolean` é declarado como `int`. Os literais `true` e `false` são traduzidos para `1` e `0` respectivamente na fase léxica.

### 3.3 Conversão Implícita

A única conversão implícita permitida é `int → float`. Ela ocorre:

- Em expressões aritméticas mistas: se um operando é `float` e o outro é `int`, o `int` é promovido com `(float)` antes da operação.
- Em atribuição: se a variável-alvo é `float` e a expressão é `int`, uma promoção com `(float)` é inserida.

### 3.4 Cast Explícito

Sintaxe: `(tipo) expr`

O cast explícito é permitido entre qualquer par de tipos não-nulos. O C intermediário emite o cast diretamente:

```c
// Entrada: (float) I
T2 = (float) T1;
```

### 3.5 Regras de Compatibilidade

| Operação | Regra |
|---|---|
| Atribuição `x = e` | `x.type == e.type` ou `x.type == float && e.type == int` |
| `+`, `-`, `*`, `/` | Ambos numéricos (`int` ou `float`) |
| `%` | Ambos `int` |
| `&&`, `\|\|` | Ambos `boolean` |
| `!` | Operando `boolean` |
| `<`, `<=`, `>`, `>=` | Ambos numéricos |
| `==`, `!=` numérico | Ambos numéricos |
| `==`, `!=` mesmo tipo | `char == char` ou `boolean == boolean` |

---

## 4. Elementos Léxicos

### 4.1 Identificadores

Padrão: `[A-Za-z_][A-Za-z0-9_]*`

Identificadores começam com letra ou sublinhado e são seguidos por letras, dígitos ou sublinhados. Distinção de maiúsculas e minúsculas é aplicada.

### 4.2 Literais

| Tipo | Padrão | Exemplos |
|---|---|---|
| Inteiro (`TK_NUM`) | `[0-9]+` | `0`, `42`, `100` |
| Real (`TK_REAL`) | `[0-9]+\.[0-9]+` | `3.14`, `0.5` |
| Booleano (`TK_BOOL`) | `true` \| `false` | `true` → `1`, `false` → `0` |
| Caractere (`TK_CHAR`) | `'char'` com escapes `\n \r \t \\ \' \"` | `'a'`, `'\n'` |

### 4.3 Palavras-chave

| Token | Lexema | Etapa |
|---|---|---|
| `TK_TYPE_INT` | `int` | I |
| `TK_TYPE_FLOAT` | `float` | I |
| `TK_TYPE_BOOLEAN` | `boolean`, `bool` | I |
| `TK_TYPE_CHAR` | `char` | I |
| `TK_IF` | `if` | II |
| `TK_ELSE` | `else` | II |
| `TK_SWITCH` | `switch` | II |
| `TK_CASE` | `case` | II |
| `TK_DEFAULT` | `default` | II |
| `TK_DO` | `do` | II |
| `TK_WHILE` | `while` | II |
| `TK_FOR` | `for` | II |
| `TK_READ` | `read` | II |
| `TK_PRINT` | `print` | II |
| `TK_BREAK` | `break` | II |
| `TK_CONTINUE` | `continue` | II |

### 4.4 Operadores

| Token | Lexema |
|---|---|
| `TK_OP_GREATER_EQUAL` | `>=` |
| `TK_OP_LESS_EQUAL` | `<=` |
| `TK_OP_EQUAL` | `==` |
| `TK_OP_DIF` | `!=` |
| `TK_OP_AND` | `&&` |
| `TK_OP_OR` | `\|\|` |
| Outros | `+ - * / % > < ! =` (char literals) |

### 4.5 Comentários

- Linha: `// até o fim da linha`
- Bloco: `/* ... */` (não aninhados)

Comentários são descartados pelo scanner e não produzem tokens.

---

## 5. Expressões — Etapa I

### 5.1 Precedência e Associatividade

Do menor para o maior precedência:

| Nível | Operadores | Associatividade |
|---|---|---|
| 1 | `=` (atribuição) | Direita |
| 2 | `\|\|` | Esquerda |
| 3 | `&&` | Esquerda |
| 4 | `==` `!=` | Esquerda |
| 5 | `>` `<` `>=` `<=` | Esquerda |
| 6 | `+` `-` | Esquerda |
| 7 | `*` `/` `%` | Esquerda |
| 8 | `!` (unário) | Direita |
| 9 | `(tipo)` (cast) | Direita (UCAST) |

### 5.2 Atribuição

Sintaxe: `LVALUE = E`

`LVALUE` é um identificador. A atribuição verifica compatibilidade de tipos. Se o lado esquerdo é `float` e o lado direito é `int`, uma conversão implícita é inserida automaticamente.

### 5.3 Operadores Aritméticos

`+`, `-`, `*`, `/` exigem operandos numéricos (`int` ou `float`). Se um operando é `float` e o outro é `int`, o `int` é promovido. O resultado é `float` se algum operando é `float`; caso contrário, `int`.

O operador `%` (módulo) exige ambos os operandos como `int`.

### 5.4 Operadores Relacionais

Produzem resultado do tipo `boolean`. Para `<`, `<=`, `>`, `>=`: operandos numéricos com promoção automática. Para `==`, `!=`: operandos numéricos (com promoção) ou mesmo tipo não-numérico (`char == char`, `boolean == boolean`).

### 5.5 Operadores Lógicos

`&&` e `||` exigem ambos os operandos `boolean`. `!` (negação unária) exige operando `boolean`.

### 5.6 Cast Explícito

Sintaxe: `(tipo) expr`. O cast é permitido entre quaisquer dois tipos não-nulos. A instrução C correspondente é emitida diretamente.

---

## 6. Declarações — Etapa I

### 6.1 Declaração Explícita

Sintaxe: `TYPE ID ;`

Registra o identificador na tabela de símbolos com o tipo declarado. Gera um temporário de usuário `Tn` com um comentário anotando o nome original:

```c
int T1; /* A */
```

Declarar um identificador já existente é erro semântico.

### 6.2 Criação Implícita

Para compatibilidade com expressões que usam identificadores não declarados (Tarefa 5), o compilador cria implicitamente variáveis do tipo `int` para identificadores desconhecidos. A declaração implícita é anotada:

```c
int T3; /* X : declaracao implicita int */
```

### 6.3 Tabela de Símbolos

Estrutura `symbol`:

```cpp
struct symbol {
    string name;     // nome original do identificador
    types  type;     // tipo semântico
    string address;  // nome do temporário (T1, T2, ...)
    bool   istemp;   // true se é temporário de computação (sem nome de usuário)
    bool   implicit; // true se foi criado implicitamente
};
```

---

## 7. Controle de Fluxo — Etapa II (Planejado)

### 7.1 if / else

```
if ( E ) BLOCO
if ( E ) BLOCO else BLOCO
```

Geração de código: rótulos `L1`, `L2`; `goto` condicional (`if (!cond) goto L1`).

### 7.2 while

```
while ( E ) BLOCO
```

Geração: rótulo de entrada `L_inicio`, rótulo de saída `L_fim`.

### 7.3 do / while

```
do BLOCO while ( E ) ;
```

Geração: rótulo `L_inicio` antes do corpo; avaliação da condição ao final.

### 7.4 for

```
for ( INIT ; COND ; STEP ) BLOCO
```

Açúcar sintático sobre while com inicialização e incremento.

### 7.5 switch / case

```
switch ( E ) { case LITERAL : COMMANDS ... default : COMMANDS }
```

Geração: comparações explícitas ou tabela de salto, dependendo da densidade dos casos.

### 7.6 break e continue

`break` salta para o rótulo de saída do laço ou switch mais interno. `continue` salta para o rótulo de incremento (for) ou condição (while/do-while).

---

## 8. Entrada e Saída — Etapa II (Planejado)

### 8.1 read

```
read ( ID ) ;
```

Gera uma chamada `scanf` com o especificador de formato adequado ao tipo da variável.

### 8.2 print

```
print ( E ) ;
```

Gera uma chamada `printf` com o especificador de formato adequado ao tipo da expressão.

---

## 9. Funções — Etapa III (Planejado)

### 9.1 Declaração de Função

```
TYPE ID ( PARAMS ) BLOCO
```

Cada função gera uma função C correspondente. Parâmetros são mapeados para temporários. A tabela de símbolos precisa ser estendida para suportar escopo de função.

### 9.2 Chamada de Função

```
ID ( ARGS )
```

Gera código de preparação de argumentos seguido da instrução de chamada.

### 9.3 Retorno

```
return E ;
```

Gera `return label;` onde `label` é o temporário com o resultado de `E`.

---

## 10. Estrutura de um Programa Miila

### 10.1 Formato Geral — Etapa I

Na Etapa I, um programa é uma sequência plana de declarações e expressões separadas por ponto e vírgula. Não há blocos, funções ou controle de fluxo.

```
PROGRAM  →  COMMAND*
COMMAND  →  DECLARATION ';'
          | E ';'
```

### 10.2 Exemplo Completo

```
// Declarações
int A;
float B;

// Expressões
A = 5;
B = (float) A + 1.5;
```

Saída C gerada:

```c
#include <stdio.h>

int main(void) {
    int T1;   /* A */
    float T2; /* B */
    int T3;
    float T4;
    float T5;
    float T6;

    T3 = 5;
    T1 = T3;
    T4 = (float) T1;
    T5 = 1.5;
    T6 = T4 + T5;
    T2 = T6;
    return 0;
}
```

---

## 11. Funções Semânticas — Referência

### 11.1 Funções de Suporte

| Função | Finalidade |
|---|---|
| `newTempName()` | Incrementa contador e retorna `"T" + n` |
| `typeToC(types)` | Converte tipo interno para string C (`"int"`, `"float"`, `"char"`) |
| `typeToText(types)` | Converte para texto legível (`"boolean"` em vez de `"int"`) |
| `isNumeric(types)` | Retorna `true` para `t_int` e `t_float` |
| `canAssign(target, source)` | Valida compatibilidade de atribuição |
| `canExplicitCast(target, source)` | Valida se cast explícito é permitido |

### 11.2 Funções de Criação de Símbolos

| Função | Comportamento |
|---|---|
| `declareSymbol(name, type)` | Cria variável de usuário; erro se duplicada |
| `getOrCreateSymbol(name)` | Recupera símbolo existente ou cria implícito `int` |
| `createTemp(type)` | Cria temporário anônimo para resultado de operação |

### 11.3 Funções Construtoras de Atributos

| Função | Nó gerado |
|---|---|
| `makeLiteral(type, value)` | Literal numérico/booleano/char |
| `makeIdentifier(name)` | Referência a variável |
| `makeAssignment(target, expr)` | Atribuição com coerção implícita |
| `makeBinary(left, op, right)` | Operação binária com promoção |
| `makeRelational(left, op, right)` | Operação relacional com promoção |
| `makeLogicalNot(expr)` | Negação lógica |
| `makeCast(targetType, expr)` | Cast explícito |

### 11.4 Saída

| Função | Comportamento |
|---|---|
| `printProgram(body)` | Emite `#include`, `main()`, declarações, corpo e `return 0` |

---

## 12. Conjunto de Testes — Etapa I

### 12.1 Convenção de Teste

Cada teste consiste em:
- `NN_nome.mila`: programa de entrada em mila-lang
- `NN_nome.expected`: saída C esperada (com espaços exatos)

Comando de execução: `make test` — compara saída real com `.expected` via `diff`.

### 12.2 Testes Existentes

| # | Arquivo | Foco |
|---|---|---|
| 01 | `01_soma.mila` | Aritmética simples, múltiplas somas |
| 02 | `02_operadores.mila` | Todos os operadores aritméticos e precedência |
| 03 | `03_declaracao_temp.mila` | Temporários sem declaração explícita |
| 04 | `04_parenteses.mila` | Agrupamento por parênteses |
| 05 | `05_atribuicao.mila` | Declaração explícita + atribuição |
| 06 | `06_declaracao.mila` | Múltiplas declarações |
| 07 | `07_float.mila` | Literais float e variável float |
| 08 | `08_char_bool.mila` | Tipos `char` e `bool` |
| 09 | `09_relacionais.mila` | Todos os operadores relacionais |
| 10 | `10_logicos.mila` | Operadores lógicos `&&` `\|\|` `!` |
| 11 | `11_conversao_implicita.mila` | Promoção implícita `int → float` |
| 12 | `12_conversao_explicita.mila` | Cast explícito `(float) I` |

### 12.3 Convenção de Escrita de Novos Testes

Ao implementar um novo recurso:
1. Escrever `NN_nome.mila` com o caso mais simples possível.
2. Rodar `make run FILE=tests/NN_nome.mila` e inspecionar manualmente a saída.
3. Salvar a saída inspecionada em `NN_nome.expected`.
4. Confirmar com `make test-NN`.
5. Escrever casos adicionais para bordas e erros.

---

## 13. Etapas de Desenvolvimento

### 13.1 Etapa I — Concluída

**Escopo:**
- Tipos primitivos: `int`, `float`, `boolean`/`bool`, `char`
- Literais: inteiro, real, booleano, caractere
- Operadores: aritméticos, relacionais, lógicos, cast explícito
- Declaração de variáveis
- Atribuição com coerção implícita `int → float`
- Geração de código C de três endereços compilável

**Status:** implementado e testado com 12 testes.

### 13.2 Etapa II — Planejada

**Escopo previsto:**
- Estruturas de controle: `if`, `else`, `while`, `do while`, `for`, `switch`, `case`
- Comandos de I/O: `read`, `print`
- `break` e `continue`
- Rótulos e gotos no C intermediário

**Novo em geração de código:** gerenciamento de rótulos (`L1`, `L2`, ...) para branches e loops.

### 13.3 Etapa III — Planejada

**Escopo previsto:**
- Funções com parâmetros e retorno
- Escopo léxico com pilha de tabelas de símbolos
- Suporte a arrays ou strings (TBD conforme especificação da disciplina)

---

## 14. Regras Semânticas — Resumo

### 14.1 Verificação de Tipos em Tempo de Compilação

| Situação | Ação |
|---|---|
| `&&`/`\|\|` com não-boolean | Erro: "operador X exige operandos boolean" |
| `%` com não-int | Erro: "operador % exige operandos int" |
| `+`/`-`/`*`/`/` com não-numérico | Erro: "operador X exige operandos numericos" |
| `!` com não-boolean | Erro: "operador ! exige operando boolean" |
| `<`/`<=`/`>`/`>=` com não-numérico | Erro de tipos relacional |
| `==`/`!=` com tipos incompatíveis | Erro de tipos relacional |
| Atribuição incompatível | Erro: "nao e possivel atribuir T a S" |
| Cast de/para `t_null` | Erro: "cast invalido" |
| Declaração duplicada | Erro: "variavel ja declarada: X" |

### 14.2 Promoção Automática `int → float`

Ocorre silenciosamente em:
- Operandos de `+`, `-`, `*`, `/` quando o resultado deve ser `float`
- Lado direito de atribuição para variável `float`
- Operandos de `<`, `<=`, `>`, `>=`, `==`, `!=` em contexto numérico misto

A promoção gera um temporário extra: `Tn = (float) Tk;`

### 14.3 Ordem das Declarações no C Gerado

Declarações aparecem no C na ordem em que os símbolos/temporários foram encontrados durante a análise. Isso inclui temporários de cálculo intermediário interspersados com variáveis de usuário, porque a análise é feita em profundidade (avalia filhos antes de criar o nó pai).
