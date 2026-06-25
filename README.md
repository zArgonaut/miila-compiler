# Milla

Milla é uma linguagem de programação imperativa e estaticamente tipada, desenvolvida como trabalho da disciplina de Compiladores da UFRRJ. O projeto não se limita a cumprir o enunciado: cada decisão de design foi tomada com a intenção de produzir uma linguagem que valha a pena escrever, com personalidade própria e escolhas coerentes entre si. A inspiração vem do scripting tipado e prático de Kotlin e Crystal e da expressividade de Ruby, buscando unir a brevidade do caso comum à possibilidade de controle fino quando o programador precisa.

O compilador traduz programas escritos em Milla para código de três endereços (TAC) que é, ao mesmo tempo, C válido. Essa decisão é deliberada: o código gerado pode ser passado diretamente ao GCC, o que serve tanto como mecanismo de validação durante o desenvolvimento quanto como demonstração concreta de que a tradução está correta. Não há máquina virtual nem runtime grande — o que sai do compilador é C legível.

O fluxo de compilação segue o pipeline clássico de quatro fases:

```
programa.milla  ->  Flex (lexico)  ->  Bison (sintaxe + semantica + geracao)  ->  C (TAC)  ->  GCC
```

## Princípios de design

Três princípios guiaram todas as escolhas da linguagem.

O primeiro é a simplicidade no caso geral, com especificidade quando se quer. A Milla não exige declaração de tipo, mas a aceita. Quem busca rapidez escreve `x = 10` e segue; quem precisa de controle escreve `int x = 10`. Nenhum dos caminhos é punido.

O segundo é uma regra aplicada de forma coerente. Quando uma decisão funciona bem em uma construção, ela vale em todas. A regra de parênteses nas condições, por exemplo, comporta-se igual em `if`, `while` e `do-while`.

O terceiro é que o caso difícil paga seu próprio preço. O caso simples permanece trivial e o caso complexo recebe uma rota explícita, sem corromper o uso comum. O `foreach` resolve a varredura de um nível; o aninhamento usa `for...in` nomeado. O `break` sai do laço atual; `break all` sai de todos.

## Como compilar e executar

O ambiente de referência é Windows com MSYS2 (UCRT64), mas o projeto também compila em Linux ou WSL. São necessários Flex, Bison, G++ (para construir o compilador) e GCC (para validar o C gerado).

Em Linux ou WSL:

```bash
sudo apt install build-essential flex bison
```

Em Windows com MSYS2, abre-se o terminal UCRT64 e instalam-se as ferramentas:

```bash
pacman -S flex bison make
pacman -S mingw-w64-ucrt-x86_64-gcc
```

Com o ambiente pronto, a construção e a execução seguem o Makefile:

```bash
make                                  # constroi o compilador (mila-compiler)
make run FILE=uso.milla               # compila e imprime o TAC no terminal
make verify FILE=uso.milla            # gera o TAC, compila com GCC e executa
make test                             # roda a suite completa de testes
make clean                            # remove os artefatos gerados
```

## A linguagem

### Tipos e variáveis

A Milla tem seis tipos primários: `int`, `float`, `double`, `char`, `string` e `bool`. Toda variável tem um tipo concreto, conhecido em tempo de compilação. A criação de uma variável acontece de três formas. Pode-se declarar sem valor (`int x;`), declarar com inicialização (`int x = 5;`) ou apenas atribuir, deixando o tipo ser inferido do valor (`x = 5;`). A inferência identifica o tipo correto: um literal decimal como `3.14` produz um `double`, e não um `int`. O tipo é fixado na primeira atribuição e não muda depois.

```milla
i = 10
nome = "Milla"
ativo = true
double pi = 3.14
```

### Operadores

Estão disponíveis os operadores aritméticos (`+`, `-`, `*`, `/`, `%`), relacionais (`<`, `<=`, `>`, `>=`, `==`, `!=`), lógicos (`&&`, `||`, `!`), compostos (`+=`, `-=`, `*=`, `/=`, `%=`) e unários (`++`, `--`, `-` e `!`). Há ainda a exponenciação `**`, que associa à direita e tem precedência acima da multiplicação. Os operadores relacionais e lógicos produzem `bool`.

### Coerção segura

A coerção implícita segue a hierarquia `int -> float -> double` e ocorre apenas quando não há perda de informação. O caminho inverso, a conversão estreita (como `double` para `int`), exige cast explícito. Essa é uma decisão consciente de segurança: o truncamento silencioso é uma fonte clássica de erros sutis, e a Milla prefere torná-lo visível.

```milla
double d = 9.7
int i = (int) d        // cast obrigatorio; i recebe 9
```

### Strings

O operador `+` concatena quando ao menos um operando é `string` ou `char`. A linguagem também oferece interpolação no estilo Ruby, com `#{expr}`, e strings de múltiplas linhas delimitadas por `"""`. Internamente, as strings são gerenciadas em memória de forma explícita: o compilador emite alocação, cópia com `strcpy` e liberação com `free`, de modo que o C gerado não acumula lixo de memória.

```milla
nome = "Milla"
mout("Ola, #{nome}! Resultado: #{2 ** 4}")

texto = """
Relatorio
Nome: #{nome}
"""
```

### Controle de fluxo

As construções de decisão são `if`, `else if` e `else`, com chaves obrigatórias mesmo em corpo de uma linha. A condição segue uma regra unificada: sem parênteses, exige um valor estritamente `bool`; entre parênteses, ativa a chamada truthiness, em que valores como `0`, `0.0`, `'\0'` e `null` são falsos e o restante é verdadeiro.

```milla
if x > 0 { mout("positivo") } else { mout("nao positivo") }
if (x) { mout("diferente de zero") }
```

Os laços disponíveis são `while`, `do-while` e `for` no estilo C. No lugar do `switch` tradicional, a Milla adota `match`, uma construção sem fall-through: cada braço é isolado e não há necessidade de `break`. Vários valores podem compartilhar um braço, e o sublinhado `_` funciona como caso padrão.

```milla
match nota {
    10 -> { mout("excelente") },
    7, 8, 9 -> { mout("bom") },
    _ -> { mout("revisar") }
}
```

O controle de laços conta com `break`, `continue` e `break all`, este último responsável por sair de todos os laços aninhados de uma vez.

### Iteração sobre sequências

Além do `for` clássico, há duas formas de varredura. O `for...in` nomeia a variável de iteração (`for c in "Milla"`), enquanto o `foreach` mantém o elemento atual disponível na palavra reservada `ci`. Ambos percorrem strings caractere a caractere e vetores elemento a elemento.

```milla
foreach "Milla" { mout(ci) }
```

### Funções e procedimentos

As funções são declaradas com a palavra-chave `fnc`, seguida do tipo de retorno, do nome e dos parâmetros tipados. A ausência do tipo de retorno indica um procedimento, que executa efeitos sem devolver valor. Parâmetros consecutivos de mesmo tipo podem compartilhar a anotação. As funções suportam recursão e enxergam apenas os próprios parâmetros e variáveis locais, o que mantém a assinatura como descrição completa do que entra e do que sai.

```milla
fnc int soma(int a, int b) { return a + b }
fnc int media(int a, b, c) { return (a + b + c) / 3 }
fnc saudar(string nome) { mout("Ola, #{nome}") }
```

### Vetores e matrizes

Vetores podem ter tamanho fixo (`int v[5]`) ou ser inicializados na declaração (`int v[] = {1, 2, 3}`). Para situações em que o tamanho não é conhecido de antemão, existe o vetor extensível, declarado com `int v[ext]`: ele cresce em tempo de execução por meio de `push(v, x)` e, por segurança, só aumenta, nunca diminui. O comprimento é obtido com `len(v)`, e todo acesso por índice é verificado em tempo de execução, encerrando o programa com mensagem clara caso o índice esteja fora dos limites.

```milla
int notas[ext]
push(notas, 7)
push(notas, 9)
mout("quantidade: #{len(notas)}, primeira: #{notas[0]}")
```

As matrizes são bidimensionais e seguem a mesma lógica de inicialização (`int m[][] = {{1, 2}, {3, 4}}`), com acesso na forma `m[i][j]`. A varredura completa de uma matriz com `foreach` percorre, por padrão, linha a linha; o modificador `by col` inverte a ordem para coluna a coluna.

```milla
int m[][] = {{1, 2, 3}, {4, 5, 6}}
foreach m { mout(ci) }            // 1 2 3 4 5 6
foreach m by col { mout(ci) }     // 1 4 2 5 3 6
```

### Detecção de erros

O compilador não interrompe a análise no primeiro problema. Ele coleta todos os erros de uma compilação e os reporta juntos, cada um com linha e coluna, recuperando-se após erros de sintaxe para continuar examinando o restante do programa. Quando há qualquer erro, nenhum código é gerado.

```
erro [linha 3, coluna 6]: variavel 'z' nao declarada
```

## Recursos além do obrigatório

A linguagem implementa diversos recursos que vão além do conjunto mínimo exigido. Entre eles estão a declaração implícita com inferência de tipo, os procedimentos sem retorno, o `match` no lugar do `switch`, a concatenação de strings com gestão automática de memória, o `break all`, o `foreach` com `ci`, os vetores extensíveis `[ext]`, a escolha de ordem de varredura de matrizes com `by col`, a exponenciação `**`, a interpolação `#{}`, as strings de múltiplas linhas, a verificação de limites em tempo de execução e a detecção de erros com múltiplas mensagens localizadas. As decisões por trás de cada um desses recursos, com seus motivos e contexto, estão detalhadas na cartilha de desenvolvimento do projeto.

## Programas de exemplo

A raiz do projeto traz programas completos que exercitam a linguagem de forma densa e demonstram seus recursos em funcionamento real:

- `uso.milla` — análise de um conjunto de notas com vetor extensível, função, `foreach`, `len` e interpolação;
- `blabla.milla` — operações sobre matriz com varredura por linha e por coluna, exponenciação e construção de strings;
- `fizzbuzz.milla` — controle de fluxo com `for`, encadeamento de `if`/`else if` e `match`.

Cada um pode ser executado diretamente:

```bash
make verify FILE=uso.milla
```

## Estrutura do projeto

```text
src/
  lexico.l        analisador lexico (Flex)
  sintatico.y     gramatica, analise semantica e geracao de TAC (Bison)
tests/
  *.mila          programas de entrada
  *.expected      TAC esperado, comparado pela suite de testes
uso.milla         programas de demonstracao
blabla.milla
fizzbuzz.milla
Makefile          automacao de build, execucao, testes e verificacao
```

## Convenções do código gerado

O TAC produzido é C válido. Os temporários recebem nomes em maiúsculas (`T1`, `T2`, ...), e cada variável do usuário é mapeada para um temporário, anotado com o nome original para facilitar a leitura. Todas as declarações aparecem antes das instruções, no estilo C89. Os valores booleanos são representados como `int`, e as conversões de tipo aparecem explicitamente como instruções de cast.

A título de exemplo, o programa a seguir:

```milla
int i = 10
double d = 2.5
soma = i + d
mout(soma)
```

gera o C a seguir, em que a promoção de `int` para `double` aparece como cast explícito e cada variável do usuário é anotada com seu nome:

```c
#include <stdio.h>

int main(void) {
    int T1;
    int T2; /* i */
    double T3;
    double T4; /* d */
    double T5;
    double T6;
    double T7; /* soma : inferida double */

    T1 = 10;
    T2 = T1;
    T3 = 2.5;
    T4 = T3;
    T5 = (double) T2;
    T6 = T5 + T4;
    T7 = T6;
    printf("%f\n", T7);
    return 0;
}
```
