# Planejamento de Desenvolvimento — Compilador Milla

**Disciplina de Compiladores · UFRRJ · Documento v3**

---

## Sumário

1. [O que é a Milla](#1-o-que-é-a-milla)
2. [Princípios de design](#2-princípios-de-design)
3. [Visão técnica do compilador](#3-visão-técnica-do-compilador)
4. [Anatomia da linguagem](#4-anatomia-da-linguagem)
5. [Convenções do código intermediário](#5-convenções-do-código-intermediário)
6. [Etapas de entrega](#6-etapas-de-entrega)
7. [Arquitetura do código-fonte do compilador](#7-arquitetura-do-código-fonte-do-compilador)
8. [Sistema de testes integrado](#8-sistema-de-testes-integrado)
9. [Roteiro de implementação](#9-roteiro-de-implementação)
10. [Divisão de trabalho na equipe](#10-divisão-de-trabalho-na-equipe)
11. [Decisões em aberto e extras](#11-decisões-em-aberto-e-extras)
12. [Referências](#12-referências)
13. [Palavras reservadas](#13-palavras-reservadas)
14. [Checklist detalhado da Etapa II](#14-checklist-detalhado-da-etapa-ii)
15. [Programa exemplo completo (Etapa II)](#15-programa-exemplo-completo-etapa-ii)

---

## 1. O que é a Milla

A Milla é uma linguagem de programação imperativa, estaticamente tipada, projetada como trabalho da disciplina de Compiladores da UFRRJ. Apesar do contexto acadêmico, ela não é uma linguagem de brinquedo — desde o começo do projeto, tomamos as decisões de design pensando em **uma linguagem que valha a pena escrever**, não apenas em um exercício para satisfazer o enunciado. Esse compromisso aparece em cada escolha: aceitamos um pouco mais de trabalho de implementação para entregar uma linguagem que tem personalidade e que conversa com o estado da arte do design de linguagens.

A Milla nasce da combinação de duas tradições. A primeira é a do **scripting tipado prático**, herdada de Kotlin e Crystal — linguagens que provam que tipos estáticos não precisam vir acompanhados de verbosidade. A segunda é a da **expressividade Ruby**, que valoriza o programador acima da máquina e busca código que se leia como prosa. A Milla tenta capturar o melhor dos dois: o programador comum, escrevendo o caso geral, recebe a brevidade do Ruby; quando precisa de controle fino — declarar tipos explicitamente, especificar comportamento — a linguagem oferece os mecanismos sem atrapalhar.

O compilador da Milla traduz programas escritos na linguagem para **código de três endereços (TAC)** compilável como C válido. Essa decisão é deliberada: o TAC gerado pode ser passado direto ao GCC para verificação, o que serve tanto como mecanismo de validação durante o desenvolvimento quanto como demonstração concreta de que a tradução está correta. Não há máquina virtual, não há runtime grande, não há mágica — o que sai do compilador é código C legível.

## 2. Princípios de design

Sempre que tivemos dúvida sobre uma decisão, voltamos a três princípios que se mostraram suficientes para guiar todo o resto.

**Simplicidade no caso geral, especificidade quando o programador quiser.** A Milla não exige declaração de tipo, mas aceita; não exige separador de comandos, mas aceita; usa inferência por padrão, mas permite forçar. O programador que quer rapidez escreve `x = 10` e segue a vida. O programador que precisa de controle escreve `int x = 10` e tem o que precisa. Nenhum dos dois caminhos é "errado", e a linguagem não pune nenhum.

**Uma regra, aplicada coerentemente.** Quando uma decisão funciona bem em uma construção, ela vale em todas. A regra de parênteses na condição — *sem* parênteses exige bool estrito, *com* parênteses ativa truthiness — vale igual em `if`, `while`, `do-while`. As chaves são obrigatórias em todas as construções de bloco. O newline funciona como separador de statement no mesmo conjunto de circunstâncias em todo o programa. Essa coerência tornou a especificação consideravelmente menor do que seria de outro modo.

**O caso difícil paga seu próprio preço, o caso fácil não.** Sempre que aparecia uma decisão "mais poderosa, mas mais cara", optamos por **manter o caso fácil trivial e oferecer uma rota explícita para o caso difícil**. O `foreach` com `ci` funciona lindamente em um nível; aninhou e precisa do externo, troca para `for...in` nomeado. O `break` simples sai do laço atual; quer sair de tudo, escreve `break all`. Globais são acessíveis dentro de funções sem cerimônia, mas modificá-las emite warning sugerindo passar por parâmetro. Esse padrão se repete porque a alternativa — embutir complexidade em todo lugar para suportar o caso raro — corrompe o caso comum, e a Milla preferiu não fazer isso.

## 3. Visão técnica do compilador

O compilador segue o pipeline clássico de quatro fases — análise léxica, análise sintática, análise semântica e geração de código intermediário — descrito no Dragon Book (Aho, Lam, Sethi, Ullman) e em *Introdução à Compilação* (Elsevier). As tecnologias são Flex (Lex) para o lexer, Bison (Yacc) para o parser, e C/C++ para a tabela de símbolos, análise semântica e geração de código. A compilação é orquestrada por um Makefile que respeita a ordem obrigatória: Bison gera o header de tokens antes de Flex incluí-lo, e ambos são compilados junto com os módulos restantes.

A invocação do compilador segue um padrão simples:

```
$ milla programa.milla
Compiled - 0 erros, 0 warnings, 87 tokens, 12 vars, 6 temps
Olá, mundo!

$ milla programa.milla --silent
Olá, mundo!

$ milla programa.milla --tac
int T1;
int T2;
T1 = 10;
T2 = T1 + 1;
A = T2;
```

A mensagem padrão de compilação carrega métricas úteis tanto para depuração quanto para o relatório acadêmico: número de erros, warnings, tokens consumidos, variáveis do usuário declaradas e temporários gerados. A flag `--silent` suprime essa linha e mostra apenas a saída do programa, útil para integração com scripts e com o sistema de testes. A flag `--tac` exibe o código intermediário, essencial durante o desenvolvimento e poderosa nas demonstrações.

O compilador é estritamente *batch*: compila um arquivo de cada vez, processa do início ao fim, emite resultado. Não há REPL, não há servidor de linguagem, não há observação de mudanças — escopo intencionalmente enxuto.

## 4. Anatomia da linguagem

### 4.1 Tipos primários

A Milla tem seis tipos primários: `int`, `float`, `double`, `char`, `string` e `bool`. Não existe `any` ou outra forma de tipagem dinâmica — toda variável tem um tipo concreto, conhecido em tempo de compilação. A inferência cobre o caso de "não querer declarar"; a declaração explícita cobre o caso de "querer controle".

```milla
x = 10              // x é int, inferido pelo literal
y = 3.14            // y é double (literal decimal padrão)
z = 'A'             // z é char
nome = "Milla"      // nome é string
ativo = true        // ativo é bool

int contador = 0    // declaração explícita; força o tipo
float pi = 3.14     // explicitamente float em vez do default double
```

O tipo é fixado na **primeira atribuição** e não muda depois. Tentar `x = "abc"` após `x = 10` é erro de compilação. Esse é o trade-off central da Milla: você não declara, mas também não pode mudar de ideia. Na prática, isso elimina toda uma classe de bugs sutis que linguagens dinâmicas sofrem, sem cobrar o preço de declarações em todo lugar.

### 4.2 Literais

Literais inteiros, de ponto flutuante, char e string seguem convenções familiares com pequenas particularidades importantes:

| Sintaxe | Significado |
|---|---|
| `42` | inteiro |
| `3.14` | double (literal decimal sem sufixo) |
| `'a'` | caractere (apenas um caractere ou escape) |
| `"abc"` | string |
| `"""..."""` | string multi-linha (preserva quebras de linha) |
| `true`, `false` | booleanos |
| `null`          | — (truthiness: valor falso, palavra reservada) |
| identificador sem aspas | nome de variável; erro se não declarada |

A distinção entre `'a'` (char) e `"a"` (string) é central. Não existe coerção implícita entre os dois — concatenar `'a' + 'b'` resulta numa string `"ab"`, mas `'a' + 1` é erro de tipo. Quem quer o valor ASCII usa `ord('a')` explicitamente.

Strings suportam sete sequências de escape (`\n`, `\t`, `\\`, `\"`, `\'`, `\0`, `\r`) e **interpolação** com sintaxe `#{expr}`, herdada de Ruby:

```milla
nome = "Caio"
mout("Olá, #{nome}, próximo: #{idade + 1}")
```

A interpolação aceita qualquer expressão da linguagem, inclusive expressões mais elaboradas como `if`-expressões. Ela funciona tanto em strings de uma linha quanto em strings multi-linha com aspas triplas.

### 4.3 Operadores

Os operadores são os clássicos, com regras de precedência alinhadas com C/Java:

- **Aritméticos:** `+`, `-`, `*`, `/`, `%`
- **Relacionais:** `<`, `<=`, `>`, `>=`, `==`, `!=`
- **Lógicos:** `&&`, `||`, `!`
- **Atribuição:** `=`
- **Concatenação:** o `+` aplicado a strings ou chars resulta em string

A coerção implícita segue a hierarquia natural `int → float → double`. Em expressões mistas, o operando "menor" é promovido ao tipo do "maior":

```milla
int i = 5
double d = 2.5
resultado = i + d       // resultado é double; i é promovido
```

A promoção é emitida explicitamente no TAC como instrução de cast, o que mantém o código intermediário verificável e legível. A coerção entre tipos compatíveis acontece silenciosamente; conversões entre tipos incompatíveis (string ↔ int, por exemplo) exigem cast explícito ou geram erro semântico.

**Tabela de combinações de tipos para operadores aritméticos e concatenação:**

| Operação         | Resultado                        |
|------------------|----------------------------------|
| int op int       | int                              |
| int op float     | float (promoção implícita)       |
| int op double    | double (promoção implícita)      |
| float op float   | float                            |
| float op double  | double (promoção implícita)      |
| double op double | double                           |
| char + char      | string (concatenação)            |
| char + string    | string (concatenação)            |
| string + char    | string (concatenação)            |
| string + string  | string (concatenação)            |
| char op int      | ERRO (tipo incompatível)         |
| string op int    | ERRO (tipo incompatível)         |
| bool op qualquer | ERRO (exceto `&&`, `||`, `!`)    |

### 4.4 Léxico: separadores e comentários

A Milla usa **quebra de linha como separador de statement**, no estilo Kotlin, Swift e Go. O ponto-e-vírgula é opcional e serve apenas para juntar comandos numa única linha:

```milla
x = 10
y = 20                 // newline separa
a = 1; b = 2; c = 3    // ; junta na mesma linha
```

A regra para o lexer é precisa: ao encontrar `\n`, ele emite o token `NEWLINE` (separador), **exceto** em quatro situações onde a continuação de expressão deve ser mantida:

1. Dentro de `(`, `[`, `{` ainda não fechados (rastreio de profundidade de delimitadores).
2. Logo após um operador binário (`+`, `-`, `*`, `/`, `%`, `==`, `!=`, `<`, `>`, `<=`, `>=`, `&&`, `||`, `=`).
3. Logo após uma vírgula.
4. Logo após um abre-delimitador qualquer.

A convenção estilística da Milla é colocar o operador binário **no fim da linha anterior**, não no começo da seguinte:

```milla
total = preco +              // operador no fim → o lexer ignora o \n
        imposto +
        frete                // último token é identificador → \n separa
```

Comentários são reconhecidos em duas formas: `//` para linha (consome até o próximo `\n`) e `/* ... */` para bloco. O `#` foi deliberadamente *não* adotado como comentário para liberá-lo como marcador de interpolação de string.

### 4.5 Variáveis, escopo e blocos

Toda variável vive em um escopo. Escopos são criados pelas chaves `{` e `}` — abrir uma chave empilha um novo escopo, fechar a chave o desempilha. A tabela de símbolos do compilador é, literalmente, uma pilha de mapas: cada bloco aninhado adiciona uma camada por cima.

A regra fundamental para atribuição é simples e gera o comportamento esperado intuitivamente: **ao atribuir `nome = valor`, o compilador procura `nome` na pilha de escopos visíveis**. Se encontrar, é uma reatribuição no escopo onde estava. Se não encontrar, é uma criação no escopo atual (o mais interno).

```milla
x = 10                  // criada no escopo global
if cond {
    x = 20              // x existe no global → reatribui (não cria nova)
    y = 5               // y não existe → cria no escopo do if
}
mout(x)                 // 20 (foi reatribuída)
mout(y)                 // erro: y morreu com o if
```

Quando o programador quer deliberadamente criar uma variável local que **sombreie** uma externa do mesmo nome, ele usa declaração explícita:

```milla
x = 10
if cond {
    int x = 20          // declaração explícita → cria local, sombreia
    mout(x)             // 20 (a local)
}
mout(x)                 // 10 (a global continua intocada)
```

Variáveis no nível raiz do programa são **globais**. Funções acessam globais transparentemente — leem e escrevem sem cerimônia — mas a Milla emite **warning** quando uma função modifica uma global, sugerindo que talvez fosse melhor passar como parâmetro. O programa continua compilando; é apenas uma sugestão de estilo capturada em tempo de compilação.

### 4.6 Controle de fluxo

#### Condicional `if`

O `if` da Milla segue o modelo Kotlin/Rust: chaves obrigatórias mesmo para corpo de uma linha, e `else if` (sem keyword nova como `elsif` ou `elif`). A grande característica é que o `if` **é uma expressão** — retorna o valor do braço executado:

```milla
// como statement
if x > 0 {
    mout("positivo")
} else if x == 0 {
    mout("zero")
} else {
    mout("negativo")
}

// como expressão
sinal = if x > 0 { "positivo" } else if x == 0 { "zero" } else { "negativo" }
```

A condição segue a regra de parênteses unificada da Milla. Sem parênteses, a condição deve ser estritamente `bool`. Com parênteses, ativa-se a *truthiness*: qualquer tipo é aceito, e a falsidade é definida por `0`, `0.0`, `'\0'`, `""`, `false` ou `null`; tudo mais é verdadeiro.

```milla
if x > 0 { ... }        // sem parênteses → exige bool
if (x) { ... }          // com parênteses → truthiness (x ≠ 0)
if (nome) { ... }       // truthiness em string → nome não vazia
```

#### Laços `for`, `while`, `do-while`

A Milla oferece três formas de `for`, cada uma com papel distinto.

A primeira é o **`for` clássico estilo C**, sem parênteses, para iterações contadas com controle total:

```milla
for i = 0; i < 10; i = i + 1 {
    mout(i)
}
```

A segunda é o **`for...in` nomeado**, para iteração sobre coleções com variável batizada — e tem variante com índice opcional, no estilo do `enumerate` de Python ou do `range` de Go:

```milla
for x in lista { mout(x) }              // só o valor
for i, x in lista { mout("#{i}: #{x}") } // índice e valor
```

A terceira é o **`foreach`**, varredura anônima sobre estruturas inteiras. Dentro do corpo, a palavra reservada `ci` (de *current item*) refere-se ao elemento atual. O `ci` se liga sempre ao `foreach` **mais interno**; quando há aninhamento e o programador precisa do externo, ele troca o externo por um `for...in` nomeado.

```milla
foreach "batata" { mout(ci) }            // imprime b, a, t, a, t, a

foreach palavras {                        // varre a lista de palavras
    foreach palavras {                    // varre de novo (cruzamento)
        mout(ci)                          // ci se refere ao foreach interno
    }
}

for p in palavras {                       // externo nomeado quando necessário
    foreach letras { mout(p + ci) }
}
```

O `for` em todas as três formas itera sobre **string**, **vetor** e **matriz**, e é statement puro (não retorna valor).

> **Detalhe crítico de implementação — `continue` no for C-style:** em `for i=0; i<10; i=i+1 { }`, o `continue` deve saltar para o label de **update** (o incremento `i=i+1`), não para o label de **topo** da condição. Se pular para o topo, o incremento é ignorado e o laço pode entrar em loop infinito. O codegen mantém três labels para o for C-style: `L_top` (condição), `L_update` (incremento) e `L_end` (saída). `break` → `L_end`; `continue` → `L_update`.

O `while` e o `do-while` seguem o modelo esperado, herdando a mesma regra de parênteses do `if`:

```milla
while x < 10 {
    x = x + 1
}

do {
    x = x + 1
} while x < 100
```

O controle de laços usa `break` e `continue` no nível 1 (sai do laço imediato, vai para a próxima iteração imediata). A Milla também oferece `break all` como **extra**, que sai de toda a pilha de laços de uma vez — útil em buscas em matrizes onde encontrar o item significa terminar tudo.

#### Seleção: `match` (no lugar do `switch` clássico)

A Milla substitui o `switch` clássico por **`match`**, uma construção de pattern matching moderna sem fall-through. A justificativa: o `switch` do C carrega três pecados de design (fall-through implícito, sobrecarga do `break`, comparação só por igualdade) que linguagens modernas resolveram. Optamos pela versão moderna porque ela é mais segura, mais expressiva, e rende um parágrafo melhor no relatório acadêmico.

```milla
match x {
    1, 2, 3 -> mout("baixo"),
    10      -> mout("dez"),
    _       -> mout("outro")
}
```

Cada braço usa `->` para separar o padrão do corpo. Vários valores podem compartilhar um braço pela vírgula interna. O sublinhado `_` é o catchall. A vírgula entre braços é opcional quando há quebra de linha. O corpo pode ser um statement simples ou um bloco com chaves para múltiplos statements.

Como o `if`, o `match` **é uma expressão** e retorna o valor do braço executado. Quando usado como expressão, **o catchall `_` é obrigatório** — a Milla exige exaustividade em tempo de compilação para garantir que toda execução produza valor.

```milla
descricao = match x {
    1 -> "um",
    2 -> "dois",
    _ -> "muitos"            // obrigatório quando match é expressão
}
```

### 4.7 Entrada e saída

A entrada e a saída são feitas por funções built-in:

- **`min(...)`** — entrada simples de um valor tipado
- **`scan(...)`** — entrada com formatação ou leitura de linha
- **`print(...)`** — saída padrão
- **`mout(...)`** — saída alternativa, equivalente ao `cout` de C++
- **`log(...)`** — saída para depuração
- **`error(...)`** — saída de erro

O par `min`/`mout` carrega a personalidade da Milla — é a "assinatura" da linguagem que aparece nos exemplos canônicos. O par `scan`/`print` carrega o uso real, com nomes universais. Programas idiomáticos da Milla podem usar qualquer combinação; a documentação oficial favorece `print` para saída ordinária e `mout` quando o autor quer o sabor mais característico da linguagem.

A Milla **não tem print implícito**. Programas silenciosos por padrão; só imprimem o que for explicitamente passado para uma função de saída. Essa decisão foi tomada após considerar alternativas (Modelo Python/Ruby de REPL puro) e descartá-las pelo custo de surpresas em programas reais.

### 4.8 Funções ASCII utilitárias

A Milla oferece `ord` e `chr` para o caso comum de obter valor ASCII e vice-versa. O `ord` tem comportamento agregador: quando recebe uma string de mais de um caractere, retorna a **soma** dos valores ASCII dos caracteres. O caso clássico de "valor de um único caractere" é o caso particular `n=1` dessa regra:

```milla
ord('A')           // 65
ord("A")           // 65 (string de 1 char)
ord("alo")         // 97 + 108 + 111 = 316
ord[0]("alo")      // 97 (indexação posicional)
chr(65)            // 'A'
```

A indexação `ord[N](str)` retorna o valor ASCII do N-ésimo caractere apenas, oferecendo uma forma natural de acessar posições específicas sem precisar quebrar a string.

## 5. Convenções do código intermediário

O TAC emitido pela Milla é **código C válido**. Isso não é metáfora — o arquivo `.tac` resultante de uma compilação bem-sucedida pode ser passado direto ao GCC para verificação, e o programa C resultante deve produzir a mesma saída do programa Milla original.

As convenções foram herdadas e aperfeiçoadas em relação ao plano original:

| Aspecto | Convenção |
|---|---|
| **Temporários** | Nomeados `T1`, `T2`, `T3`...; **maiúsculas** (mudança consciente em relação ao predecessor FOCA, que usava minúsculas). |
| **Declarações primeiro** | Todas as declarações (variáveis do usuário e temporários) aparecem antes de qualquer instrução, no estilo C89. |
| **Mapeamento de variáveis** | Cada variável do usuário tem um temporário associado na tabela de símbolos. `A` → `T1`, `B` → `T2`, etc. |
| **`bool` não existe no TAC** | Booleanos são representados como `int`: `true=1`, `false=0`. Macros `#define true 1` e `#define false 0` podem ser emitidas no preâmbulo. |
| **Conversões explícitas** | Tanto coerções implícitas quanto casts explícitos aparecem como instruções TAC: `T2 = (float) T1;`, `T3 = (double) T2;`. |
| **Strings** | Strings literais e variáveis são `char*` no TAC. Concatenação é traduzida para chamadas a funções de runtime (`milla_strcat`, etc). |

O formato das instruções:

| Instrução | Formato | Exemplo |
|---|---|---|
| Atribuição binária | `Tn = Tx op Ty;` | `T3 = T1 + T2;` |
| Atribuição de cópia | `Tn = Tx;` | `T5 = T4;` |
| Conversão | `Tn = (tipo) Tx;` | `T2 = (float) T1;` |
| Desvio condicional | `ifFalse Tn goto Lx;` | `ifFalse T3 goto L2;` |
| Desvio incondicional | `goto Lx;` | `goto L5;` |
| Label | `Lx:` | `L3:` |
| Parâmetro | `param Tn;` | `param T2;` |
| Chamada | `call f, n;` | `call soma, 2;` |
| Retorno | `return Tn;` | `return T7;` |
| Acesso a vetor | `Tn = a[Ti];` / `a[Ti] = Tn;` | `T1 = v[2];` |

> **Preâmbulo bool:** quando o programa usa `bool`, emitir antes das declarações: `#define true 1` e `#define false 0`.

### 5.1 Padrões TAC por construção de controle

**if / else:**
```
  T_cond = ... avalia condição ...
  ifFalse T_cond goto L_else
  ... corpo then ...
  goto L_end
L_else:
  ... corpo else ...
L_end:
```

**while:**
```
L_top:
  T_cond = ... avalia condição ...
  ifFalse T_cond goto L_end
  ... corpo ...
  goto L_top
L_end:
```

**do-while:**
```
L_top:
  ... corpo ...
  T_cond = ... avalia condição ...
  ifFalse T_cond goto L_end
  goto L_top
L_end:
```

**for C-style** — `for i = 0; i < N; i = i + 1 { }`:
```
  T_i = 0                        ← init
L_top:
  T_cond = T_i < N               ← condição
  ifFalse T_cond goto L_end
  ... corpo ...                  ← break → goto L_end; continue → goto L_update
L_update:
  T_i = T_i + 1                  ← update
  goto L_top
L_end:
```
> `continue` vai para **L_update** (não L_top) para garantir que o incremento rode.

**for...in** — `for x in lista { }`:
```
  T_idx = 0
  T_len = milla_len(T_lista)
L_top:
  T_cond = T_idx < T_len
  ifFalse T_cond goto L_end
  T_x = milla_get(T_lista, T_idx)
  ... corpo (T_x disponível) ...
  T_idx = T_idx + 1
  goto L_top
L_end:
```

**foreach** — mesmo padrão de for...in com `T_ci` no lugar de `T_x`.

**match:**
```
  T_x = ... valor de match ...
  T_cmp = T_x == val1
  ifFalse T_cmp goto L_arm2
  ... corpo do braço 1 ...
  goto L_end
L_arm2:
  T_cmp = T_x == val2
  ...
L_default:
  ... corpo do _ ...
L_end:
```

**if / match como expressão** — cada braço armazena resultado em `T_result` comum:
```
  ... avalia condição ...
  ifFalse T_cond goto L_else
  T_result = valor_then
  goto L_end
L_else:
  T_result = valor_else
L_end:
  // T_result contém o valor da expressão
```

**break / continue / break all:**
```
break      → goto L_end_do_laço_atual       (loop_stack.back().end)
continue   → goto L_top_ou_L_update         (loop_stack.back().top — ou L_update no for)
break all  → goto L_end_do_laço_mais_externo (loop_stack[0].end)
```

### 5.2 Estruturas do codegen

```c
int  temp_counter = 0;     // incrementado a cada new_temp()
int  label_counter = 0;    // incrementado a cada new_label()

char *new_temp();   // retorna "T1", "T2", ...
char *new_label();  // retorna "L1", "L2", ...

typedef struct LoopLabels {
    char *top;   // label de continue (topo do laço ou L_update no for C-style)
    char *end;   // label de break (saída do laço)
} LoopLabels;

LoopLabels loop_stack[64];
int        loop_stack_top = -1;
```

Operadores compostos são **desaçucarados** antes do codegen:
```
A += expr  →  T_lhs = A; T_rhs = expr; T_res = T_lhs + T_rhs; A = T_res;
```

Operadores unários:
```
-x    →  T1 = x; T2 = -T1;
!x    →  T1 = x; T2 = !T1;
++x   →  T1 = x; T2 = T1 + 1; x = T2;   (resultado = T2)
x++   →  T1 = x; T2 = T1 + 1; x = T2;   (resultado = T1)
```

## 6. Etapas de entrega

A disciplina prevê três etapas de entrega progressivas. O estado atual do projeto coloca a equipe trabalhando na **transição da Etapa I para a Etapa II**, com toda a especificação da Etapa II já desenhada e pronta para implementação.

### 6.1 Etapa I — Fundação Expressiva (concluída, com correções pendentes)

A Etapa I cobre o pipeline de expressões: tipos primários, operadores aritméticos, relacionais e lógicos, declaração de variáveis, atribuição, conversão implícita e explícita. Está estruturada em 12 tarefas estritamente incrementais, descritas em detalhe no plano original; aqui sintetizamos por bloco.

**O que a Etapa I implementa:**
- Expressões aritméticas com todos os operadores e precedência correta.
- Tipos `int`, `float`, `char`, `bool` (e agora `double`, adicionado para a Etapa II).
- Declaração explícita e inferência por primeira atribuição.
- Bloco de declarações de temporários antes das instruções.
- Conversão implícita seguindo a tabela de coerção.
- Cast explícito com sintaxe `(tipo) expr`.

**Correções pendentes da Etapa I que entram no escopo da Etapa II:**

1. **Coerção implícita ampla**: a tabela de coerção precisa ser estendida para incluir `double` e cobrir todas as combinações entre os seis tipos. Hierarquia: `int → float → double`. Combinações com `char`, `string`, `bool` exigem cast explícito.
2. **Regra de booleano revisada**: a regra de truthiness com parênteses que adotamos para `if`/`while`/`do-while` substitui a antiga "boolean estrito". Implementação: bool estrito por padrão; truthiness ativada apenas quando a condição está entre parênteses.

### 6.2 Etapa II — Controle de Fluxo, Escopo e Strings (escopo atual)

A Etapa II é onde a Milla deixa de ser uma calculadora glorificada e se torna uma linguagem real. É também o estágio onde tomamos as decisões mais filosóficas — escopo, pattern matching, sintaxe de laços, separação de comandos. Tudo está fechado conceitualmente e pronto para virar código.

**Escopo da Etapa II:**

- **Lexer estendido**: novos tokens para `if`, `else`, `while`, `for`, `do`, `match`, `_`, `break`, `continue`, `in`, `ci`, `true`, `false`, `null`. Separação de statements por newline com as regras de continuação descritas em 4.4. Strings com escapes, multi-linha (`"""..."""`) e interpolação (`#{...}`).
- **Gramática de bloco**: `{ }` com escopo aninhado obrigatório em toda construção de bloco.
- **Tabela de símbolos como pilha de escopos**: push/pop a cada bloco, escopo global como raiz permanente, regra de busca para reatribuição vs criação.
- **Comandos de controle de fluxo**: `if`/`else if`/`else` (statement e expressão), `while`, `do/while`, `for` em três formas, `match`.
- **Controle de laços**: `break`, `continue` (obrigatório), e `break all` (extra de bônus).
- **Comandos de entrada e saída**: implementação das seis funções (`min`, `scan`, `print`, `mout`, `log`, `error`).
- **Operadores compostos**: `+=`, `-=`, `*=`, `/=`, `%=`, desaçucarados para `A = A op expr` no TAC (puxados para a Etapa II).
- **Operadores unários**: `++`, `--` (pré e pós-fixo) (puxados para a Etapa II).
- **Geração de TAC** para todas as construções acima, com labels e goto adequados.

A ordem de implementação recomendada dentro da Etapa II está em [§9 Roteiro de implementação](#9-roteiro-de-implementação).

### 6.3 Entrega Final — Funções, Matrizes, Operadores Compostos

A Entrega Final fecha a linguagem com o que ainda falta para programas Milla reais serem viáveis: subrotinas, estruturas de dados indexadas, e o açúcar sintático que falta dos operadores aritméticos. As decisões filosóficas dessa etapa **ainda estão em aberto** — funções têm vários eixos de design (sintaxe da assinatura, retorno múltiplo, defaults, argumentos nomeados, closures) que precisam de uma sessão própria de discussão.

**Escopo previsto (sujeito a refinamento):**

- **Funções**: declaração com parâmetros tipados, corpo e retorno; verificação semântica de assinatura; recursão; TAC com `param`, `call`, `return`. Decisões em aberto: palavra-chave (`def` vs `fn` vs `fun`), inferência de tipo de retorno, função como expressão, retorno múltiplo.
- **Vetores e matrizes**: declaração `A[]` para vetor e `A[][]` para matriz, com semântica de `std::vector` (tamanho dinâmico); acesso indexado `A[i]` e `A[i][j]`; TAC com `T = a[i]; a[i] = T`.
- **Inicialização**: variáveis e matrizes podem ser inicializadas na declaração (`int v[] = {1, 2, 3}`).
- **Operadores compostos**: `+=`, `-=`, `*=`, `/=`, `%=`, desaçucarados para `A = A op expr`.
- **Operadores unários**: `++`, `--` (pré e pós-fixo), `-x`, `!x`. (Esses foram puxados para a Etapa II por decisão tomada em sessão.)
- **Detecção e recuperação de erros**: mensagens com linha e coluna, recuperação no parser para listar múltiplos erros, severidade `error` vs `warning`.

**Extras planejados (alguns já decididos como bônus):**
- `break all` (sair de todos os laços aninhados) — *decidido como extra*.
- Interpolação de strings — *promovida para Etapa II*.
- Indexação `ord[N](str)` — *promovida para Etapa II*.
- Exponenciação `**` como operador nativo.
- `foreach` sobre matrizes inteiras (já no design da Etapa II).
- Argumentos nomeados em funções.
- Inferência de tipo de retorno em funções.

## 7. Arquitetura do código-fonte do compilador

A organização do código segue a separação clássica por fase, com cada módulo encapsulando sua responsabilidade:

```
milla-compiler/
├── src/
│   ├── lexer.l           # Flex: tokens, literais, escapes, interpolação
│   ├── parser.y          # Bison: gramática, ações semânticas, precedência
│   ├── ast.c / ast.h     # ASA: NodeKind, DataType, ponteiros left/right/next
│   ├── symtable.c/.h     # Tabela de símbolos: pilha de escopos, busca/inserção
│   ├── semantic.c/.h     # Verificação de tipos, coerção, exaustividade do match
│   ├── codegen.c/.h      # Geração de TAC: declarações + instruções + labels
│   └── main.c            # CLI, flags --silent/--tac, mensagem Compiled - ...
├── tools/
│   └── test_runner.py    # Runner do sistema de testes (ver §8)
├── tests/                # Suite de testes organizada por fase (ver §8)
├── docs/
│   ├── planejamento_v3.md              # Este documento
│   ├── relatorio.md                    # Relatório de implementação e decisões
│   └── spec.md                         # Referência técnica da Etapa I
├── Makefile
└── README.md
```

A ordem do Makefile é obrigatória: Bison roda primeiro para gerar `parser.tab.c` e `parser.tab.h`; Flex roda em seguida para gerar `lex.yy.c` (que inclui o header de tokens); GCC/G++ compila todos os módulos juntos em um binário `milla` (ou `milla.exe` no MSYS2).

A estrutura do nó da ASA é simples e uniforme:

```c
typedef enum {
    // Expressões
    NODE_EXPR, NODE_LITERAL, NODE_IDENT,
    NODE_ASSIGN, NODE_BINOP, NODE_UNOP, NODE_CAST,
    // Controle de fluxo
    NODE_IF, NODE_WHILE, NODE_DO_WHILE,
    NODE_FOR_C, NODE_FOR_IN, NODE_FOR_IN_IDX, NODE_FOREACH,
    NODE_MATCH, NODE_MATCH_ARM,
    NODE_BREAK, NODE_CONTINUE, NODE_BREAK_ALL,
    // Blocos e declarações
    NODE_BLOCK, NODE_VAR_DECL,
    // I/O
    NODE_PRINT, NODE_MOUT, NODE_LOG, NODE_ERROR, NODE_MIN, NODE_SCAN,
    // Funções (Etapa III)
    NODE_FUNC_DECL, NODE_CALL, NODE_RETURN,
    // Coleções (Etapa III)
    NODE_ARRAY_DECL, NODE_ARRAY_ACCESS,
    // Strings
    NODE_STRING_LIT, NODE_STRING_INTERP,
} NodeKind;

typedef enum {
    TYPE_INT, TYPE_FLOAT, TYPE_DOUBLE,
    TYPE_CHAR, TYPE_STRING, TYPE_BOOL,
    TYPE_VOID, TYPE_UNKNOWN
} DataType;

struct ASTNode {
    NodeKind kind;
    DataType type;
    char *name;
    union { int i; double d; char c; char *s; int b; } literal;
    struct ASTNode *left;
    struct ASTNode *right;
    struct ASTNode *next;
    int line, col;
};
```

A tabela de símbolos é a pilha de mapas descrita em 4.5:

```c
typedef struct Symbol {
    char *name;
    DataType type;
    char *temp_name;      // nome do temporário associado (T1, T2, ...)
    int declared_at_line;
    int is_explicit;      // 1 se declarado com tipo, 0 se inferido
} Symbol;

typedef struct Scope {
    HashMap *symbols;
    struct Scope *parent;
} Scope;

Scope *current_scope;     // topo da pilha
Scope *global_scope;      // raiz permanente
```

Ambiente de build: **Windows com MSYS2 (UCRT64)**. Flex e Bison devem ser instalados com `pacman -S flex bison`, **sem** o prefixo `mingw-w64-ucrt-x86_64-` (que causa erros silenciosos de instalação — aprendemos isso pelo caminho doloroso).

## 8. Sistema de testes integrado

O sistema de testes da Milla é parte integrante do projeto, não um anexo. Cada feature da linguagem nasce com seus testes; cada bug fixado vira um teste de regressão. A arquitetura escolhida é **Nível 2** — testes granulares por fase do compilador, com testes grossos de integração, organização por polaridade (passa/falha), runner em Python, e relatório de cobertura cruzando features versus fases.

### 8.1 Estrutura de pastas

```
tests/
├── lexer/          # tokenização (fase 1)
│   ├── pass/
│   │   ├── 01_comments/
│   │   ├── 02_strings/
│   │   └── ...
│   └── fail/
├── parser/         # gramática (fase 2)
│   ├── pass/
│   └── fail/
├── semantic/       # análise semântica (fase 3)
│   ├── pass/
│   └── fail/
├── codegen/        # geração de TAC (fase 4)
│   ├── pass/
│   └── fail/
└── integration/    # programas reais end-to-end
    ├── pass/
    └── fail/
```

Cada teste é uma pasta com 2 a 4 arquivos:

```
tests/parser/pass/02_if/01_simple_if/
├── input.milla      # programa a compilar (obrigatório)
├── expected.out     # stdout esperado da execução (opcional)
├── expected.err     # stderr esperado da compilação (opcional)
└── expected.tac     # TAC esperado (opcional, comparação tolerante a espaços)
```

O runner compara as três saídas e marca `PASS` se todas baterem, `FAIL` com diff colorido se alguma diverge. Testes em `pass/` devem compilar com sucesso; testes em `fail/` devem falhar com a mensagem em `expected.err`.

### 8.2 Granularidade

A granularidade é **híbrida** por escolha consciente. Testes nas categorias `lexer/`, `parser/`, `semantic/` e `codegen/` são **finos**: cada um isola um conceito específico (um único tipo de comentário, uma única forma de `if`, uma única coerção). Quando algo quebra, sabe-se exatamente o quê. Testes em `integration/` são **grossos**: programas Milla pequenos mas completos que exercitam várias features juntas, simulando uso real.

A intuição: testes finos para precisão diagnóstica, testes grossos para confiança de que a soma funciona.

### 8.3 Runner Python e Makefile

O runner principal é `tools/test_runner.py`, ~300 linhas. Funcionalidades:

- Descoberta automática de testes (qualquer pasta com `input.milla` em `tests/` é teste).
- Execução com timeout de segurança (10s por teste).
- Comparação de stdout, stderr e TAC com diff legível em modo verboso.
- Comparação de erro **tolerante**: `expected.err` precisa apenas conter a primeira linha essencial; o resto da mensagem pode evoluir sem quebrar 80 testes.
- Comparação de TAC **normalizada** (ignora espaços extras e linhas vazias).
- Cache de últimos resultados para `--failed-only` (roda só os que falharam).
- Filtros por categoria (`--category lexer`) e por substring (`--filter strings`).
- Relatório de cobertura (`--coverage`) cruzando features × fases.

O Makefile expõe atalhos curtos:

```makefile
make test                # roda tudo
make test-lexer          # roda só a categoria lexer
make test-parser         # roda só a categoria parser
make test-semantic
make test-codegen
make test-integration
make test-failed         # roda só os que falharam por último, modo verboso
make test-coverage       # gera relatório de cobertura
make test-verbose        # roda tudo com diffs completos das falhas
```

Para opções mais finas, chama-se o Python diretamente: `python tools/test_runner.py --filter "match" --verbose`.

### 8.4 Cobertura

A lista canônica de features da Milla é mantida no topo do `test_runner.py` (variável `FEATURES`). O comando `--coverage` produz uma tabela mostrando quais features têm pelo menos um teste em cada fase do compilador:

```
Cobertura de Features
─────────────────────────────────
            lexer  parser  semantic  codegen  integration
if            ✓      ✓        ✓        ✓         ✓
for_cstyle    ✓      ✓        —        ✓         ✓
foreach       ✓      ✓        —        ✓         —
match         ✓      ✓        ✓        ✓         ✓
strings_inter ✓      ✓        —        —         —
```

Os buracos são imediatamente visíveis. A tabela vira artefato do relatório acadêmico — evidência tangível de cobertura sistemática.

### 8.5 Filosofia de crescimento

A regra é **crescimento incremental**, não tentativa de especificação completa antecipada:

1. Crie a estrutura mínima de pastas e o runner agora.
2. Migre 3 a 5 testes da Etapa I para validar o framework.
3. A partir daí, **cada feature da Etapa II nasce com seus testes**.

## 9. Roteiro de implementação

### M0 — Infraestrutura

1. Verificar build (Flex/Bison sem prefixo `mingw-w64-ucrt-x86_64-`).
2. Implantar sistema de testes com runner Python, estrutura de pastas e alvos no Makefile.
3. Migrar 3-5 testes da Etapa I como prova de conceito.
4. Documentar a baseline.

### M1 — Refinamentos da Etapa I

1. Estender tabela de coerção para `double` (matriz 6×6 em `semantic.c`).
2. Implementar regra de parênteses (bool estrito / truthiness) para `if`.

### M2 — Lexer da Etapa II

1. Comentários `//` e `/* */`.
2. Newline como separador (com quatro exceções de continuação; variável de estado no Flex).
3. Strings com escapes dos sete universais.
4. Strings multi-linha `"""..."""` (start condition do Flex).
5. Interpolação `#{...}` (start conditions: modo string → `INTERP_START` → expressão → `INTERP_END` → volta ao modo string).
6. Novos tokens reservados: `if`, `else`, `while`, `do`, `for`, `in`, `match`, `_`, `break`, `continue`, `ci`, e I/O built-ins.

### M3 — Parser e ASA da Etapa II

1. Gramática de bloco `{ }` + pilha de escopos em `symtable.c`.
2. `if`/`else if`/`else` como statement e expressão.
3. `while` e `do/while`.
4. `for` nos três estilos (C-style, `for...in`, `foreach`).
5. `match` com múltiplos valores por braço, `_` catchall, corpo de bloco opcional.
6. `break`/`continue`/`break all`.

### M4 — Semântica da Etapa II

1. Resolução de nomes na pilha de escopos.
2. Shadowing intencional por declaração explícita.
3. Warning de modificação de globais em funções (infraestrutura).
4. Exaustividade do `match` como expressão.
5. Verificação de tipos de braços em `if`-expressão e `match`-expressão.

### M5 — Geração de TAC da Etapa II

1. `if`/`else` com `ifFalse goto Lx` e labels.
2. `while`/`do-while` com labels de topo e saída.
3. `for` C-style: equivalente a `init; while (cond) { corpo; update; }`.
4. `for...in` e `foreach`: índice temporário + iteração até o tamanho.
5. `match`: cadeia de comparações com labels.
6. `break`/`continue`: salta para label de saída/topo do laço imediato (pilha de labels no codegen).
7. `break all`: salta para label de saída do laço mais externo.
8. Strings com interpolação: temporário + `milla_strcat`.

### M6 — Mensagens de erro

1. Formato unificado: `nivel: mensagem em arquivo:linha:coluna`.
2. Severidade: `error` (não compila) vs `warning` (compila com aviso).
3. Recuperação no parser com `token error` do Bison.
4. Conectar métricas à mensagem `Compiled - ...`.

### M7 — Documentação e entrega

1. Atualizar `relatorio.md` com tudo que foi implementado.
2. Verificar relatório de cobertura.
3. Tag de release no git + README com instruções e exemplos.

## 10. Divisão de trabalho na equipe

| Membro | Camada | Etapa II — responsabilidades |
|---|---|---|
| **A** | Léxica + Gramática | Lexer estendido (M2 inteiro), gramática das construções de controle (M3 itens 1-4), gramática de `match` (M3 item 5), tokens de I/O. |
| **B** | Semântica + Símbolos | Pilha de escopos (M3 item 1), resolução de nomes e shadowing (M4 itens 1-3), exaustividade do `match` (M4 item 4), verificação de tipos em expressões com `if`/`match`. |
| **C** | Código Intermediário | TAC de todas as construções de controle (M5 inteiro), runtime auxiliar para strings/interpolação, formatação consistente do TAC, integração com `--tac`. |

**Trabalho compartilhado:** infraestrutura (M0), refinamentos da Etapa I (M1), sistema de testes (todos contribuem por camada), documentação e entrega (M7), tratamento de erros (M6 distribuído entre A/B/C).

## 11. Decisões em aberto e extras

### 11.1 Decisões adiadas para a Entrega Final

- **Funções**: palavra-chave, inferência de tipo de retorno, função como expressão, retorno múltiplo, parâmetros default, argumentos nomeados.
- **Vetores/matrizes**: sintaxe de inicialização, método de acesso a atributos, comportamento fora dos limites, varredura de matrizes com `for...in` e `foreach`.

### 11.2 Extras de bônus já decididos

- `break all` (Etapa II).
- Interpolação `#{...}` (Etapa II).
- Indexação `ord[N](str)` (Etapa II).
- Exponenciação `**` (Entrega Final).
- Argumentos nomeados em funções (Entrega Final).
- Inferência de tipo de retorno (Entrega Final).
- `match` com guards (`n if n > 10 -> ...`) (Entrega Final).

### 11.3 Itens fora do escopo

OOP, ponteiros explícitos, genéricos, inferência polimórfica parametricamente tipada.

## 12. Referências

- **AHO et al.** *Compiladores: Princípios, Técnicas e Ferramentas.* 2ª ed. Pearson, 2008. (Dragon Book)
- **Introdução à Compilação.** Elsevier.
- **Slide sets da disciplina** (UFRRJ): autômatos, análise léxica, scanners, análise sintática, código intermediário, Lex, Yacc.
- **Documentação do Flex/Lex** — start conditions, expressões regulares.
- **Documentação do Bison/Yacc** — gramáticas LALR, precedência, recuperação de erros.
- **Documentação do Kotlin** — `if`-expressão, separador de linha.
- **Documentação do Rust** — `match` exaustivo.
- **Documentação do Ruby** — interpolação `#{...}`, simplicidade no caso geral.

## 13. Palavras reservadas

Lista canônica de todas as palavras reservadas da Milla. Nenhum identificador do usuário pode usar esses nomes.

**Controle de fluxo:**
```
if  else  while  do  for  in  foreach  match  break  continue
```

**Literais e valores especiais:**
```
true  false  null  ci  _
```

**Tipos:**
```
int  float  double  char  string  bool
```

**Funções built-in (tratadas como palavras reservadas):**
```
print  mout  min  scan  log  error  ord  chr
```

**Operadores e tokens especiais:**
```
->        braço de match
#{        início de interpolação (tratado no lexer)
"""       string multi-linha (tratado no lexer)
+=  -=  *=  /=  %=   operadores compostos (Etapa II)
++  --               pré e pós-fixo (Etapa II)
**                   exponenciação (Extra)
```

---

## 14. Checklist detalhado da Etapa II

Use este checklist para rastrear o progresso de implementação. `[x]` = concluído, `[~]` = parcial, `[ ]` = pendente.

### M0 — Infraestrutura
- [x] Compilador build funcional (Flex + Bison + G++)
- [x] Suite de 12 testes de Etapa I passando
- [x] Make test com diff --strip-trailing-cr
- [ ] Árvore de pastas `tests/` com categorias (lexer/parser/semantic/codegen/integration)
- [ ] `tools/test_runner.py` instalado
- [ ] Alvos `make test-lexer`, `make test-parser`, etc. no Makefile
- [ ] Migração de ≥3 testes da Etapa I ao novo formato (input.milla + expected.tac)

### M1 — Refinamentos da Etapa I
- [ ] Tipo `double` distinto de `float` (t_double no enum; literal `3.14` = double)
- [ ] Tabela de coerção ampliada: `int → float → double` (6×6 completa)
- [ ] Regra de parênteses: condição sem parênteses exige bool; com parênteses ativa truthiness
- [ ] `null` como keyword (falsy value na truthiness)

### M2 — Lexer da Etapa II
- [x] Comentários `//` e `/* ... */`
- [x] Tokens: if, else, while, do, for, match, break, continue, mout, in, `_`
- [x] String literals básicos `"..."`
- [ ] Newline como separador NEWLINE (com 4 exceções de continuação)
- [ ] Processar escapes dentro de strings: `\n \t \\ \" \' \0 \r`
- [ ] Strings multi-linha `"""..."""` (start condition MULTILINE_MODE)
- [ ] Interpolação `#{...}` (start conditions STRING_MODE + INTERP_MODE)
- [ ] Tokens: `true`, `false`, `null`, `ci`, `foreach`
- [ ] Operadores compostos: `+=`, `-=`, `*=`, `/=`, `%=`
- [ ] Operadores unários: `++`, `--`

### M3 — Parser e gramática
- [x] BLOCK `{ }` com push/pop de escopo
- [x] if / else if / else (statement)
- [x] while
- [x] do-while
- [x] for C-style (sem parênteses)
- [x] match (arms de valor único + `_` catchall)
- [x] break / continue
- [x] mout(expr)
- [ ] Statement list com NEWLINE como separador (grammar rule `stmt NEWLINE`)
- [ ] match com múltiplos valores por arm: `1, 2, 3 -> body`
- [ ] for...in nomeado: `for x in lista { }`
- [ ] for...in indexado: `for i, x in lista { }`
- [ ] foreach com ci: `foreach lista { ... ci ... }`
- [ ] break all
- [ ] if como expressão (retorna valor)
- [ ] match como expressão (retorna valor; `_` obrigatório)
- [ ] Operadores compostos desaçucarados no parser/codegen
- [ ] Operadores unários `++`, `--` na gramática
- [ ] Funções: print, log, error, min, scan

### M4 — Semântica
- [x] Scope stack com lookup do mais interno ao mais externo
- [x] Criação no scope atual se não encontrado (reatribuição se encontrado)
- [x] Shadowing por declaração explícita
- [ ] Tipo `double` na verificação e coerção
- [ ] Regra de parênteses para condições (bool estrito / truthiness)
- [ ] Exaustividade do match-expressão (`_` obrigatório)
- [ ] Verificação de if-expressão (else obrigatório em todos os caminhos)
- [ ] Verificação de tipos de braços em if/match-expressão (compatibilidade)
- [ ] `ci` visível somente dentro de foreach; ligado ao foreach mais interno
- [ ] Warning de modificação de global dentro de função
- [ ] Mensagens de erro com linha:coluna

### M5 — Geração de TAC
- [x] if/else com `if (!Tn) goto Lx;` e labels
- [x] while com L_top + L_end
- [x] do-while com L_top + L_end
- [x] for C-style (estrutura L_top + L_update + L_end)
- [x] break → goto L_end
- [x] continue → goto loop_stack.back().first
- [x] match (arm de valor único + `_`)
- [x] mout → printf com format por tipo
- [ ] **CORREÇÃO CRÍTICA**: continue em for C-style deve ir para L_update (não L_top) — atualmente usa L_top, o que pula o incremento
- [ ] match com múltiplos valores por arm (OR de comparações)
- [ ] for...in (milla_len + milla_get)
- [ ] foreach (T_ci no lugar de T_x)
- [ ] break all → loop_stack[0].end
- [ ] if-expressão (T_result em cada braço)
- [ ] match-expressão (T_result_match)
- [ ] TAC dos operadores compostos (desaçucarados)
- [ ] TAC dos operadores unários (++ pré/pós, --)
- [ ] TAC da interpolação de strings (milla_strcat)
- [ ] `#define true 1` / `#define false 0` no preâmbulo quando bool é usado

### M6 — CLI e mensagens
- [ ] Formato de erro: `nivel: mensagem em arquivo.milla:linha:coluna`
- [ ] Exemplos: `error: variável 'x' não declarada em prog.milla:5:9`
- [ ] Recuperação no parser com `error NEWLINE` para múltiplos erros
- [ ] Contagem de tokens, vars, temps para mensagem `Compiled - ...`
- [ ] Flag `--silent` suprime linha Compiled
- [ ] Flag `--tac` imprime TAC
- [ ] Warning de modificação de global: `warning: função 'f' modifica global 'x'`

---

## 15. Programa exemplo completo (Etapa II)

O compilador deve processar este programa corretamente ao final da Etapa II. Serve como teste de conformidade end-to-end.

```milla
// programa completo de demonstração da Etapa II
// testa: tipos, escopo, if, for, while, match, strings, interpolação

x = 10
nome = "Milla"
ativo = true

// if como statement e como expressão
if x > 5 {
    mout("x é grande")
} else {
    mout("x é pequeno")
}

resultado = if (ativo) { "ligado" } else { "desligado" }
mout("Status: #{resultado}")

// for C-style
soma = 0
for i = 1; i <= x; i = i + 1 {
    soma = soma + i
}
mout("Soma de 1 a #{x}: #{soma}")

// while com break
n = 100
while n > 1 {
    if n % 2 == 0 {
        n = n / 2
    } else {
        n = n * 3 + 1
    }
    if n == 1 { break }
}

// do-while
contador = 0
do {
    contador = contador + 1
} while contador < 5

// match como expressão
categoria = match soma {
    0       -> "vazio",
    1, 2, 3 -> "pequeno",
    _       -> "grande"
}
mout("Categoria: #{categoria}")

// escopo aninhado com shadowing
y = 100
if y > 50 {
    int y = 999     // shadowing intencional
    mout(y)         // imprime 999
}
mout(y)             // imprime 100 (global intocada)

// string multi-linha
descricao = """
    Nome: #{nome}
    Valor: #{x}
    Soma: #{soma}
"""
mout(descricao)
```

---

*Documento v3 — consenso da equipe ao final das sessões de design. Mudanças futuras devem ser registradas em v4 com diff explícito.*

❯ Prepare-se para sim executar o planejamento em auto-mode, mas eu quero apenas a parte referente a etapa 2 implementada por agora. Tudo referente a etapa de entrega final que não 
  seja extremamente fundamental para o funcionamento atual do compilador e que interfira diretamente na entrega da etapa 2 deve ser mantido guardado para ser implementado em outro 
  momento separado. 