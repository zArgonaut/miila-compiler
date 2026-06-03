%{
#include <cstdlib>
#include <iostream>
#include <map>
#include <string>
#include <vector>

#define YYSTYPE attributes

using namespace std;

enum types {
    t_null = 0,
    t_int,
    t_float,
    t_double,
    t_bool,
    t_char,
    t_string
};

struct attributes {
    string label;
    string translation;
    types type;
    bool parenthesized;
};

struct symbol {
    string name;
    types type;
    string address;
    bool istemp;
    bool implicit;
};

struct LoopCtx {
    string cont;  /* continue target (L_update para for C-style/for-in/foreach; L_top para while/do-while) */
    string brk;   /* break target (L_end) */
};

struct IterState {
    string t_coll, t_idx, t_len, t_cond, t_item;
    string l_top, l_update, l_end;
};

static int var_temp_qnt = 0;
static int label_counter = 0;
static bool uses_exit = false;
static vector<symbol> declarations;
static vector<map<string, symbol>> scope_stack;
static vector<LoopCtx> loop_stack;
static vector<string> ci_stack;
static vector<IterState> iter_stack;
static string match_expr_label;
static string match_end_label;

int yylex(void);
void yyerror(string message);

string newTempName();
string newLabel();
string typeToC(types type);
string typeToText(types type);
string formatSpec(types type);
bool isNumeric(types type);
bool canAssign(types target, types source);
bool canExplicitCast(types target, types source);
void pushScope();
void popScope();
symbol declareSymbol(const string& name, types type);
symbol getOrCreateSymbol(const string& name);
symbol createTemp(types type);
attributes makeLiteral(types type, const string& value);
attributes makeStringLiteral(const string& value);
attributes makeNullLiteral();
attributes makeIdentifier(const string& name);
attributes makeAssignment(const attributes& target, const attributes& expr);
attributes makeCompoundAssign(const attributes& target, const string& op, const attributes& expr);
attributes makePrefixInc(const string& name, const string& op);
attributes makePostfixInc(const string& name, const string& op);
attributes makeBinary(const attributes& left, const string& op, const attributes& right);
attributes makeRelational(const attributes& left, const string& op, const attributes& right);
attributes makeLogicalNot(const attributes& expr);
attributes makeCast(types targetType, const attributes& expr);
attributes makeIoOut(const string& funcName, const attributes& expr);
attributes makeMin(types type);
symbol* findSymbol(const string& name);
void checkCondition(const attributes& cond);
void printProgram(const string& body);
%}

%token TK_NUM TK_REAL TK_BOOL TK_CHAR TK_STRING
%token TK_ID TK_TYPE_INT TK_TYPE_FLOAT TK_TYPE_DOUBLE TK_TYPE_BOOLEAN TK_TYPE_CHAR TK_TYPE_STRING
%token TK_OP_GREATER_EQUAL TK_OP_LESS_EQUAL TK_OP_EQUAL TK_OP_DIF
%token TK_OP_AND TK_OP_OR
%token TK_IF TK_ELSE TK_DO TK_WHILE TK_FOR TK_FOREACH
%token TK_BREAK TK_CONTINUE TK_IN TK_CI TK_ALL TK_NULL
%token TK_MATCH TK_MOUT TK_PRINT TK_LOG TK_ERRORFN TK_MIN TK_SCAN
%token TK_ARROW TK_UNDERSCORE
%token TK_INC TK_DEC
%token TK_PLUS_EQ TK_MINUS_EQ TK_TIMES_EQ TK_DIV_EQ TK_MOD_EQ
%token TK_END TK_ERROR

%start S

%nonassoc LOWER_THAN_ELSE
%nonassoc TK_ELSE

%right '=' TK_PLUS_EQ TK_MINUS_EQ TK_TIMES_EQ TK_DIV_EQ TK_MOD_EQ
%left TK_OP_OR
%left TK_OP_AND
%left TK_OP_EQUAL TK_OP_DIF
%left '>' '<' TK_OP_GREATER_EQUAL TK_OP_LESS_EQUAL
%left '+' '-'
%left '*' '/' '%'
%right '!' UINC UCAST
%left TK_INC TK_DEC

%%

S
    : COMMANDS
      {
          printProgram($1.translation);
      }
    ;

COMMANDS
    : COMMANDS COMMAND
      {
          $$.translation = $1.translation + $2.translation;
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | /* vazio */
      {
          $$.translation = "";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    ;

BLOCK
    : '{' { pushScope(); } COMMANDS '}'
      {
          popScope();
          $$ = $3;
      }
    ;

COMMAND
    : DECLARATION ';'
      {
          $$.translation = "";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | E ';'
      {
          $$ = $1;
      }
    | IF_STMT
      { $$ = $1; }
    | WHILE_STMT
      { $$ = $1; }
    | DOWHILE_STMT
      { $$ = $1; }
    | FOR_STMT
      { $$ = $1; }
    | FOR_IN_STMT
      { $$ = $1; }
    | FOREACH_STMT
      { $$ = $1; }
    | MOUT_STMT ';'
      { $$ = $1; }
    | PRINT_STMT ';'
      { $$ = $1; }
    | LOG_STMT ';'
      { $$ = $1; }
    | ERROR_STMT ';'
      { $$ = $1; }
    | MIN_STMT ';'
      { $$ = $1; }
    | TK_BREAK ';'
      {
          if (loop_stack.empty()) yyerror("break fora de loop");
          $$.translation = "    goto " + loop_stack.back().brk + ";\n";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | TK_BREAK TK_ALL ';'
      {
          if (loop_stack.empty()) yyerror("break all fora de loop");
          $$.translation = "    goto " + loop_stack.front().brk + ";\n";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | TK_CONTINUE ';'
      {
          if (loop_stack.empty()) yyerror("continue fora de loop");
          $$.translation = "    goto " + loop_stack.back().cont + ";\n";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | MATCH_STMT
      { $$ = $1; }
    ;

DECLARATION
    : TYPE TK_ID
      {
          declareSymbol($2.label, $1.type);
          $$.translation = "";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    ;

TYPE
    : TK_TYPE_INT
      { $$.type = t_int; $$.label = ""; $$.translation = ""; $$.parenthesized = false; }
    | TK_TYPE_FLOAT
      { $$.type = t_float; $$.label = ""; $$.translation = ""; $$.parenthesized = false; }
    | TK_TYPE_DOUBLE
      { $$.type = t_double; $$.label = ""; $$.translation = ""; $$.parenthesized = false; }
    | TK_TYPE_BOOLEAN
      { $$.type = t_bool; $$.label = ""; $$.translation = ""; $$.parenthesized = false; }
    | TK_TYPE_CHAR
      { $$.type = t_char; $$.label = ""; $$.translation = ""; $$.parenthesized = false; }
    | TK_TYPE_STRING
      { $$.type = t_string; $$.label = ""; $$.translation = ""; $$.parenthesized = false; }
    ;

LVALUE
    : TK_ID
      {
          symbol target = getOrCreateSymbol($1.label);
          $$.label = target.address;
          $$.type = target.type;
          $$.translation = "";
          $$.parenthesized = false;
      }
    ;

IF_STMT
    : TK_IF E BLOCK %prec LOWER_THAN_ELSE
      {
          checkCondition($2);
          string l_end = newLabel();
          $$.translation = $2.translation
              + "    if (!" + $2.label + ") goto " + l_end + ";\n"
              + $3.translation
              + "    " + l_end + ": ;\n";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | TK_IF E BLOCK TK_ELSE BLOCK
      {
          checkCondition($2);
          string l_else = newLabel(), l_end = newLabel();
          $$.translation = $2.translation
              + "    if (!" + $2.label + ") goto " + l_else + ";\n"
              + $3.translation
              + "    goto " + l_end + ";\n"
              + "    " + l_else + ": ;\n"
              + $5.translation
              + "    " + l_end + ": ;\n";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | TK_IF E BLOCK TK_ELSE IF_STMT
      {
          checkCondition($2);
          string l_else = newLabel(), l_end = newLabel();
          $$.translation = $2.translation
              + "    if (!" + $2.label + ") goto " + l_else + ";\n"
              + $3.translation
              + "    goto " + l_end + ";\n"
              + "    " + l_else + ": ;\n"
              + $5.translation
              + "    " + l_end + ": ;\n";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    ;

WHILE_STMT
    : TK_WHILE
      {
          string ls = newLabel(), le = newLabel();
          loop_stack.push_back({ls, le});
          $$.label = "";
          $$.translation = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
      E BLOCK
      {
          checkCondition($3);
          LoopCtx ctx = loop_stack.back();
          loop_stack.pop_back();
          $$.translation = "    " + ctx.cont + ": ;\n"
              + $3.translation
              + "    if (!" + $3.label + ") goto " + ctx.brk + ";\n"
              + $4.translation
              + "    goto " + ctx.cont + ";\n"
              + "    " + ctx.brk + ": ;\n";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    ;

DOWHILE_STMT
    : TK_DO
      {
          string ls = newLabel(), le = newLabel();
          loop_stack.push_back({ls, le});
          $$.label = "";
          $$.translation = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
      BLOCK TK_WHILE E ';'
      {
          checkCondition($5);
          LoopCtx ctx = loop_stack.back();
          loop_stack.pop_back();
          $$.translation = "    " + ctx.cont + ": ;\n"
              + $3.translation
              + $5.translation
              + "    if (!" + $5.label + ") goto " + ctx.brk + ";\n"
              + "    goto " + ctx.cont + ";\n"
              + "    " + ctx.brk + ": ;\n";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    ;

/* for C-style: for init; cond; update { body }
   continue → L_update (roda o incremento antes de testar a condicao)
   break    → L_end */
FOR_STMT
    : TK_FOR E ';' E ';' E
      {
          checkCondition($4);
          string ls = newLabel(), lu = newLabel(), le = newLabel();
          loop_stack.push_back({lu, le});
          $$.label = ls;    /* armazena L_top para acao final */
          $$.translation = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
      BLOCK
      {
          string ls = $7.label;
          LoopCtx ctx = loop_stack.back();
          loop_stack.pop_back();
          $$.translation = $2.translation
              + "    " + ls + ": ;\n"
              + $4.translation
              + "    if (!" + $4.label + ") goto " + ctx.brk + ";\n"
              + $8.translation
              + "    " + ctx.cont + ": ;\n"
              + $6.translation
              + "    goto " + ls + ";\n"
              + "    " + ctx.brk + ": ;\n";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    ;

/* for...in: itera sobre string (char a char) usando verificacao de null-terminator */
FOR_IN_STMT
    : TK_FOR TK_ID TK_IN E
      {
          pushScope();
          string id_name = $2.label;
          string t_src = $4.label;

          symbol s_item = declareSymbol(id_name, t_char);
          symbol s_idx  = createTemp(t_int);
          symbol s_cond = createTemp(t_bool);

          string lu = newLabel(), le = newLabel();
          string ls = newLabel();
          loop_stack.push_back({lu, le});

          IterState is;
          is.t_coll   = t_src;
          is.t_idx    = s_idx.address;
          is.t_len    = "";   /* nao usado: sem strlen */
          is.t_cond   = s_cond.address;
          is.t_item   = s_item.address;
          is.l_top    = ls;
          is.l_update = lu;
          is.l_end    = le;
          iter_stack.push_back(is);

          $$.translation = $4.translation
              + "    " + s_idx.address + " = 0;\n";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
      BLOCK
      {
          IterState is = iter_stack.back();
          iter_stack.pop_back();
          loop_stack.pop_back();
          popScope();

          /* le char ANTES da verificacao; para em '\0' */
          $$.translation = $5.translation
              + "    " + is.l_top + ": ;\n"
              + "    " + is.t_item + " = " + is.t_coll + "[" + is.t_idx + "];\n"
              + "    " + is.t_cond + " = " + is.t_item + " != '\\0';\n"
              + "    if (!" + is.t_cond + ") goto " + is.l_end + ";\n"
              + $6.translation
              + "    " + is.l_update + ": ;\n"
              + "    " + is.t_idx + " = " + is.t_idx + " + 1;\n"
              + "    goto " + is.l_top + ";\n"
              + "    " + is.l_end + ": ;\n";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    ;

/* foreach: itera sobre string com variavel implicita ci (sem strlen) */
FOREACH_STMT
    : TK_FOREACH E
      {
          string t_src = $2.label;

          symbol s_ci   = createTemp(t_char);
          symbol s_idx  = createTemp(t_int);
          symbol s_cond = createTemp(t_bool);

          ci_stack.push_back(s_ci.address);

          string ls = newLabel(), lu = newLabel(), le = newLabel();
          loop_stack.push_back({lu, le});

          IterState is;
          is.t_coll   = t_src;
          is.t_idx    = s_idx.address;
          is.t_len    = "";   /* nao usado: sem strlen */
          is.t_cond   = s_cond.address;
          is.t_item   = s_ci.address;
          is.l_top    = ls;
          is.l_update = lu;
          is.l_end    = le;
          iter_stack.push_back(is);

          $$.translation = $2.translation
              + "    " + s_idx.address + " = 0;\n";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
      BLOCK
      {
          IterState is = iter_stack.back();
          iter_stack.pop_back();
          loop_stack.pop_back();
          ci_stack.pop_back();

          /* le char ANTES da verificacao; para em '\0' */
          $$.translation = $3.translation
              + "    " + is.l_top + ": ;\n"
              + "    " + is.t_item + " = " + is.t_coll + "[" + is.t_idx + "];\n"
              + "    " + is.t_cond + " = " + is.t_item + " != '\\0';\n"
              + "    if (!" + is.t_cond + ") goto " + is.l_end + ";\n"
              + $4.translation
              + "    " + is.l_update + ": ;\n"
              + "    " + is.t_idx + " = " + is.t_idx + " + 1;\n"
              + "    goto " + is.l_top + ";\n"
              + "    " + is.l_end + ": ;\n";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    ;

/* min: leitura com escopo controlado
   min(x)       — x deve estar declarado; le em variavel existente
   min(tipo x)  — declara x (erro se ja existe); x fica acessivel no escopo atual */
MIN_STMT
    : TK_MIN '(' TK_ID ')'
      {
          symbol* var = findSymbol($3.label);
          if (!var) yyerror("variavel '" + $3.label + "' nao declarada; declare com tipo antes ou use min(tipo nome)");
          string fmt = "\"%" + formatSpec(var->type) + "\"";
          if (var->type == t_char) fmt = "\" %c\"";
          $$.translation = "    scanf(" + fmt + ", &" + var->address + ");\n";
          $$.label = var->address;
          $$.type = var->type;
          $$.parenthesized = false;
      }
    | TK_MIN '(' TYPE TK_ID ')'
      {
          string varName = $4.label;
          if (findSymbol(varName))
              yyerror("variavel '" + varName + "' ja existe no escopo; use min(" + varName + ") para ler em variavel existente");
          symbol var = declareSymbol(varName, $3.type);
          string fmt = "\"%" + formatSpec(var.type) + "\"";
          if (var.type == t_char) fmt = "\" %c\"";
          $$.translation = "    scanf(" + fmt + ", &" + var.address + ");\n";
          $$.label = var.address;
          $$.type = var.type;
          $$.parenthesized = false;
      }
    ;

MOUT_STMT
    : TK_MOUT '(' E ')'
      { $$ = makeIoOut("printf", $3); }
    ;

/* print: saida sem \n automatico (bloco de construcao) */
PRINT_STMT
    : TK_PRINT '(' E ')'
      { $$ = makeIoOut("printf_raw", $3); }
    ;

LOG_STMT
    : TK_LOG '(' E ')'
      { $$ = makeIoOut("fprintf_stderr", $3); }
    ;

ERROR_STMT
    : TK_ERRORFN '(' E ')'
      {
          uses_exit = true;
          attributes tmp = makeIoOut("fprintf_stderr", $3);
          tmp.translation += "    exit(1);\n";
          $$ = tmp;
      }
    ;

MATCH_STMT
    : TK_MATCH
      {
          match_end_label = newLabel();
          $$.label = "";
          $$.translation = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
      E
      {
          match_expr_label = $3.label;
          $$.label = "";
          $$.translation = $3.translation;
          $$.type = t_null;
          $$.parenthesized = false;
      }
      '{' MATCH_ARMS '}'
      {
          $$.translation = $4.translation + $6.translation
              + "    " + match_end_label + ": ;\n";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    ;

MATCH_ARMS
    : MATCH_ARM
      { $$ = $1; }
    | MATCH_ARMS ',' MATCH_ARM
      {
          $$.translation = $1.translation + $3.translation;
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    ;

/* MATCH_PATS: lista de padroes separados por virgula dentro de um arm */
MATCH_PATS
    : E
      { $$ = $1; }
    | MATCH_PATS ',' E
      {
          /* acumula lista de valores; label sera uma string composta usada em MATCH_ARM */
          $$.translation = $1.translation + $3.translation;
          $$.label = $1.label + "|" + $3.label;  /* separador | para parsing posterior */
          $$.type = $1.type;
          $$.parenthesized = false;
      }
    ;

MATCH_ARM
    : MATCH_PATS TK_ARROW BLOCK
      {
          string l_next = newLabel();
          string pats_code = $1.translation;
          string pats_label = $1.label;

          /* verificar se ha multiplos valores (separados por |) */
          string cmp_code = "";
          symbol tmp_any = createTemp(t_bool);

          /* decompor lista de padroes */
          vector<string> vals;
          string cur = "";
          for (char c : pats_label) {
              if (c == '|') { if (!cur.empty()) vals.push_back(cur); cur = ""; }
              else cur += c;
          }
          if (!cur.empty()) vals.push_back(cur);

          if (vals.size() == 1) {
              /* arm de valor unico: comparacao direta */
              symbol tmp_cmp = createTemp(t_bool);
              cmp_code += "    " + tmp_cmp.address + " = " + match_expr_label + " == " + vals[0] + ";\n";
              cmp_code += "    " + tmp_any.address + " = " + tmp_cmp.address + ";\n";
          } else {
              /* arm multi-valor: OR das comparacoes */
              cmp_code += "    " + tmp_any.address + " = 0;\n";
              for (const string& v : vals) {
                  symbol tmp_cmp = createTemp(t_bool);
                  cmp_code += "    " + tmp_cmp.address + " = " + match_expr_label + " == " + v + ";\n";
                  cmp_code += "    " + tmp_any.address + " = " + tmp_any.address + " || " + tmp_cmp.address + ";\n";
              }
          }

          $$.translation = pats_code
              + cmp_code
              + "    if (!" + tmp_any.address + ") goto " + l_next + ";\n"
              + $3.translation
              + "    goto " + match_end_label + ";\n"
              + "    " + l_next + ": ;\n";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | TK_UNDERSCORE TK_ARROW BLOCK
      {
          $$.translation = $3.translation
              + "    goto " + match_end_label + ";\n";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    ;

E
    : LVALUE '=' E
      { $$ = makeAssignment($1, $3); }
    | LVALUE TK_PLUS_EQ E
      { $$ = makeCompoundAssign($1, "+", $3); }
    | LVALUE TK_MINUS_EQ E
      { $$ = makeCompoundAssign($1, "-", $3); }
    | LVALUE TK_TIMES_EQ E
      { $$ = makeCompoundAssign($1, "*", $3); }
    | LVALUE TK_DIV_EQ E
      { $$ = makeCompoundAssign($1, "/", $3); }
    | LVALUE TK_MOD_EQ E
      { $$ = makeCompoundAssign($1, "%", $3); }
    | TK_INC TK_ID %prec UINC
      { $$ = makePrefixInc($2.label, "+"); }
    | TK_DEC TK_ID %prec UINC
      { $$ = makePrefixInc($2.label, "-"); }
    | TK_ID TK_INC
      { $$ = makePostfixInc($1.label, "+"); }
    | TK_ID TK_DEC
      { $$ = makePostfixInc($1.label, "-"); }
    | '(' E ')'
      {
          $$ = $2;
          $$.parenthesized = true;
      }
    | '(' TYPE ')' E %prec UCAST
      { $$ = makeCast($2.type, $4); }
    | E '+' E
      { $$ = makeBinary($1, $2.label, $3); }
    | E '-' E
      { $$ = makeBinary($1, $2.label, $3); }
    | E '*' E
      { $$ = makeBinary($1, $2.label, $3); }
    | E '/' E
      { $$ = makeBinary($1, $2.label, $3); }
    | E '%' E
      { $$ = makeBinary($1, $2.label, $3); }
    | E '>' E
      { $$ = makeRelational($1, $2.label, $3); }
    | E '<' E
      { $$ = makeRelational($1, $2.label, $3); }
    | E TK_OP_GREATER_EQUAL E
      { $$ = makeRelational($1, $2.label, $3); }
    | E TK_OP_LESS_EQUAL E
      { $$ = makeRelational($1, $2.label, $3); }
    | E TK_OP_EQUAL E
      { $$ = makeRelational($1, $2.label, $3); }
    | E TK_OP_DIF E
      { $$ = makeRelational($1, $2.label, $3); }
    | E TK_OP_AND E
      { $$ = makeBinary($1, $2.label, $3); }
    | E TK_OP_OR E
      { $$ = makeBinary($1, $2.label, $3); }
    | '!' E
      { $$ = makeLogicalNot($2); }
    | TK_NUM
      { $$ = makeLiteral(t_int, $1.label); }
    | TK_REAL
      { $$ = makeLiteral(t_float, $1.label); }
    | TK_BOOL
      { $$ = makeLiteral(t_bool, $1.label); }
    | TK_CHAR
      { $$ = makeLiteral(t_char, $1.label); }
    | TK_STRING
      { $$ = makeStringLiteral($1.label); }
    | TK_NULL
      { $$ = makeNullLiteral(); }
    | TK_CI
      {
          if (ci_stack.empty()) yyerror("ci usado fora de foreach");
          $$.label = ci_stack.back();
          $$.type = t_char;
          $$.translation = "";
          $$.parenthesized = false;
      }
    | TK_SCAN '(' TYPE ')'
      { $$ = makeMin($3.type); }
    | TK_SCAN '(' ')'
      { $$ = makeMin(t_int); }
    | TK_ID
      { $$ = makeIdentifier($1.label); }
    ;

%%

#include "lex.yy.c"

string newTempName()
{
    ++var_temp_qnt;
    return "T" + to_string(var_temp_qnt);
}

string newLabel()
{
    ++label_counter;
    return "L" + to_string(label_counter);
}

void pushScope()
{
    scope_stack.push_back({});
}

void popScope()
{
    if (!scope_stack.empty()) scope_stack.pop_back();
}

string typeToC(types type)
{
    switch (type) {
        case t_int:    return "int";
        case t_float:  return "float";
        case t_double: return "double";
        case t_bool:   return "int";
        case t_char:   return "char";
        case t_string: return "char*";
        default:       return "void";
    }
}

string typeToText(types type)
{
    switch (type) {
        case t_int:    return "int";
        case t_float:  return "float";
        case t_double: return "double";
        case t_bool:   return "boolean";
        case t_char:   return "char";
        case t_string: return "string";
        default:       return "null";
    }
}

string formatSpec(types type)
{
    switch (type) {
        case t_float:
        case t_double: return "f";
        case t_char:   return "c";
        case t_string: return "s";
        default:       return "d";
    }
}

bool isNumeric(types type)
{
    return type == t_int || type == t_float || type == t_double;
}

bool canAssign(types target, types source)
{
    if (target == source) return true;
    /* coercao implicita upcast: int → float → double */
    if (target == t_float  && source == t_int)   return true;
    if (target == t_double && source == t_int)   return true;
    if (target == t_double && source == t_float) return true;
    /* downcast numerico (possivel perda de precisao — responsabilidade do programador) */
    if (target == t_int   && (source == t_float || source == t_double)) return true;
    if (target == t_float && source == t_double) return true;
    /* bool aceita int: 0 = false, qualquer outro = true */
    if (target == t_bool && source == t_int) return true;
    /* null pode ser atribuido a qualquer tipo (valor 0/NULL) */
    if (source == t_null) return true;
    return false;
}

bool canExplicitCast(types target, types source)
{
    if (target == t_null || source == t_null) return false;
    return true;
}

/* verifica condicao: sem parenteses exige bool; com parenteses aceita numericos */
void checkCondition(const attributes& cond)
{
    if (cond.parenthesized) {
        /* truthiness: aceita int, float, double, char, bool */
        if (cond.type == t_string)
            yyerror("truthiness de string nao suportada; use comparacao explicita");
        if (cond.type == t_null)
            yyerror("condicao nula invalida");
    } else {
        if (cond.type != t_bool)
            yyerror("condicao deve ser boolean; use parenteses para truthiness: if (" + cond.label + ")");
    }
}

symbol declareSymbol(const string& name, types type)
{
    if (scope_stack.back().count(name)) {
        yyerror("variavel ja declarada: " + name);
    }

    symbol variable;
    variable.name = name;
    variable.type = type;
    variable.address = newTempName();
    variable.istemp = false;
    variable.implicit = false;

    scope_stack.back()[name] = variable;
    declarations.push_back(variable);
    return variable;
}

symbol getOrCreateSymbol(const string& name)
{
    for (int i = (int)scope_stack.size() - 1; i >= 0; i--) {
        auto it = scope_stack[i].find(name);
        if (it != scope_stack[i].end()) return it->second;
    }

    symbol variable;
    variable.name = name;
    variable.type = t_int;
    variable.address = newTempName();
    variable.istemp = false;
    variable.implicit = true;

    scope_stack.back()[name] = variable;
    declarations.push_back(variable);
    return variable;
}

symbol createTemp(types type)
{
    symbol temporary;
    temporary.name = "";
    temporary.type = type;
    temporary.address = newTempName();
    temporary.istemp = true;
    temporary.implicit = false;

    declarations.push_back(temporary);
    return temporary;
}

attributes makeLiteral(types type, const string& value)
{
    symbol temporary = createTemp(type);

    attributes result;
    result.label = temporary.address;
    result.type = type;
    result.parenthesized = false;
    result.translation = "    " + result.label + " = " + value + ";\n";
    return result;
}

attributes makeStringLiteral(const string& value)
{
    attributes result;
    result.label = value;
    result.type = t_string;
    result.translation = "";
    result.parenthesized = false;
    return result;
}

attributes makeNullLiteral()
{
    attributes result;
    result.label = "0";
    result.type = t_null;
    result.translation = "";
    result.parenthesized = false;
    return result;
}

attributes makeIdentifier(const string& name)
{
    symbol variable = getOrCreateSymbol(name);

    attributes result;
    result.label = variable.address;
    result.type = variable.type;
    result.translation = "";
    result.parenthesized = false;
    return result;
}

attributes makeAssignment(const attributes& target, const attributes& expr)
{
    if (!canAssign(target.type, expr.type)) {
        yyerror("nao e possivel atribuir " + typeToText(expr.type) + " a " + typeToText(target.type));
    }

    attributes result;
    result.label = target.label;
    result.type = target.type;
    result.parenthesized = false;
    result.translation = expr.translation;

    if (target.type == expr.type || expr.type == t_null) {
        result.translation += "    " + target.label + " = " + expr.label + ";\n";
    } else {
        symbol converted = createTemp(target.type);
        result.translation += "    " + converted.address + " = (" + typeToC(target.type) + ") " + expr.label + ";\n";
        result.translation += "    " + target.label + " = " + converted.address + ";\n";
    }

    return result;
}

attributes makeCompoundAssign(const attributes& target, const string& op, const attributes& expr)
{
    /* desugar: target op= expr  →  target = target op expr */
    attributes lhs;
    lhs.label = target.label;
    lhs.type = target.type;
    lhs.translation = "";
    lhs.parenthesized = false;

    attributes rhs = makeBinary(lhs, op, expr);
    return makeAssignment(target, rhs);
}

attributes makePrefixInc(const string& name, const string& op)
{
    /* ++x ou --x: T1 = x op 1; x = T1; resultado = T1 */
    symbol var = getOrCreateSymbol(name);
    if (!isNumeric(var.type)) yyerror("++ / -- requer tipo numerico");

    attributes lhs;
    lhs.label = var.address;
    lhs.type = var.type;
    lhs.translation = "";
    lhs.parenthesized = false;

    attributes one = makeLiteral(t_int, "1");
    attributes result = makeBinary(lhs, op, one);

    result.translation += "    " + var.address + " = " + result.label + ";\n";
    return result;
}

attributes makePostfixInc(const string& name, const string& op)
{
    /* x++ ou x--: T_old = x; T1 = x op 1; x = T1; resultado = T_old */
    symbol var = getOrCreateSymbol(name);
    if (!isNumeric(var.type)) yyerror("++ / -- requer tipo numerico");

    symbol old_val = createTemp(var.type);
    string save_code = "    " + old_val.address + " = " + var.address + ";\n";

    attributes lhs;
    lhs.label = var.address;
    lhs.type = var.type;
    lhs.translation = "";
    lhs.parenthesized = false;

    attributes one = makeLiteral(t_int, "1");
    attributes incremented = makeBinary(lhs, op, one);

    incremented.translation = save_code + incremented.translation;
    incremented.translation += "    " + var.address + " = " + incremented.label + ";\n";

    incremented.label = old_val.address;
    incremented.type = var.type;
    return incremented;
}

/* promove tipos numericos para o tipo maior da hierarquia int → float → double */
static types promoteNumeric(types a, types b)
{
    if (a == t_double || b == t_double) return t_double;
    if (a == t_float  || b == t_float)  return t_float;
    return t_int;
}

static string& promoteArg(string& code, attributes& arg, types target)
{
    if (arg.type != target) {
        symbol conv = createTemp(target);
        code += "    " + conv.address + " = (" + typeToC(target) + ") " + arg.label + ";\n";
        arg.label = conv.address;
        arg.type  = target;
    }
    return code;
}

attributes makeBinary(const attributes& left, const string& op, const attributes& right)
{
    attributes l = left;
    attributes r = right;
    string code = l.translation + r.translation;
    types resultType = t_null;

    if (op == "&&" || op == "||") {
        if (l.type != t_bool || r.type != t_bool) {
            yyerror("operador " + op + " exige operandos boolean");
        }
        resultType = t_bool;
    } else if (op == "%") {
        if (l.type != t_int || r.type != t_int) {
            yyerror("operador % exige operandos int");
        }
        resultType = t_int;
    } else if (op == "+" || op == "-" || op == "*" || op == "/") {
        if (!isNumeric(l.type) || !isNumeric(r.type)) {
            yyerror("operador " + op + " exige operandos numericos");
        }
        resultType = promoteNumeric(l.type, r.type);
        promoteArg(code, l, resultType);
        promoteArg(code, r, resultType);
    } else {
        yyerror("operador binario desconhecido: " + op);
    }

    symbol temporary = createTemp(resultType);

    attributes result;
    result.label = temporary.address;
    result.type = resultType;
    result.parenthesized = false;
    result.translation = code + "    " + result.label + " = " + l.label + " " + op + " " + r.label + ";\n";
    return result;
}

attributes makeRelational(const attributes& left, const string& op, const attributes& right)
{
    attributes l = left;
    attributes r = right;
    string code = l.translation + r.translation;

    bool equalityOp = (op == "==" || op == "!=");

    if (isNumeric(l.type) && isNumeric(r.type)) {
        types cmpType = promoteNumeric(l.type, r.type);
        promoteArg(code, l, cmpType);
        promoteArg(code, r, cmpType);
    } else if (equalityOp && l.type == r.type && (l.type == t_bool || l.type == t_char)) {
        /* igualdade entre bool/char do mesmo tipo: permitido */
    } else if (equalityOp && (l.type == t_null || r.type == t_null)) {
        /* comparacao com null (0): permitido */
    } else {
        yyerror("operador " + op + " nao aceita " + typeToText(l.type) + " e " + typeToText(r.type));
    }

    symbol temporary = createTemp(t_bool);

    attributes result;
    result.label = temporary.address;
    result.type = t_bool;
    result.parenthesized = false;
    result.translation = code + "    " + result.label + " = " + l.label + " " + op + " " + r.label + ";\n";
    return result;
}

attributes makeLogicalNot(const attributes& expr)
{
    if (expr.type != t_bool) {
        yyerror("operador ! exige operando boolean");
    }

    symbol temporary = createTemp(t_bool);

    attributes result;
    result.label = temporary.address;
    result.type = t_bool;
    result.parenthesized = false;
    result.translation = expr.translation + "    " + result.label + " = !" + expr.label + ";\n";
    return result;
}

attributes makeCast(types targetType, const attributes& expr)
{
    if (!canExplicitCast(targetType, expr.type)) {
        yyerror("cast invalido de " + typeToText(expr.type) + " para " + typeToText(targetType));
    }

    symbol temporary = createTemp(targetType);

    attributes result;
    result.label = temporary.address;
    result.type = targetType;
    result.parenthesized = false;
    result.translation = expr.translation + "    " + result.label + " = (" + typeToC(targetType) + ") " + expr.label + ";\n";
    return result;
}

attributes makeIoOut(const string& funcName, const attributes& expr)
{
    /* mout: adiciona \n automatico (saida simples e completa)
       print: sem \n (bloco de construcao de saida complexa)
       log/error: vai para stderr */
    string fmtSpec;
    switch (expr.type) {
        case t_float:
        case t_double: fmtSpec = "f"; break;
        case t_char:   fmtSpec = "c"; break;
        case t_string: fmtSpec = "s"; break;
        default:       fmtSpec = "d"; break;
    }

    bool with_newline = (funcName != "printf_raw");
    bool is_stderr    = (funcName == "fprintf_stderr");
    string fmt = "\"%" + fmtSpec + (with_newline ? "\\n" : "") + "\"";

    attributes result;
    result.label = "";
    result.type = t_null;
    result.parenthesized = false;

    if (is_stderr) {
        result.translation = expr.translation + "    fprintf(stderr, " + fmt + ", " + expr.label + ");\n";
    } else {
        result.translation = expr.translation + "    printf(" + fmt + ", " + expr.label + ");\n";
    }
    return result;
}

attributes makeMin(types type)
{
    symbol tmp = createTemp(type);
    string fmt = "\"%";
    fmt += formatSpec(type);
    fmt += "\"";

    string addr = "&" + tmp.address;
    /* para char, scanf precisa de " %c" para pular whitespace */
    if (type == t_char) fmt = "\" %c\"";

    attributes result;
    result.label = tmp.address;
    result.type = type;
    result.parenthesized = false;
    result.translation = "    scanf(" + fmt + ", " + addr + ");\n";
    return result;
}

symbol* findSymbol(const string& name)
{
    for (int i = (int)scope_stack.size() - 1; i >= 0; i--) {
        auto it = scope_stack[i].find(name);
        if (it != scope_stack[i].end()) return &it->second;
    }
    return nullptr;
}

void printProgram(const string& body)
{
    cout << "#include <stdio.h>\n";
    if (uses_exit) cout << "#include <stdlib.h>\n";
    cout << "\n";

    cout << "int main(void) {\n";

    for (const symbol& declaration : declarations) {
        cout << "    " << typeToC(declaration.type) << " " << declaration.address << ";";
        if (!declaration.istemp && !declaration.name.empty()) {
            cout << " /* " << declaration.name;
            if (declaration.implicit) cout << " : declaracao implicita int";
            cout << " */";
        }
        cout << "\n";
    }

    if (!declarations.empty() || !body.empty()) {
        cout << "\n";
    }

    cout << body;
    cout << "    return 0;\n";
    cout << "}\n";
}

void yyerror(string message)
{
    cerr << "Erro: " << message << endl;
    exit(1);
}

int main(int argc, char *argv[])
{
    (void) argc;
    (void) argv;

    scope_stack.push_back({});
    return yyparse();
}
