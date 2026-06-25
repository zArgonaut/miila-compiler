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
    t_string,
    t_void
};

struct symbol;

struct attributes {
    string label;
    string translation;
    types type = t_null;
    bool parenthesized = false;
    string name;
    bool resolved = false;
    bool isLiteral = false;
    bool freeable = false;
    int line = 0;
    int col = 0;

    symbol* arr = nullptr;
};

struct symbol {
    string name;
    types type;
    string address;
    bool istemp = false;
    bool implicit = false;

    bool is_array = false;
    bool is_dynamic = false;
    int dims = 0;
    types elem_type = t_null;
    int size0 = 0;
    int size1 = 0;
    string len_addr;
    string cap_addr;
};

struct LoopCtx {
    string cont;
    string brk;
    bool cont_used = false;
};

struct IterState {
    string t_coll, t_idx, t_len, t_cond, t_item;
    string l_top, l_update, l_end;
    bool is_array = false;
    string size_expr;

    bool is_matrix = false;
    bool by_col = false;
    string m_ti, m_tj;
    string m_li, m_lj;
    string m_cond_out, m_cond_in;
    string l_out_top, l_in_top, l_in_upd, l_in_end, l_out_end;
};

struct FuncSig {
    types ret;
    vector<types> params;
};

struct FuncCtx {
    string name;
    types ret_type;
    vector<symbol> params;
    vector<symbol> decls;
    string body;
    bool has_return;
};

static int var_temp_qnt = 0;
static int label_counter = 0;
static bool uses_exit = false;

struct CompileError { int line; int col; string msg; bool warning; };
static vector<CompileError> g_errors;
int cur_line = 1;
int cur_col = 1;
int cur_tok_col = 1;
void reportWarning(int line, const string& msg);
bool hadErrors();
static bool uses_strings = false;
static bool uses_strdup = false;
static bool uses_strcat = false;
static bool uses_charstr = false;
static vector<symbol> declarations;
static vector<map<string, symbol>> scope_stack;
static vector<LoopCtx> loop_stack;
static vector<string> ci_stack;
static vector<types> ci_type_stack;
static vector<IterState> iter_stack;
static string match_expr_label;
static string match_end_label;

static map<string, FuncSig> function_table;
static vector<FuncCtx> func_stack;
static vector<FuncCtx> finished_functions;
static vector<map<string, symbol>> saved_scope_stack;
static vector<vector<attributes>> arg_stack;
static types last_param_type = t_void;
static vector<vector<attributes>> elem_stack;
static vector<vector<vector<attributes>>> matrix_rows;

struct StrPart { bool is_expr; string frag; attributes expr; };
static vector<vector<StrPart>> strpart_stack;
static bool uses_intstr = false;
static bool uses_doublestr = false;
static bool uses_boolstr = false;
static bool uses_powi = false;
static bool uses_powd = false;
static bool uses_arrays = false;
static bool uses_bounds = false;

int yylex(void);
void yyerror(string message);

string newTempName();
string newLabel();
string typeToC(types type);
string typeToText(types type);
string formatSpec(types type);
bool isNumeric(types type);
bool isStringy(types type);
bool canAssign(types target, types source);
bool canAssignExpr(types target, const attributes& expr);
bool canExplicitCast(types target, types source);
void pushScope();
void popScope();
symbol declareSymbol(const string& name, types type, bool implicit = false);
symbol createTemp(types type);
attributes makeStringConcat(attributes left, attributes right);
attributes makeLiteral(types type, const string& value);
attributes makeStringLiteral(const string& value);
attributes buildString(vector<StrPart>& parts);
attributes makeNullLiteral();
attributes makeIdentifier(const string& name);
attributes makeAssignment(const attributes& target, const attributes& expr);
attributes makeCompoundAssign(const attributes& target, const string& op, const attributes& expr);
attributes makePrefixInc(const string& name, const string& op);
attributes makePostfixInc(const string& name, const string& op);
attributes makeBinary(const attributes& left, const string& op, const attributes& right);
attributes makeRelational(const attributes& left, const string& op, const attributes& right);
attributes makeLogicalNot(const attributes& expr);
attributes makeUnaryMinus(const attributes& expr);
attributes makePow(const attributes& base, const attributes& exp);
attributes makeCast(types targetType, const attributes& expr);
attributes makeIoOut(const string& funcName, const attributes& expr);
attributes makeMin(types type);
symbol* findSymbol(const string& name);
void checkCondition(const attributes& cond);
void printProgram(const string& body);

vector<symbol>& activeDecls();
void beginFunction(types ret, const string& name);
void registerSignature();
void endFunction(const string& body);
symbol declareParam(const string& name, types type);
attributes makeCall(const string& name, vector<attributes>& args);
attributes makeReturn(attributes* expr);

void noArray(const attributes& a, const string& ctx);
symbol declareArrayFixed(const string& name, types elemType, int size, int dims, int size1);
symbol declareArrayDynamic(const string& name, types elemType);
string emitArrayInit(const symbol& sym, vector<attributes>& elems);
string emitArrayInitDynamic(const symbol& sym, vector<attributes>& elems);
string makePush(const string& name, const attributes& value);
attributes makeArrayAccess(const string& name, const attributes& idx);
attributes makeArrayAccessLValue(const string& name, const attributes& idx);
string emitMatrixInit(const symbol& sym, vector<vector<attributes>>& rows);
attributes makeMatrixAccess(const string& name, const attributes& i, const attributes& j);
attributes makeMatrixAccessLValue(const string& name, const attributes& i, const attributes& j);
attributes makeLen(const string& name);
string emitIterLoop(const IterState& is, const string& body, bool cont_used);
string emitMatrixForeach(const IterState& is, const string& body, bool cont_used);
%}

%token TK_NUM TK_REAL TK_BOOL TK_CHAR TK_STRING
%token TK_ID TK_TYPE_INT TK_TYPE_FLOAT TK_TYPE_DOUBLE TK_TYPE_BOOLEAN TK_TYPE_CHAR TK_TYPE_STRING
%token TK_OP_GREATER_EQUAL TK_OP_LESS_EQUAL TK_OP_EQUAL TK_OP_DIF
%token TK_OP_AND TK_OP_OR
%token TK_IF TK_ELSE TK_DO TK_WHILE TK_FOR TK_FOREACH
%token TK_BREAK TK_CONTINUE TK_IN TK_CI TK_ALL TK_NULL
%token TK_MATCH TK_MOUT TK_PRINT TK_LOG TK_ERRORFN TK_MIN TK_SCAN
%token TK_FNC TK_RETURN
%token TK_LEN TK_PUSH TK_EXT TK_BY
%token TK_STR_BEGIN TK_STR_END TK_STR_CHARS TK_INTERP_BEGIN TK_INTERP_END
%token TK_ARROW TK_UNDERSCORE
%token TK_INC TK_DEC TK_POW
%token TK_PLUS_EQ TK_MINUS_EQ TK_TIMES_EQ TK_DIV_EQ TK_MOD_EQ
%token TK_END TK_ERROR

%start S

%define parse.error verbose

%nonassoc LOWER_THAN_ELSE
%nonassoc TK_ELSE

%right '=' TK_PLUS_EQ TK_MINUS_EQ TK_TIMES_EQ TK_DIV_EQ TK_MOD_EQ
%left TK_OP_OR
%left TK_OP_AND
%left TK_OP_EQUAL TK_OP_DIF
%left '>' '<' TK_OP_GREATER_EQUAL TK_OP_LESS_EQUAL
%left '+' '-'
%left '*' '/' '%'
%right TK_POW
%right '!' UINC UCAST UMINUS
%left TK_INC TK_DEC

%%

S
    : COMMANDS
      {

          if (!hadErrors())
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
    |
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
          $$ = $1;
      }
    | E ';'
      {
          $$ = $1;

          if ($1.type == t_string && $1.freeable) {
              $$.translation += "    free(" + $1.label + ");\n";
          }
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
    | PUSH_STMT ';'
      { $$ = $1; }
    | TK_BREAK ';'
      {
          if (loop_stack.empty()) { yyerror("break fora de loop"); $$.translation = ""; }
          else $$.translation = "    goto " + loop_stack.back().brk + ";\n";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | TK_BREAK TK_ALL ';'
      {
          if (loop_stack.empty()) { yyerror("break all fora de loop"); $$.translation = ""; }
          else $$.translation = "    goto " + loop_stack.front().brk + ";\n";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | TK_CONTINUE ';'
      {
          if (loop_stack.empty()) { yyerror("continue fora de loop"); $$.translation = ""; }
          else {
              loop_stack.back().cont_used = true;
              $$.translation = "    goto " + loop_stack.back().cont + ";\n";
          }
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | MATCH_STMT
      { $$ = $1; }
    | FUNC_DEF
      { $$ = $1; }
    | TK_RETURN E ';'
      { $$ = makeReturn(&$2); }
    | TK_RETURN ';'
      {
          $$ = makeReturn(nullptr);
      }
    | error ';'
      {

          yyerrok;
          $$.translation = "";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
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
    | TYPE TK_ID '=' E
      {

          symbol var = declareSymbol($2.label, $1.type);
          attributes tgt;
          tgt.resolved = true;
          tgt.label = var.address;
          tgt.type = var.type;
          tgt.name = var.name;
          attributes assign = makeAssignment(tgt, $4);
          $$.translation = assign.translation;
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | TYPE TK_ID '[' TK_NUM ']'
      {

          declareArrayFixed($2.label, $1.type, atoi($4.label.c_str()), 1, 0);
          $$.translation = "";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | TYPE TK_ID '[' TK_NUM ']' '=' '{' { elem_stack.push_back(vector<attributes>()); } ELEMS '}'
      {

          int n = atoi($4.label.c_str());
          vector<attributes> elems = elem_stack.back();
          elem_stack.pop_back();
          if ((int)elems.size() != n)
              yyerror("vetor '" + $2.label + "' declarado com tamanho " + to_string(n) +
                      " mas inicializado com " + to_string(elems.size()) + " elemento(s)");
          symbol s = declareArrayFixed($2.label, $1.type, n, 1, 0);
          $$.translation = emitArrayInit(s, elems);
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | TYPE TK_ID '[' ']' '=' '{' { elem_stack.push_back(vector<attributes>()); } ELEMS '}'
      {

          vector<attributes> elems = elem_stack.back();
          elem_stack.pop_back();
          if (elems.empty())
              yyerror("vetor '" + $2.label + "' com tamanho inferido precisa de ao menos um elemento");
          symbol s = declareArrayFixed($2.label, $1.type, (int)elems.size(), 1, 0);
          $$.translation = emitArrayInit(s, elems);
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | TYPE TK_ID '[' TK_EXT ']'
      {

          declareArrayDynamic($2.label, $1.type);
          $$.translation = "";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | TYPE TK_ID '[' TK_EXT ']' '=' '{' { elem_stack.push_back(vector<attributes>()); } ELEMS '}'
      {

          vector<attributes> elems = elem_stack.back();
          elem_stack.pop_back();
          if (elems.empty())
              yyerror("use 'int " + $2.label + "[ext]' para um vetor dinamico vazio");
          symbol s = declareArrayDynamic($2.label, $1.type);
          $$.translation = emitArrayInitDynamic(s, elems);
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | TYPE TK_ID '[' TK_NUM ']' '[' TK_NUM ']'
      {

          declareArrayFixed($2.label, $1.type, atoi($4.label.c_str()), 2, atoi($7.label.c_str()));
          $$.translation = "";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | TYPE TK_ID '[' TK_NUM ']' '[' TK_NUM ']' '=' MATRIX_INIT
      {

          int L = atoi($4.label.c_str()), C = atoi($7.label.c_str());
          vector<vector<attributes>> rows = matrix_rows.back();
          matrix_rows.pop_back();
          if ((int)rows.size() != L)
              yyerror("matriz '" + $2.label + "' declarada com " + to_string(L) +
                      " linha(s) mas inicializada com " + to_string(rows.size()));
          for (auto& row : rows)
              if ((int)row.size() != C)
                  yyerror("matriz '" + $2.label + "': cada linha deve ter " + to_string(C) + " coluna(s)");
          symbol s = declareArrayFixed($2.label, $1.type, L, 2, C);
          $$.translation = emitMatrixInit(s, rows);
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | TYPE TK_ID '[' ']' '[' ']' '=' MATRIX_INIT
      {

          vector<vector<attributes>> rows = matrix_rows.back();
          matrix_rows.pop_back();
          if (rows.empty())
              yyerror("matriz '" + $2.label + "' com dimensoes inferidas precisa de ao menos uma linha");
          int L = (int)rows.size(), C = (int)rows[0].size();
          for (auto& row : rows)
              if ((int)row.size() != C)
                  yyerror("matriz '" + $2.label + "': todas as linhas devem ter o mesmo numero de colunas");
          symbol s = declareArrayFixed($2.label, $1.type, L, 2, C);
          $$.translation = emitMatrixInit(s, rows);
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    ;

MATRIX_INIT
    : '{' { matrix_rows.push_back(vector<vector<attributes>>()); } ROW_LIST '}'
    ;

ROW_LIST
    : ROW
    | ROW_LIST ',' ROW
    ;

ROW
    : '{' { elem_stack.push_back(vector<attributes>()); } ELEMS '}'
      {
          matrix_rows.back().push_back(elem_stack.back());
          elem_stack.pop_back();
      }
    ;

ELEMS
    :
    | ELEM_ITEMS
    ;

ELEM_ITEMS
    : E
      { elem_stack.back().push_back($1); }
    | ELEM_ITEMS ',' E
      { elem_stack.back().push_back($3); }
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
          symbol* target = findSymbol($1.label);
          $$.name = $1.label;
          $$.translation = "";
          $$.parenthesized = false;
          if (target) {
              $$.resolved = true;
              $$.label = target->address;
              $$.type = target->type;
          } else {

              $$.resolved = false;
              $$.label = "";
              $$.type = t_null;
          }
      }
    | TK_ID '[' E ']' '[' E ']'
      { $$ = makeMatrixAccessLValue($1.label, $3, $6); }
    | TK_ID '[' E ']'
      { $$ = makeArrayAccessLValue($1.label, $3); }
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

FOR_STMT
    : TK_FOR E ';' E ';' E
      {
          checkCondition($4);
          string ls = newLabel(), lu = newLabel(), le = newLabel();
          loop_stack.push_back({lu, le});
          $$.label = ls;
          $$.translation = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
      BLOCK
      {
          string ls = $7.label;
          LoopCtx ctx = loop_stack.back();
          loop_stack.pop_back();
          string cont_label = ctx.cont_used ? ("    " + ctx.cont + ": ;\n") : "";
          $$.translation = $2.translation
              + "    " + ls + ": ;\n"
              + $4.translation
              + "    if (!" + $4.label + ") goto " + ctx.brk + ";\n"
              + $8.translation
              + cont_label
              + $6.translation
              + "    goto " + ls + ";\n"
              + "    " + ctx.brk + ": ;\n";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    ;

FOR_IN_STMT
    : TK_FOR TK_ID TK_IN E
      {
          pushScope();
          string id_name = $2.label;

          bool isArr = ($4.arr != nullptr);
          if (isArr && $4.arr->dims != 1)
              yyerror("for...in sobre matriz nao suportado; use indices ou foreach");
          types itemType = isArr ? $4.arr->elem_type : t_char;
          string coll = isArr ? $4.arr->address : $4.label;
          string sizeExpr = isArr ? ($4.arr->is_dynamic ? $4.arr->len_addr
                                                          : to_string($4.arr->size0)) : "";

          symbol s_item = declareSymbol(id_name, itemType);
          symbol s_idx  = createTemp(t_int);
          symbol s_cond = createTemp(t_bool);

          string lu = newLabel(), le = newLabel();
          string ls = newLabel();
          loop_stack.push_back({lu, le});

          IterState is;
          is.t_coll   = coll;
          is.t_idx    = s_idx.address;
          is.t_cond   = s_cond.address;
          is.t_item   = s_item.address;
          is.l_top    = ls;
          is.l_update = lu;
          is.l_end    = le;
          is.is_array = isArr;
          is.size_expr = sizeExpr;
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
          bool cu = loop_stack.back().cont_used;
          loop_stack.pop_back();
          popScope();
          $$.translation = $5.translation + emitIterLoop(is, $6.translation, cu);
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    ;

FOREACH_STMT
    : TK_FOREACH E ITER_MOD
      {
          bool byCol = ($3.label == "col");
          bool isArr = ($2.arr != nullptr);
          bool isMatrix = (isArr && $2.arr->dims == 2);

          if (byCol && !isMatrix)
              yyerror("'by col'/'by row' so se aplica a foreach sobre matriz");

          if (isMatrix) {
              symbol* M = $2.arr;
              types itemType = M->elem_type;
              symbol s_ci  = createTemp(itemType);
              symbol s_i   = createTemp(t_int);
              symbol s_j   = createTemp(t_int);
              symbol s_co  = createTemp(t_bool);
              symbol s_cin = createTemp(t_bool);

              ci_stack.push_back(s_ci.address);
              ci_type_stack.push_back(itemType);

              string lot = newLabel(), lit = newLabel(), liu = newLabel(),
                     lie = newLabel(), loe = newLabel();

              loop_stack.push_back({liu, loe});

              IterState is;
              is.is_matrix   = true;
              is.by_col      = byCol;
              is.t_coll      = M->address;
              is.t_item      = s_ci.address;
              is.m_ti        = s_i.address;
              is.m_tj        = s_j.address;
              is.m_li        = to_string(M->size0);
              is.m_lj        = to_string(M->size1);
              is.m_cond_out  = s_co.address;
              is.m_cond_in   = s_cin.address;
              is.l_out_top   = lot;
              is.l_in_top    = lit;
              is.l_in_upd    = liu;
              is.l_in_end    = lie;
              is.l_out_end   = loe;
              iter_stack.push_back(is);

              $$.translation = $2.translation;
          } else {
              types itemType = isArr ? $2.arr->elem_type : t_char;
              string coll = isArr ? $2.arr->address : $2.label;
              string sizeExpr = isArr ? ($2.arr->is_dynamic ? $2.arr->len_addr
                                                             : to_string($2.arr->size0)) : "";
              symbol s_ci   = createTemp(itemType);
              symbol s_idx  = createTemp(t_int);
              symbol s_cond = createTemp(t_bool);
              ci_stack.push_back(s_ci.address);
              ci_type_stack.push_back(itemType);
              string ls = newLabel(), lu = newLabel(), le = newLabel();
              loop_stack.push_back({lu, le});
              IterState is;
              is.t_coll   = coll;
              is.t_idx    = s_idx.address;
              is.t_cond   = s_cond.address;
              is.t_item   = s_ci.address;
              is.l_top    = ls;
              is.l_update = lu;
              is.l_end    = le;
              is.is_array = isArr;
              is.size_expr = sizeExpr;
              iter_stack.push_back(is);
              $$.translation = $2.translation + "    " + s_idx.address + " = 0;\n";
          }
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
      BLOCK
      {
          IterState is = iter_stack.back();
          iter_stack.pop_back();
          bool cu = loop_stack.back().cont_used;
          loop_stack.pop_back();
          ci_stack.pop_back();
          ci_type_stack.pop_back();
          if (is.is_matrix)
              $$.translation = $4.translation + emitMatrixForeach(is, $5.translation, cu);
          else
              $$.translation = $4.translation + emitIterLoop(is, $5.translation, cu);
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    ;

ITER_MOD
    :
      { $$.label = "row"; $$.type = t_null; $$.translation = ""; $$.parenthesized = false; }
    | TK_BY TK_ID
      {
          if ($2.label != "col" && $2.label != "row")
              yyerror("modificador de foreach invalido: 'by " + $2.label + "' (use 'by col' ou 'by row')");
          $$.label = $2.label;
          $$.type = t_null;
          $$.translation = "";
          $$.parenthesized = false;
      }
    ;

MIN_STMT
    : TK_MIN '(' TK_ID ')'
      {
          symbol* var = findSymbol($3.label);
          if (!var) {
              yyerror("variavel '" + $3.label + "' nao declarada; declare com tipo antes ou use min(tipo nome)");
              $$.translation = "";
              $$.label = "";
              $$.type = t_null;
              $$.parenthesized = false;
          } else {
              string fmt = "\"%" + formatSpec(var->type) + "\"";
              if (var->type == t_char) fmt = "\" %c\"";
              $$.translation = "    scanf(" + fmt + ", &" + var->address + ");\n";
              $$.label = var->address;
              $$.type = var->type;
              $$.parenthesized = false;
          }
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

PUSH_STMT
    : TK_PUSH '(' TK_ID ',' E ')'
      {
          $$.translation = makePush($3.label, $5);
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    ;

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
          noArray($3, "valor de match");
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

MATCH_PATS
    : E
      { $$ = $1; }
    | MATCH_PATS ',' E
      {

          $$.translation = $1.translation + $3.translation;
          $$.label = $1.label + "|" + $3.label;
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

          string cmp_code = "";
          symbol tmp_any = createTemp(t_bool);

          vector<string> vals;
          string cur = "";
          for (char c : pats_label) {
              if (c == '|') { if (!cur.empty()) vals.push_back(cur); cur = ""; }
              else cur += c;
          }
          if (!cur.empty()) vals.push_back(cur);

          if (vals.size() == 1) {

              symbol tmp_cmp = createTemp(t_bool);
              cmp_code += "    " + tmp_cmp.address + " = " + match_expr_label + " == " + vals[0] + ";\n";
              cmp_code += "    " + tmp_any.address + " = " + tmp_cmp.address + ";\n";
          } else {

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

FUNC_DEF
    : TK_FNC TYPE TK_ID
      { beginFunction($2.type, $3.label); }
      '(' PARAM_LIST ')'
      { registerSignature(); }
      BLOCK
      {
          endFunction($9.translation);
          $$.translation = "";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    | TK_FNC TK_ID
      { beginFunction(t_void, $2.label); }
      '(' PARAM_LIST ')'
      { registerSignature(); }
      BLOCK
      {
          endFunction($8.translation);
          $$.translation = "";
          $$.label = "";
          $$.type = t_null;
          $$.parenthesized = false;
      }
    ;

PARAM_LIST
    :
    | PARAMS
    ;

PARAMS
    : PARAM
    | PARAMS ',' PARAM
    ;

PARAM
    : TYPE TK_ID
      { declareParam($2.label, $1.type); }
    | TK_ID
      { declareParam($1.label, last_param_type); }
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
    | E TK_POW E
      { $$ = makePow($1, $3); }
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
    | '-' E %prec UMINUS
      { $$ = makeUnaryMinus($2); }
    | TK_NUM
      { $$ = makeLiteral(t_int, $1.label); }
    | TK_REAL
      { $$ = makeLiteral(t_double, $1.label); }
    | TK_BOOL
      { $$ = makeLiteral(t_bool, $1.label); }
    | TK_CHAR
      { $$ = makeLiteral(t_char, $1.label); }
    | STRING
      { $$ = $1; }
    | TK_NULL
      { $$ = makeNullLiteral(); }
    | TK_CI
      {
          if (ci_stack.empty()) {
              yyerror("'ci' usado fora de um foreach");
              $$.label = "0";
              $$.type = t_int;
          } else {
              $$.label = ci_stack.back();
              $$.type = ci_type_stack.back();
          }
          $$.translation = "";
          $$.parenthesized = false;
          $$.isLiteral = false;
          $$.freeable = false;
      }
    | TK_SCAN '(' TYPE ')'
      { $$ = makeMin($3.type); }
    | TK_SCAN '(' ')'
      { $$ = makeMin(t_int); }
    | TK_ID '(' { arg_stack.push_back(vector<attributes>()); } ARG_LIST ')'
      {
          $$ = makeCall($1.label, arg_stack.back());
          arg_stack.pop_back();
      }
    | TK_ID '[' E ']' '[' E ']'
      { $$ = makeMatrixAccess($1.label, $3, $6); }
    | TK_ID '[' E ']'
      { $$ = makeArrayAccess($1.label, $3); }
    | TK_LEN '(' TK_ID ')'
      { $$ = makeLen($3.label); }
    | TK_ID
      { $$ = makeIdentifier($1.label); }
    ;

ARG_LIST
    :
    | ARGS
    ;

ARGS
    : E
      { arg_stack.back().push_back($1); }
    | ARGS ',' E
      { arg_stack.back().push_back($3); }
    ;

STRING
    : TK_STR_BEGIN { strpart_stack.push_back(vector<StrPart>()); } STR_ITEMS TK_STR_END
      {
          $$ = buildString(strpart_stack.back());
          strpart_stack.pop_back();
          $$.parenthesized = false;
      }
    ;

STR_ITEMS
    :
    | STR_ITEMS STR_ITEM
    ;

STR_ITEM
    : TK_STR_CHARS
      {
          StrPart p;
          p.is_expr = false;
          p.frag = $1.label;
          strpart_stack.back().push_back(p);
      }
    | TK_INTERP_BEGIN E TK_INTERP_END
      {
          StrPart p;
          p.is_expr = true;
          p.expr = $2;
          strpart_stack.back().push_back(p);
      }
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

vector<symbol>& activeDecls()
{
    if (!func_stack.empty()) return func_stack.back().decls;
    return declarations;
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
        case t_void:   return "void";
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
        case t_void:   return "void";
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

bool isStringy(types type)
{
    return type == t_string || type == t_char;
}

bool canAssign(types target, types source)
{
    if (target == source) return true;

    if (target == t_float  && source == t_int)   return true;
    if (target == t_double && source == t_int)   return true;
    if (target == t_double && source == t_float) return true;

    if (source == t_null) return true;
    return false;
}

bool canAssignExpr(types target, const attributes& expr)
{
    if (canAssign(target, expr.type)) return true;
    if (expr.isLiteral && isNumeric(target) && isNumeric(expr.type)) {
        if (target == t_int) return false;
        return true;
    }
    return false;
}

bool canExplicitCast(types target, types source)
{
    if (target == t_null || source == t_null) return false;
    return true;
}

void checkCondition(const attributes& cond)
{
    noArray(cond, "condicao");
    if (cond.parenthesized) {

        if (cond.type == t_string)
            yyerror("truthiness de string nao suportada; use comparacao explicita");
        if (cond.type == t_null)
            yyerror("condicao nula invalida");
    } else {
        if (cond.type != t_bool)
            yyerror("condicao deve ser boolean; use parenteses para truthiness: if (" + cond.label + ")");
    }
}

symbol declareSymbol(const string& name, types type, bool implicit)
{
    if (scope_stack.back().count(name)) {
        yyerror("variavel ja declarada: " + name);
    }

    if (type == t_string) uses_strings = true;

    symbol variable;
    variable.name = name;
    variable.type = type;
    variable.address = newTempName();
    variable.istemp = false;
    variable.implicit = implicit;

    scope_stack.back()[name] = variable;
    activeDecls().push_back(variable);
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

    activeDecls().push_back(temporary);
    return temporary;
}

attributes makeLiteral(types type, const string& value)
{
    symbol temporary = createTemp(type);

    attributes result;
    result.label = temporary.address;
    result.type = type;
    result.isLiteral = isNumeric(type);
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

attributes buildString(vector<StrPart>& parts)
{
    bool hasExpr = false;
    for (const StrPart& p : parts) if (p.is_expr) hasExpr = true;

    if (!hasExpr) {
        string lit = "\"";
        for (const StrPart& p : parts) lit += p.frag;
        lit += "\"";
        attributes r;
        r.type = t_string;
        r.label = lit;
        return r;
    }

    uses_strings = true;
    uses_strcat = true;
    string code = "";

    struct Piece { string label; bool freeable; };
    vector<Piece> pieces;
    for (StrPart& p : parts) {
        if (!p.is_expr) {
            pieces.push_back({ "\"" + p.frag + "\"", false });
            continue;
        }
        attributes e = p.expr;
        noArray(e, "interpolacao");
        code += e.translation;
        string lbl;
        bool fr;
        if (e.type == t_string) {
            lbl = e.label;
            fr = e.freeable;
        } else if (e.type == t_char) {
            uses_charstr = true;
            symbol t = createTemp(t_string);
            code += "    " + t.address + " = milla_char_str(" + e.label + ");\n";
            lbl = t.address; fr = true;
        } else if (e.type == t_int) {
            uses_intstr = true;
            symbol t = createTemp(t_string);
            code += "    " + t.address + " = milla_int_str(" + e.label + ");\n";
            lbl = t.address; fr = true;
        } else if (e.type == t_float || e.type == t_double) {
            uses_doublestr = true;
            symbol t = createTemp(t_string);
            code += "    " + t.address + " = milla_double_str((double) " + e.label + ");\n";
            lbl = t.address; fr = true;
        } else if (e.type == t_bool) {
            uses_boolstr = true;
            symbol t = createTemp(t_string);
            code += "    " + t.address + " = milla_bool_str(" + e.label + ");\n";
            lbl = t.address; fr = true;
        } else {
            yyerror("nao e possivel interpolar valor do tipo " + typeToText(e.type));
            lbl = "\"\""; fr = false;
        }
        pieces.push_back({ lbl, fr });
    }

    string acc = pieces[0].label;
    bool accFree = pieces[0].freeable;
    for (size_t i = 1; i < pieces.size(); i++) {
        symbol res = createTemp(t_string);
        code += "    " + res.address + " = milla_strcat(" + acc + ", " + pieces[i].label + ");\n";
        if (accFree) code += "    free(" + acc + ");\n";
        if (pieces[i].freeable) code += "    free(" + pieces[i].label + ");\n";
        acc = res.address;
        accFree = true;
    }

    attributes r;
    r.type = t_string;
    r.label = acc;
    r.freeable = accFree;
    r.translation = code;
    return r;
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

static attributes dummyExpr()
{
    attributes a;
    a.type = t_int;
    a.label = "0";
    return a;
}

attributes makeIdentifier(const string& name)
{
    symbol* variable = findSymbol(name);
    if (!variable) {
        yyerror("variavel '" + name + "' nao declarada");
        return dummyExpr();
    }

    attributes result;
    if (variable->is_array) {

        result.arr = variable;
        result.label = variable->address;
        result.type = t_null;
        return result;
    }
    result.label = variable->address;
    result.type = variable->type;
    result.translation = "";
    return result;
}

void noArray(const attributes& a, const string& ctx)
{
    if (a.arr)
        yyerror("vetor/matriz nao pode ser usado como valor escalar em " + ctx +
                "; use indexacao (v[i]), len(v) ou itere com for/foreach");
}

symbol declareArrayFixed(const string& name, types elemType, int size, int dims, int size1)
{
    if (elemType == t_string)
        yyerror("vetores de string ainda nao sao suportados nesta versao");
    if (size <= 0 || (dims == 2 && size1 <= 0))
        yyerror("tamanho de vetor/matriz deve ser positivo");
    if (scope_stack.back().count(name))
        yyerror("variavel ja declarada: " + name);

    uses_arrays = true;
    symbol s;
    s.name = name;
    s.type = elemType;
    s.address = newTempName();
    s.is_array = true;
    s.dims = dims;
    s.elem_type = elemType;
    s.size0 = size;
    s.size1 = size1;
    scope_stack.back()[name] = s;
    activeDecls().push_back(s);
    return s;
}

string emitArrayInit(const symbol& sym, vector<attributes>& elems)
{
    string code = "";
    for (size_t i = 0; i < elems.size(); i++) {
        attributes e = elems[i];
        noArray(e, "inicializacao de vetor");
        if (!canAssignExpr(sym.elem_type, e))
            yyerror("elemento " + to_string(i + 1) + " do vetor: esperado " +
                    typeToText(sym.elem_type) + ", obtido " + typeToText(e.type));
        code += e.translation;
        string val = e.label;
        if (e.type != sym.elem_type) {
            symbol c = createTemp(sym.elem_type);
            code += "    " + c.address + " = (" + typeToC(sym.elem_type) + ") " + val + ";\n";
            val = c.address;
        }
        code += "    " + sym.address + "[" + to_string(i) + "] = " + val + ";\n";
    }
    return code;
}

symbol declareArrayDynamic(const string& name, types elemType)
{
    if (elemType == t_string)
        yyerror("vetores de string ainda nao sao suportados nesta versao");
    if (scope_stack.back().count(name))
        yyerror("variavel ja declarada: " + name);

    uses_arrays = true;
    symbol s;
    s.name = name;
    s.type = elemType;
    s.address = newTempName();
    s.is_array = true;
    s.is_dynamic = true;
    s.dims = 1;
    s.elem_type = elemType;
    s.size0 = 0;
    s.len_addr = newTempName();
    s.cap_addr = newTempName();
    scope_stack.back()[name] = s;
    activeDecls().push_back(s);
    return s;
}

string emitArrayInitDynamic(const symbol& sym, vector<attributes>& elems)
{
    int n = (int)elems.size();
    string ce = typeToC(sym.elem_type);
    string code = "    " + sym.address + " = (" + ce + "*) malloc(" + to_string(n) +
                  " * sizeof(" + ce + "));\n";
    code += "    " + sym.cap_addr + " = " + to_string(n) + ";\n";
    code += "    " + sym.len_addr + " = " + to_string(n) + ";\n";
    code += emitArrayInit(sym, elems);
    return code;
}

string makePush(const string& name, const attributes& value)
{
    symbol* s = findSymbol(name);
    if (!s) { yyerror("variavel '" + name + "' nao declarada"); return ""; }
    if (!s->is_array) { yyerror("push() requer um vetor, '" + name + "' nao e"); return ""; }
    if (!s->is_dynamic) {
        yyerror("push() requer um vetor dinamico; declare '" + name + "' com [ext]");
        return "";
    }
    noArray(value, "push");
    if (!canAssignExpr(s->elem_type, value))
        yyerror("push em '" + name + "': esperado " + typeToText(s->elem_type) +
                ", obtido " + typeToText(value.type));

    string ce = typeToC(s->elem_type);
    string code = value.translation;
    string val = value.label;
    if (value.type != s->elem_type) {
        symbol c = createTemp(s->elem_type);
        code += "    " + c.address + " = (" + ce + ") " + val + ";\n";
        val = c.address;
    }

    code += "    if (" + s->len_addr + " >= " + s->cap_addr + ") {\n";
    code += "        " + s->cap_addr + " = " + s->cap_addr + " == 0 ? 4 : " + s->cap_addr + " * 2;\n";
    code += "        " + s->address + " = (" + ce + "*) realloc(" + s->address + ", " +
            s->cap_addr + " * sizeof(" + ce + "));\n";
    code += "    }\n";
    code += "    " + s->address + "[" + s->len_addr + "] = " + val + ";\n";
    code += "    " + s->len_addr + " = " + s->len_addr + " + 1;\n";
    return code;
}

static string arrayIndexExpr(symbol* s, const attributes& idx)
{
    if (!s) { yyerror("variavel nao declarada"); return "0"; }
    if (!s->is_array) yyerror("'" + s->name + "' nao e um vetor/matriz");
    if (s->dims != 1) yyerror("'" + s->name + "' e uma matriz; use " + s->name + "[i][j]");
    noArray(idx, "indice de vetor");
    if (idx.type != t_int)
        yyerror("indice de vetor deve ser inteiro, obtido " + typeToText(idx.type));
    uses_bounds = true;
    string sizeExpr = s->is_dynamic ? s->len_addr : to_string(s->size0);
    return s->address + "[milla_idx(" + idx.label + ", " + sizeExpr + ")]";
}

attributes makeArrayAccess(const string& name, const attributes& idx)
{
    symbol* s = findSymbol(name);
    if (!s) { yyerror("variavel '" + name + "' nao declarada"); return dummyExpr(); }
    string access = arrayIndexExpr(s, idx);

    symbol t = createTemp(s->elem_type);
    attributes r;
    r.type = s->elem_type;
    r.label = t.address;
    r.translation = idx.translation +
        "    " + t.address + " = " + access + ";\n";
    return r;
}

string emitMatrixInit(const symbol& sym, vector<vector<attributes>>& rows)
{
    string code = "";
    for (size_t r = 0; r < rows.size(); r++) {
        for (size_t c = 0; c < rows[r].size(); c++) {
            attributes e = rows[r][c];
            noArray(e, "inicializacao de matriz");
            if (!canAssignExpr(sym.elem_type, e))
                yyerror("elemento [" + to_string(r) + "][" + to_string(c) + "] da matriz: esperado " +
                        typeToText(sym.elem_type) + ", obtido " + typeToText(e.type));
            code += e.translation;
            string val = e.label;
            if (e.type != sym.elem_type) {
                symbol cv = createTemp(sym.elem_type);
                code += "    " + cv.address + " = (" + typeToC(sym.elem_type) + ") " + val + ";\n";
                val = cv.address;
            }
            code += "    " + sym.address + "[" + to_string(r) + "][" + to_string(c) + "] = " + val + ";\n";
        }
    }
    return code;
}

static string matrixIndexExpr(symbol* s, const attributes& i, const attributes& j)
{
    if (!s) { yyerror("variavel nao declarada"); return "0"; }
    if (!s->is_array || s->dims != 2)
        yyerror("'" + (s ? s->name : "") + "' nao e uma matriz (use m[i][j] apenas em matrizes)");
    noArray(i, "indice de matriz");
    noArray(j, "indice de matriz");
    if (i.type != t_int || j.type != t_int)
        yyerror("indices de matriz devem ser inteiros");
    uses_bounds = true;
    return s->address
         + "[milla_idx(" + i.label + ", " + to_string(s->size0) + ")]"
         + "[milla_idx(" + j.label + ", " + to_string(s->size1) + ")]";
}

attributes makeMatrixAccess(const string& name, const attributes& i, const attributes& j)
{
    symbol* s = findSymbol(name);
    if (!s) { yyerror("variavel '" + name + "' nao declarada"); return dummyExpr(); }
    string access = matrixIndexExpr(s, i, j);
    symbol t = createTemp(s->elem_type);
    attributes r;
    r.type = s->elem_type;
    r.label = t.address;
    r.translation = i.translation + j.translation +
        "    " + t.address + " = " + access + ";\n";
    return r;
}

attributes makeMatrixAccessLValue(const string& name, const attributes& i, const attributes& j)
{
    symbol* s = findSymbol(name);
    if (!s) {
        yyerror("variavel '" + name + "' nao declarada");
        attributes d = dummyExpr();
        d.resolved = true;
        return d;
    }
    string access = matrixIndexExpr(s, i, j);
    attributes r;
    r.resolved = true;
    r.type = s->elem_type;
    r.label = access;
    r.translation = i.translation + j.translation;
    return r;
}

attributes makeArrayAccessLValue(const string& name, const attributes& idx)
{
    symbol* s = findSymbol(name);
    if (!s) {
        yyerror("variavel '" + name + "' nao declarada");
        attributes d = dummyExpr();
        d.resolved = true;
        return d;
    }
    string access = arrayIndexExpr(s, idx);

    attributes r;
    r.resolved = true;
    r.type = s->elem_type;
    r.label = access;
    r.translation = idx.translation;
    return r;
}

string emitIterLoop(const IterState& is, const string& body, bool cont_used)
{
    string update_label = cont_used ? ("    " + is.l_update + ": ;\n") : "";
    if (is.is_array) {
        return "    " + is.l_top + ": ;\n"
             + "    " + is.t_cond + " = " + is.t_idx + " < " + is.size_expr + ";\n"
             + "    if (!" + is.t_cond + ") goto " + is.l_end + ";\n"
             + "    " + is.t_item + " = " + is.t_coll + "[" + is.t_idx + "];\n"
             + body
             + update_label
             + "    " + is.t_idx + " = " + is.t_idx + " + 1;\n"
             + "    goto " + is.l_top + ";\n"
             + "    " + is.l_end + ": ;\n";
    }

    return "    " + is.l_top + ": ;\n"
         + "    " + is.t_item + " = " + is.t_coll + "[" + is.t_idx + "];\n"
         + "    " + is.t_cond + " = " + is.t_item + " != '\\0';\n"
         + "    if (!" + is.t_cond + ") goto " + is.l_end + ";\n"
         + body
         + update_label
         + "    " + is.t_idx + " = " + is.t_idx + " + 1;\n"
         + "    goto " + is.l_top + ";\n"
         + "    " + is.l_end + ": ;\n";
}

string emitMatrixForeach(const IterState& is, const string& body, bool cont_used)
{

    string out_idx, out_size, in_idx, in_size;
    if (!is.by_col) { out_idx = is.m_ti; out_size = is.m_li; in_idx = is.m_tj; in_size = is.m_lj; }
    else            { out_idx = is.m_tj; out_size = is.m_lj; in_idx = is.m_ti; in_size = is.m_li; }

    string upd_label = cont_used ? ("    " + is.l_in_upd + ": ;\n") : "";

    return "    " + out_idx + " = 0;\n"
         + "    " + is.l_out_top + ": ;\n"
         + "    " + is.m_cond_out + " = " + out_idx + " < " + out_size + ";\n"
         + "    if (!" + is.m_cond_out + ") goto " + is.l_out_end + ";\n"
         + "    " + in_idx + " = 0;\n"
         + "    " + is.l_in_top + ": ;\n"
         + "    " + is.m_cond_in + " = " + in_idx + " < " + in_size + ";\n"
         + "    if (!" + is.m_cond_in + ") goto " + is.l_in_end + ";\n"
         + "    " + is.t_item + " = " + is.t_coll + "[" + is.m_ti + "][" + is.m_tj + "];\n"
         + body
         + upd_label
         + "    " + in_idx + " = " + in_idx + " + 1;\n"
         + "    goto " + is.l_in_top + ";\n"
         + "    " + is.l_in_end + ": ;\n"
         + "    " + out_idx + " = " + out_idx + " + 1;\n"
         + "    goto " + is.l_out_top + ";\n"
         + "    " + is.l_out_end + ": ;\n";
}

attributes makeLen(const string& name)
{
    symbol* s = findSymbol(name);
    if (!s) { yyerror("variavel '" + name + "' nao declarada"); return dummyExpr(); }
    if (!s->is_array) yyerror("len() requer um vetor/matriz, '" + name + "' nao e");
    if (s->is_dynamic) {
        attributes r;
        r.type = t_int;
        r.label = s->len_addr;
        return r;
    }
    return makeLiteral(t_int, to_string(s->size0));
}

attributes makeAssignment(const attributes& target, const attributes& expr)
{
    string addr;
    types targetType;

    noArray(expr, "atribuicao");

    if (!target.resolved) {

        if (expr.type == t_null) {
            yyerror("nao e possivel inferir o tipo de '" + target.name +
                    "' a partir de null; declare explicitamente (ex: int " + target.name + ")");
        }
        symbol created = declareSymbol(target.name, expr.type, true);
        addr = created.address;
        targetType = expr.type;
    } else {
        addr = target.label;
        targetType = target.type;
        if (!canAssignExpr(targetType, expr)) {
            yyerror("nao e possivel atribuir " + typeToText(expr.type) + " a " +
                    typeToText(targetType) + "; conversao com perda exige cast explicito (" +
                    typeToText(targetType) + ")");
        }
    }

    attributes result;
    result.label = addr;
    result.type = targetType;
    result.translation = target.translation + expr.translation;

    if (targetType == t_string) {

        uses_strings = true;
        uses_strdup = true;
        result.translation += "    free(" + addr + ");\n";
        result.translation += "    " + addr + " = milla_str_dup(" + expr.label + ");\n";
        if (expr.freeable) {

            result.translation += "    free(" + expr.label + ");\n";
        }
    } else if (targetType == expr.type || expr.type == t_null) {
        result.translation += "    " + addr + " = " + expr.label + ";\n";
    } else {

        symbol converted = createTemp(targetType);
        result.translation += "    " + converted.address + " = (" + typeToC(targetType) + ") " + expr.label + ";\n";
        result.translation += "    " + addr + " = " + converted.address + ";\n";
    }

    return result;
}

attributes makeCompoundAssign(const attributes& target, const string& op, const attributes& expr)
{

    noArray(expr, "operador composto");
    if (!target.resolved) {
        yyerror("variavel '" + target.name + "' nao declarada; use '=' para criar antes de '" + op + "='");
    }

    attributes lhs;
    lhs.label = target.label;
    lhs.type = target.type;
    lhs.translation = "";

    attributes rhs = makeBinary(lhs, op, expr);
    return makeAssignment(target, rhs);
}

attributes makePrefixInc(const string& name, const string& op)
{

    symbol* var = findSymbol(name);
    if (!var) { yyerror("variavel '" + name + "' nao declarada"); return dummyExpr(); }
    if (!isNumeric(var->type)) yyerror("++ / -- requer tipo numerico");

    attributes lhs;
    lhs.label = var->address;
    lhs.type = var->type;
    lhs.translation = "";

    attributes one = makeLiteral(t_int, "1");
    attributes result = makeBinary(lhs, op, one);

    result.translation += "    " + var->address + " = " + result.label + ";\n";
    return result;
}

attributes makePostfixInc(const string& name, const string& op)
{

    symbol* var = findSymbol(name);
    if (!var) { yyerror("variavel '" + name + "' nao declarada"); return dummyExpr(); }
    if (!isNumeric(var->type)) yyerror("++ / -- requer tipo numerico");

    symbol old_val = createTemp(var->type);
    string save_code = "    " + old_val.address + " = " + var->address + ";\n";

    attributes lhs;
    lhs.label = old_val.address;
    lhs.type = var->type;
    lhs.translation = "";

    attributes one = makeLiteral(t_int, "1");
    attributes incremented = makeBinary(lhs, op, one);

    incremented.translation = save_code + incremented.translation;
    incremented.translation += "    " + var->address + " = " + incremented.label + ";\n";

    incremented.label = old_val.address;
    incremented.type = var->type;
    return incremented;
}

attributes makePow(const attributes& base, const attributes& exp)
{
    noArray(base, "exponenciacao");
    noArray(exp, "exponenciacao");

    attributes b = base, e = exp;
    if (!isNumeric(b.type))
        yyerror("operador ** exige base numerica, obtido " + typeToText(b.type));
    if (e.type != t_int)
        yyerror("expoente de ** deve ser inteiro, obtido " + typeToText(e.type));

    string code = b.translation + e.translation;
    types resultType = (b.type == t_int) ? t_int : b.type;
    symbol r = createTemp(resultType);

    if (resultType == t_int) {
        uses_powi = true;
        code += "    " + r.address + " = milla_powi(" + b.label + ", " + e.label + ");\n";
    } else {
        uses_powd = true;

        code += "    " + r.address + " = (" + typeToC(resultType) + ") milla_powd((double) "
              + b.label + ", " + e.label + ");\n";
    }

    attributes result;
    result.type = resultType;
    result.label = r.address;
    result.translation = code;
    return result;
}

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

attributes makeStringConcat(attributes left, attributes right)
{
    uses_strings = true;
    uses_strcat = true;
    string code = left.translation + right.translation;

    if (left.type == t_char) {
        uses_charstr = true;
        symbol t = createTemp(t_string);
        code += "    " + t.address + " = milla_char_str(" + left.label + ");\n";
        left.label = t.address;
        left.type = t_string;
        left.freeable = true;
    }
    if (right.type == t_char) {
        uses_charstr = true;
        symbol t = createTemp(t_string);
        code += "    " + t.address + " = milla_char_str(" + right.label + ");\n";
        right.label = t.address;
        right.type = t_string;
        right.freeable = true;
    }

    symbol res = createTemp(t_string);
    code += "    " + res.address + " = milla_strcat(" + left.label + ", " + right.label + ");\n";

    if (left.freeable)  code += "    free(" + left.label + ");\n";
    if (right.freeable) code += "    free(" + right.label + ");\n";

    attributes result;
    result.label = res.address;
    result.type = t_string;
    result.freeable = true;
    result.translation = code;
    return result;
}

attributes makeBinary(const attributes& left, const string& op, const attributes& right)
{
    attributes l = left;
    attributes r = right;

    noArray(l, "operacao '" + op + "'");
    noArray(r, "operacao '" + op + "'");

    if (op == "+" && (isStringy(l.type) || isStringy(r.type))) {
        if (!isStringy(l.type) || !isStringy(r.type)) {
            yyerror("operador + nao combina " + typeToText(l.type) + " e " +
                    typeToText(r.type) + "; concatenacao exige string/char");
        }
        return makeStringConcat(l, r);
    }

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

    noArray(l, "comparacao");
    noArray(r, "comparacao");

    string code = l.translation + r.translation;

    bool equalityOp = (op == "==" || op == "!=");

    if (isNumeric(l.type) && isNumeric(r.type)) {
        types cmpType = promoteNumeric(l.type, r.type);
        promoteArg(code, l, cmpType);
        promoteArg(code, r, cmpType);
    } else if (equalityOp && l.type == r.type && (l.type == t_bool || l.type == t_char)) {

    } else if (equalityOp && (l.type == t_null || r.type == t_null)) {

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
    noArray(expr, "negacao logica");
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

attributes makeUnaryMinus(const attributes& expr)
{
    noArray(expr, "negacao unaria");
    if (!isNumeric(expr.type)) {
        yyerror("operador unario '-' exige operando numerico, obtido " + typeToText(expr.type));
    }

    symbol temporary = createTemp(expr.type);

    attributes result;
    result.label = temporary.address;
    result.type = expr.type;
    result.parenthesized = false;
    result.translation = expr.translation + "    " + result.label + " = -" + expr.label + ";\n";
    return result;
}

attributes makeCast(types targetType, const attributes& expr)
{
    noArray(expr, "cast");
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

    noArray(expr, "saida (mout/print/log/error)");
    if (expr.type == t_void)
        yyerror("nao e possivel imprimir o resultado de um procedimento (void)");

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

    if (expr.type == t_string && expr.freeable) {
        result.translation += "    free(" + expr.label + ");\n";
        uses_strings = true;
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

void beginFunction(types ret, const string& name)
{
    if (!func_stack.empty())
        yyerror("funcoes aninhadas nao sao suportadas");
    if (scope_stack.size() != 1)
        yyerror("funcao '" + name + "' deve ser definida no nivel global do programa");
    if (function_table.count(name))
        yyerror("funcao '" + name + "' ja declarada");

    saved_scope_stack = scope_stack;
    scope_stack.clear();
    scope_stack.push_back(map<string, symbol>());

    FuncCtx fc;
    fc.name = name;
    fc.ret_type = ret;
    fc.has_return = false;
    func_stack.push_back(fc);
    last_param_type = t_void;
}

symbol declareParam(const string& name, types type)
{
    if (type == t_void)
        yyerror("o primeiro parametro precisa de um tipo explicito (ex.: int " + name + ")");
    if (scope_stack.back().count(name))
        yyerror("parametro '" + name + "' duplicado");

    symbol p;
    p.name = name;
    p.type = type;
    p.address = newTempName();
    p.istemp = false;
    p.implicit = false;

    scope_stack.back()[name] = p;
    func_stack.back().params.push_back(p);
    last_param_type = type;
    return p;
}

void registerSignature()
{
    FuncCtx& fc = func_stack.back();
    FuncSig sig;
    sig.ret = fc.ret_type;
    for (const symbol& p : fc.params) sig.params.push_back(p.type);
    function_table[fc.name] = sig;
}

void endFunction(const string& body)
{
    FuncCtx fc = func_stack.back();
    func_stack.pop_back();
    scope_stack = saved_scope_stack;

    if (fc.ret_type != t_void && !fc.has_return)
        yyerror("funcao '" + fc.name + "' deve retornar um valor do tipo " + typeToText(fc.ret_type));

    fc.body = body;
    finished_functions.push_back(fc);
}

attributes makeCall(const string& name, vector<attributes>& args)
{
    auto it = function_table.find(name);
    if (it == function_table.end()) {
        yyerror("funcao '" + name + "' nao declarada; defina-a antes de chamar");
        return dummyExpr();
    }
    FuncSig sig = it->second;

    if (args.size() != sig.params.size())
        yyerror("funcao '" + name + "' espera " + to_string(sig.params.size()) +
                " argumento(s), recebeu " + to_string(args.size()));

    string code = "";
    string argList = "";
    vector<string> freeAfter;

    for (size_t i = 0; i < args.size(); i++) {
        attributes a = args[i];
        types pt = sig.params[i];
        noArray(a, "argumento de funcao");
        code += a.translation;

        if (!canAssignExpr(pt, a))
            yyerror("argumento " + to_string(i + 1) + " de '" + name + "': esperado " +
                    typeToText(pt) + ", obtido " + typeToText(a.type));

        string lbl = a.label;
        if (a.type != pt && pt != t_string) {
            symbol c = createTemp(pt);
            code += "    " + c.address + " = (" + typeToC(pt) + ") " + lbl + ";\n";
            lbl = c.address;
        }
        if (a.type == t_string && a.freeable) freeAfter.push_back(a.label);

        if (i) argList += ", ";
        argList += lbl;
    }

    attributes result;
    if (sig.ret == t_void) {
        code += "    " + name + "(" + argList + ");\n";
        for (const string& f : freeAfter) code += "    free(" + f + ");\n";
        result.type = t_void;
        result.label = "";
    } else {
        symbol res = createTemp(sig.ret);
        code += "    " + res.address + " = " + name + "(" + argList + ");\n";
        for (const string& f : freeAfter) code += "    free(" + f + ");\n";
        result.type = sig.ret;
        result.label = res.address;
    }
    result.translation = code;
    return result;
}

attributes makeReturn(attributes* expr)
{
    attributes result;
    if (func_stack.empty()) {
        yyerror("'return' usado fora de uma funcao");
        return result;
    }
    FuncCtx& fc = func_stack.back();

    if (expr == nullptr) {
        if (fc.ret_type != t_void)
            yyerror("funcao '" + fc.name + "' deve retornar um valor do tipo " + typeToText(fc.ret_type));
        fc.has_return = true;
        result.translation = "    return;\n";
        return result;
    }

    noArray(*expr, "return");
    if (fc.ret_type == t_void)
        yyerror("procedimento '" + fc.name + "' (void) nao pode retornar um valor");
    if (!canAssignExpr(fc.ret_type, *expr))
        yyerror("tipo de retorno incompativel em '" + fc.name + "': esperado " +
                typeToText(fc.ret_type) + ", obtido " + typeToText(expr->type));

    fc.has_return = true;
    string code = expr->translation;
    string val = expr->label;
    if (expr->type != fc.ret_type && fc.ret_type != t_string) {
        symbol c = createTemp(fc.ret_type);
        code += "    " + c.address + " = (" + typeToC(fc.ret_type) + ") " + val + ";\n";
        val = c.address;
    }
    code += "    return " + val + ";\n";
    result.translation = code;
    return result;
}

void emitDeclaration(const symbol& d)
{
    if (d.is_array && d.is_dynamic) {

        cout << "    " << typeToC(d.elem_type) << "* " << d.address << " = NULL;";
        if (!d.name.empty())
            cout << " /* " << d.name << " : vetor[" << typeToText(d.elem_type) << "] dinamico */";
        cout << "\n";
        cout << "    int " << d.len_addr << " = 0;\n";
        cout << "    int " << d.cap_addr << " = 0;\n";
        return;
    }
    if (d.is_array && !d.is_dynamic) {

        if (d.dims == 2)
            cout << "    " << typeToC(d.elem_type) << " " << d.address
                 << "[" << d.size0 << "][" << d.size1 << "];";
        else
            cout << "    " << typeToC(d.elem_type) << " " << d.address << "[" << d.size0 << "];";
    } else if (d.type == t_string) {
        cout << "    char* " << d.address << " = NULL;";
    } else {
        cout << "    " << typeToC(d.type) << " " << d.address << ";";
    }
    if (!d.istemp && !d.name.empty()) {
        cout << " /* " << d.name;
        if (d.is_array)
            cout << " : vetor[" << typeToText(d.elem_type) << "]";
        else if (d.implicit)
            cout << " : inferida " << typeToText(d.type);
        cout << " */";
    }
    cout << "\n";
}

void printProgram(const string& body)
{
    cout << "#include <stdio.h>\n";
    if (uses_exit || uses_strings || uses_arrays) cout << "#include <stdlib.h>\n";
    if (uses_strings) cout << "#include <string.h>\n";
    cout << "\n";

    if (uses_bounds) {

        cout << "static int milla_idx(int i, int n) { if (i < 0 || i >= n) { fprintf(stderr, \"erro: indice %d fora dos limites [0, %d)\\n\", i, n); exit(1); } return i; }\n";
        cout << "\n";
    }

    if (uses_powi || uses_powd) {

        if (uses_powi)
            cout << "static int milla_powi(int b, int e) { int r = 1; while (e > 0) { r *= b; e--; } return r; }\n";
        if (uses_powd)
            cout << "static double milla_powd(double b, int e) { double r = 1.0; int k = e < 0 ? -e : e; while (k > 0) { r *= b; k--; } return e < 0 ? 1.0 / r : r; }\n";
        cout << "\n";
    }

    if (uses_strdup || uses_strcat || uses_charstr ||
        uses_intstr || uses_doublestr || uses_boolstr) {

        if (uses_strdup)
            cout << "static char* milla_str_dup(const char* s) { char* r = (char*) malloc(strlen(s) + 1); strcpy(r, s); return r; }\n";
        if (uses_strcat)
            cout << "static char* milla_strcat(const char* a, const char* b) { char* r = (char*) malloc(strlen(a) + strlen(b) + 1); strcpy(r, a); strcat(r, b); return r; }\n";
        if (uses_charstr)
            cout << "static char* milla_char_str(char c) { char* r = (char*) malloc(2); r[0] = c; r[1] = '\\0'; return r; }\n";
        if (uses_intstr)
            cout << "static char* milla_int_str(int v) { char* r = (char*) malloc(16); snprintf(r, 16, \"%d\", v); return r; }\n";
        if (uses_doublestr)
            cout << "static char* milla_double_str(double v) { char* r = (char*) malloc(32); snprintf(r, 32, \"%f\", v); return r; }\n";
        if (uses_boolstr)
            cout << "static char* milla_bool_str(int v) { char* r = (char*) malloc(8); snprintf(r, 8, \"%s\", v ? \"true\" : \"false\"); return r; }\n";
        cout << "\n";
    }

    if (!finished_functions.empty()) {
        for (const FuncCtx& f : finished_functions) {
            cout << typeToC(f.ret_type) << " " << f.name << "(";
            if (f.params.empty()) cout << "void";
            for (size_t i = 0; i < f.params.size(); i++) {
                if (i) cout << ", ";
                cout << typeToC(f.params[i].type);
            }
            cout << ");\n";
        }
        cout << "\n";
    }

    for (const FuncCtx& f : finished_functions) {
        cout << typeToC(f.ret_type) << " " << f.name << "(";
        if (f.params.empty()) cout << "void";
        for (size_t i = 0; i < f.params.size(); i++) {
            if (i) cout << ", ";
            cout << typeToC(f.params[i].type) << " " << f.params[i].address;
            if (!f.params[i].name.empty()) cout << " /* " << f.params[i].name << " */";
        }
        cout << ") {\n";

        for (const symbol& d : f.decls) {
            emitDeclaration(d);
        }
        if (!f.decls.empty()) cout << "\n";

        cout << f.body;
        if (f.ret_type != t_void)
            cout << "    return 0;\n";
        cout << "}\n\n";
    }

    cout << "int main(void) {\n";

    for (const symbol& declaration : declarations) {
        emitDeclaration(declaration);
    }

    if (!declarations.empty() || !body.empty()) {
        cout << "\n";
    }

    cout << body;

    if (uses_strings || uses_arrays) {
        bool emitted = false;
        for (const symbol& declaration : declarations) {
            bool is_str = (declaration.type == t_string && !declaration.is_array && !declaration.istemp);
            bool is_dyn = (declaration.is_array && declaration.is_dynamic && !declaration.istemp);
            if (is_str || is_dyn) {
                if (!emitted) { cout << "\n"; emitted = true; }
                cout << "    free(" << declaration.address << ");\n";
            }
        }
    }

    cout << "    return 0;\n";
    cout << "}\n";
}

void yyerror(string message)
{
    g_errors.push_back({cur_line, cur_tok_col, message, false});
}

void reportWarning(int line, const string& msg)
{
    g_errors.push_back({line, 0, msg, true});
}

bool hadErrors()
{
    for (const CompileError& e : g_errors)
        if (!e.warning) return true;
    return false;
}

static void flushDiagnostics()
{
    for (const CompileError& e : g_errors) {
        cerr << (e.warning ? "aviso" : "erro") << " [linha " << e.line;
        if (e.col > 0) cerr << ", coluna " << e.col;
        cerr << "]: " << e.msg << endl;
    }
}

int main(int argc, char *argv[])
{
    (void) argc;
    (void) argv;

    scope_stack.push_back({});
    yyparse();

    flushDiagnostics();
    if (hadErrors()) {
        int n = 0;
        for (const CompileError& e : g_errors) if (!e.warning) n++;
        cerr << "Compilacao falhou: " << n << " erro(s)." << endl;
        return 1;
    }
    return 0;
}
