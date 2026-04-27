%{
#include <iostream>
#include <string>
#include <map>
#include <vector>

#define YYSTYPE atributos

using namespace std;

struct simbolo {
    string apelido;
    string tipo;
};

map<string, simbolo> tabela_simbolos;
vector<simbolo> variaveis_temp;
int var_temp_qnt = 0;
int linha = 1;
string codigo_gerado;
bool modo_declaracao = false;

struct atributos
{
    string label;
    string traducao;
    string tipo;
};

int yylex(void);
void yyerror(string);
string gentempcode(string tipo);
%}

%token TK_NUM TK_FLOAT_VAL TK_CHAR_VAL TK_BOOL_VAL
%token TK_ID
%token TK_TIPO_INT TK_TIPO_FLOAT TK_TIPO_CHAR TK_TIPO_BOOL

%start S

%left '+' '-'
%left '*' '/'

%%

S : COMANDOS
  {
      codigo_gerado = "/*Compilador FOCA*/\n"
                      "#include <stdio.h>\n"
                      "int main(void) {\n";

      for (int i = 0; i < variaveis_temp.size(); i++) {
          string tipo_c = variaveis_temp[i].tipo;
          // O C não tem tipo bool nativo, usamos int!
          if (tipo_c == "bool") {
              tipo_c = "int"; 
          }
          codigo_gerado += "\t" + tipo_c + " " + variaveis_temp[i].apelido + ";\n";
      }

      codigo_gerado += "\n" + $1.traducao;
      codigo_gerado += "\treturn 0;\n}\n";
  }
  ;

COMANDOS : COMANDOS COMANDO
         {
             $$.traducao = $1.traducao + $2.traducao;
         }
         | /* vazio */
         {
             $$.traducao = "";
         }
         ;

COMANDO : D               { $$.traducao = $1.traducao; }
        | ATRIB           { $$.traducao = $1.traducao; }
        | ATRIB ';'       { $$.traducao = $1.traducao; }
        ;

D : TK_TIPO_INT TK_ID ';' 
  {
      modo_declaracao = true;
      if (tabela_simbolos.find($2.label) == tabela_simbolos.end()) {
          tabela_simbolos[$2.label] = {gentempcode("int"), "int"};
      }
      $$.traducao = ""; 
  }
  | TK_TIPO_FLOAT TK_ID ';' 
  {
      modo_declaracao = true;
      if (tabela_simbolos.find($2.label) == tabela_simbolos.end()) {
          tabela_simbolos[$2.label] = {gentempcode("float"), "float"};
      }
      $$.traducao = ""; 
  }
  | TK_TIPO_CHAR TK_ID ';' 
  {
      modo_declaracao = true;
      if (tabela_simbolos.find($2.label) == tabela_simbolos.end()) {
          tabela_simbolos[$2.label] = {gentempcode("char"), "char"};
      }
      $$.traducao = ""; 
  }
  | TK_TIPO_BOOL TK_ID ';' 
  {
      modo_declaracao = true;
      if (tabela_simbolos.find($2.label) == tabela_simbolos.end()) {
          tabela_simbolos[$2.label] = {gentempcode("bool"), "bool"};
      }
      $$.traducao = ""; 
  }
  ;

ATRIB : TK_ID '=' E 
      {
          if (modo_declaracao) {
              if (tabela_simbolos.find($1.label) == tabela_simbolos.end()) {
                  yyerror("Variavel nao declarada: " + $1.label);
              }
              string destino = tabela_simbolos[$1.label].apelido;
              $$.traducao = $3.traducao + "\t" + destino + " = " + $3.label + ";\n";
          } else {
              $$.traducao = $3.traducao + "\t" + $1.label + " = " + $3.label + ";\n";
          }
      }
      ;

E : E '+' E
  {
      $$.tipo = "int";
      $$.label = gentempcode($$.tipo);
      $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label + " + " + $3.label + ";\n";
  }
  | E '-' E
  {
      $$.tipo = "int";
      $$.label = gentempcode($$.tipo);
      $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label + " - " + $3.label + ";\n";
  }
  | E '*' E
  {
      $$.tipo = "int";
      $$.label = gentempcode($$.tipo);
      if ($1.tipo == "int" && $3.tipo == "float") {
          $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $3.label + " * " + $1.label + ";\n";
      } else {
          $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label + " * " + $3.label + ";\n";
      }
  }
  | E '/' E
  {
      $$.tipo = "int";
      $$.label = gentempcode($$.tipo);
      $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label + " / " + $3.label + ";\n";
  }
  | '(' E ')'
  {
      $$ = $2;
  }
  | TK_NUM
  {
      $$.tipo = "int";
      $$.label = gentempcode($$.tipo);
      $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
  }
  | TK_FLOAT_VAL
  {
      $$.tipo = "float";
      $$.label = gentempcode($$.tipo);
      $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
  }
  | TK_CHAR_VAL
  {
      $$.tipo = "char";
      $$.label = $1.label; // Passa o 'a' direto, sem criar temporária
      $$.traducao = "";    // Não gera linha de código intermediária
  }
  | TK_BOOL_VAL
  {
      $$.tipo = "bool";
      $$.label = $1.label; // Passa o 1 direto
      $$.traducao = "";
  }
  | TK_ID
  {
      if (modo_declaracao) {
          if (tabela_simbolos.find($1.label) == tabela_simbolos.end()) yyerror("Nao declarada");
          $$.label = tabela_simbolos[$1.label].apelido;
          $$.tipo = tabela_simbolos[$1.label].tipo;
          $$.traducao = ""; 
      } else {
          $$.tipo = "int";
          $$.label = gentempcode($$.tipo);
          $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
      }
  }
  ;

%%

#include "lex.yy.c"

int yyparse();

string gentempcode(string tipo)
{
    var_temp_qnt++;
    string nome = "t" + to_string(var_temp_qnt);
    
    simbolo s = {nome, tipo};
    variaveis_temp.push_back(s);
    
    return nome;
}

int main(int argc, char* argv[])
{
    var_temp_qnt = 0;

    if (yyparse() == 0)
        cout << codigo_gerado;

    return 0;
}

void yyerror(string MSG)
{
    cerr << "Erro na linha " << linha << ": " << MSG << endl;
}