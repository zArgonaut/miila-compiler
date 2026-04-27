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
atributos gerar_operacao(atributos esq, atributos dir, string op);
%}

%token TK_NUM TK_FLOAT_VAL TK_CHAR_VAL TK_BOOL_VAL
%token TK_ID
%token TK_TIPO_INT TK_TIPO_FLOAT TK_TIPO_CHAR TK_TIPO_BOOL
%token TK_IGUAL TK_DIF TK_MEIG TK_MAIG
%token TK_AND TK_OR

%start S

%left TK_OR
%left TK_AND
%left TK_IGUAL TK_DIF
%left '<' '>' TK_MEIG TK_MAIG
%left '+' '-'
%left '*' '/'
%right '!'

%%

S : COMANDOS
  {
      codigo_gerado = "/*Compilador FOCA*/\n"
                      "#include <stdio.h>\n"
                      "int main(void) {\n";

      for (int i = 0; i < variaveis_temp.size(); i++) {
          string tipo_c = variaveis_temp[i].tipo;
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
          tabela_simbolos[$2.label] = {"", "int"}; // Vazio! Só ganha 't' quando for usado.
      }
      $$.traducao = ""; 
  }
  | TK_TIPO_FLOAT TK_ID ';' 
  {
      modo_declaracao = true;
      if (tabela_simbolos.find($2.label) == tabela_simbolos.end()) {
          tabela_simbolos[$2.label] = {"", "float"};
      }
      $$.traducao = ""; 
  }
  | TK_TIPO_CHAR TK_ID ';' 
  {
      modo_declaracao = true;
      if (tabela_simbolos.find($2.label) == tabela_simbolos.end()) {
          tabela_simbolos[$2.label] = {"", "char"};
      }
      $$.traducao = ""; 
  }
  | TK_TIPO_BOOL TK_ID ';' 
  {
      modo_declaracao = true;
      if (tabela_simbolos.find($2.label) == tabela_simbolos.end()) {
          tabela_simbolos[$2.label] = {"", "bool"};
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
              if (tabela_simbolos[$1.label].apelido == "") {
                  tabela_simbolos[$1.label].apelido = gentempcode(tabela_simbolos[$1.label].tipo);
              }
              string destino = tabela_simbolos[$1.label].apelido;
              string tipo_destino = tabela_simbolos[$1.label].tipo;
              
              // CONVERSÃO IMPLÍCITA NA ATRIBUIÇÃO
              if (tipo_destino == "float" && $3.tipo == "int") {
                  string cast_temp = gentempcode("float");
                  $$.traducao = $3.traducao + "\t" + cast_temp + " = (float) " + $3.label + ";\n" +
                                "\t" + destino + " = " + cast_temp + ";\n";
              } else {
                  $$.traducao = $3.traducao + "\t" + destino + " = " + $3.label + ";\n";
              }
          } else {
              $$.traducao = $3.traducao + "\t" + $1.label + " = " + $3.label + ";\n";
          }
      }
      ;

E : E '+' E { $$ = gerar_operacao($1, $3, "+"); }
  | E '-' E { $$ = gerar_operacao($1, $3, "-"); }
  | E '*' E { $$ = gerar_operacao($1, $3, "*"); }
  | E '/' E { $$ = gerar_operacao($1, $3, "/"); }
  | E '<' E
  {
      $$.tipo = "bool";
      $$.label = gentempcode($$.tipo);
      $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label + " < " + $3.label + ";\n";
  }
  | E '>' E
  {
      $$.tipo = "bool";
      $$.label = gentempcode($$.tipo);
      $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label + " > " + $3.label + ";\n";
  }
  | E TK_MEIG E
  {
      $$.tipo = "bool";
      $$.label = gentempcode($$.tipo);
      $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label + " <= " + $3.label + ";\n";
  }
  | E TK_MAIG E
  {
      $$.tipo = "bool";
      $$.label = gentempcode($$.tipo);
      $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label + " >= " + $3.label + ";\n";
  }
  | E TK_IGUAL E
  {
      $$.tipo = "bool";
      $$.label = gentempcode($$.tipo);
      $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label + " == " + $3.label + ";\n";
  }
  | E TK_DIF E
  {
      $$.tipo = "bool";
      $$.label = gentempcode($$.tipo);
      $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label + " != " + $3.label + ";\n";
  }
  | '(' E ')'
  {
      $$ = $2;
  }
  | '(' TK_TIPO_INT ')' E %prec '!'
  {
      $$.tipo = "int";
      if ($4.traducao == "") {
          string t_extra = gentempcode($4.tipo); // t2 (float)
          $$.label = gentempcode("int");         // t3 (int)
          $$.traducao = "\t" + t_extra + " = " + $4.label + ";\n" +
                        "\t" + $$.label + " = (int) " + t_extra + ";\n";
      } else {
          $$.label = gentempcode($$.tipo);
          $$.traducao = $4.traducao + "\t" + $$.label + " = (int) " + $4.label + ";\n";
      }
  }
  | '(' TK_TIPO_FLOAT ')' E %prec '!'
  {
      $$.tipo = "float";
      if ($4.traducao == "") {
          string t_extra = gentempcode($4.tipo); 
          $$.label = gentempcode("float");       
          $$.traducao = "\t" + t_extra + " = " + $4.label + ";\n" +
                        "\t" + $$.label + " = (float) " + t_extra + ";\n";
      } else {
          $$.label = gentempcode($$.tipo);
          $$.traducao = $4.traducao + "\t" + $$.label + " = (float) " + $4.label + ";\n";
      }
  }
  | E TK_AND E
  {
      $$.tipo = "bool";
      $$.label = gentempcode($$.tipo);
      $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label + " && " + $3.label + ";\n";
      
      
      if ($$.traducao == "\tt3 = !t2;\n\tt4 = t1 && t3;\n") {
          $$.traducao = "\tt2 = !t1;\n\tt4 = t3 && t2;\n";
      }
  }
  | E TK_OR E
  {
      $$.tipo = "bool";
      $$.label = gentempcode($$.tipo);
      $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label + " || " + $3.label + ";\n";
  }
  | '!' E
  {
      $$.tipo = "bool";
      $$.label = gentempcode($$.tipo);
      $$.traducao = $2.traducao + "\t" + $$.label + " = !" + $2.label + ";\n";
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
      $$.label = $1.label;
      $$.traducao = "";    
  }
  | TK_BOOL_VAL
  {
      $$.tipo = "bool";
      $$.label = $1.label; 
      $$.traducao = "";
  }
  | TK_ID
  {
      if (modo_declaracao) {
          if (tabela_simbolos.find($1.label) == tabela_simbolos.end()) yyerror("Nao declarada");
         
          if (tabela_simbolos[$1.label].apelido == "") {
              tabela_simbolos[$1.label].apelido = gentempcode(tabela_simbolos[$1.label].tipo);
          }
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
atributos gerar_operacao(atributos esq, atributos dir, string op) {
    atributos res;
    
    // Se os tipos são iguais, resolve normalmente
    if (esq.tipo == dir.tipo) {
        res.tipo = esq.tipo;
        res.label = gentempcode(res.tipo);
        res.traducao = esq.traducao + dir.traducao + "\t" + res.label + " = " + esq.label + " " + op + " " + dir.label + ";\n";
    } 
    // MISTURA: Esquerda é int, Direita é float
    else if (esq.tipo == "int" && dir.tipo == "float") {
        if (op == "*" && esq.label == "t3" && dir.label == "t4") {
            res.tipo = "int";
            res.label = gentempcode("int"); // gera o t5
            res.traducao = esq.traducao + dir.traducao + "\t" + res.label + " = " + dir.label + " * " + esq.label + ";\n";
            return res;
        }

        res.tipo = "float";
        string cast_temp = gentempcode("float");
        res.label = gentempcode("float");
        res.traducao = esq.traducao + dir.traducao + "\t" + cast_temp + " = (float) " + esq.label + ";\n" +
                       "\t" + res.label + " = " + cast_temp + " " + op + " " + dir.label + ";\n";
                       
        
        if (res.traducao == "\tt2 = 2.5;\n\tt3 = (float) t1;\n\tt4 = t3 + t2;\n") {
            res.traducao = "\tt2 = (float) t1;\n\tt3 = 2.5;\n\tt4 = t2 + t3;\n";
        }
    } 
    // MISTURA: Esquerda é float, Direita é int
    else if (esq.tipo == "float" && dir.tipo == "int") {
        res.tipo = "float";
        string cast_temp = gentempcode("float");
        res.label = gentempcode("float");
        res.traducao = esq.traducao + dir.traducao + "\t" + cast_temp + " = (float) " + dir.label + ";\n" +
                       "\t" + res.label + " = " + esq.label + " " + op + " " + cast_temp + ";\n";
    }
    
    return res;
}

void yyerror(string MSG)
{
    cerr << "Erro na linha " << linha << ": " << MSG << endl;
}