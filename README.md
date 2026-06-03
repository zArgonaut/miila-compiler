# Mila Compiler

Mila Compiler é uma reformulação acadêmica do projeto FOCA para a disciplina de Compiladores da UFRRJ. O compilador lê programas escritos na linguagem imperativa `mila-lang` e gera código intermediário em C, com temporários explícitos e declarações emitidas antes das instruções.

## Início rápido

**1. Clone e compile:**

```bash
git clone <url-do-repositorio>
cd miila-compiler
make
```

**2. Crie seu programa Milla:**

Crie qualquer arquivo com extensão `.milla` — pode ficar em qualquer pasta. Exemplo:

```bash
# cria o arquivo
touch meu_programa.milla
```

Abra e escreva seu código Milla, por exemplo:

```
int x;
int y;
x = 10;
y = x + 5;
print(y);
```

**3. Execute:**

```bash
# imprime o código intermediário em C no terminal
make run FILE=meu_programa.milla

# gera o C intermediário, compila com GCC e executa
make verify FILE=meu_programa.milla
```

---

A implementação cobre a Etapa I (expressões, tipos, declarações, operadores, coerção) e a Etapa II (controle de fluxo, escopos, strings, I/O, laços `for`/`foreach`/`while`).

## Requisitos

Em ambiente Linux/WSL:

```bash
sudo apt install build-essential flex bison
```

Ambiente Windows (Nativo):

Se você preferir não utilizar o WSL, pode configurar o ambiente usando o MSYS2:

Instale o MSYS2: Baixe e execute o instalador do site oficial.

Atualize os pacotes: Abra o terminal MSYS2 UCRT64 e execute:

```Bash
pacman -Syu
```
Instale as ferramentas necessárias:

```Bash
pacman -S mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-flex mingw-w64-ucrt-x86_64-bison make
```

Configuração do PATH: Certifique-se de adicionar o caminho da pasta bin do seu MSYS2 (geralmente C:\msys64\ucrt64\bin) às Variáveis de Ambiente do Windows para que os comandos make, flex e bison funcionem em qualquer terminal (CMD ou PowerShell).

Ferramentas usadas:

- Flex para análise léxica.
- Bison para análise sintática.
- G++ para compilar o compilador.
- GCC para validar o C intermediário gerado.

## Estrutura

```text
src/
  lexico.l       analisador léxico Flex
  sintatico.y    gramática Bison, análise semântica e geração de C intermediário

tests/
  *.mila         entradas de teste da linguagem Mila
  *.expected     saídas esperadas em C intermediário

Makefile         automação de build, execução, testes e verificação
```

## Comandos

```bash
make
make run FILE=tests/01_soma.mila
make test
make test-01
make generate FILE=tests/11_conversao_implicita.mila
make verify FILE=tests/11_conversao_implicita.mila
make clean
```

`make run` imprime o C intermediário no terminal. `make generate` grava o C gerado em `/tmp/mila_intermediario.c`. `make verify` gera o C intermediário, compila com `gcc` e executa o binário resultante.

## Convenções do código gerado

- Temporários: `T1`, `T2`, `T3`, em maiúsculo.
- Variáveis do usuário são mapeadas para temporários.
- Declarações aparecem antes das instruções.
- `boolean` e `bool` são aceitos na linguagem fonte.
- Valores booleanos são representados como `int` no C intermediário.
- `true` gera `1`; `false` gera `0`.
- A conversão implícita permitida na Etapa I é `int -> float`.
- Casts explícitos são emitidos no C intermediário.

Exemplo de entrada:

```c
float F;
int I;
F = I + 2.5;
```

Saída esperada:

```c
#include <stdio.h>

int main(void) {
    float T1; /* F */
    int T2; /* I */
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


