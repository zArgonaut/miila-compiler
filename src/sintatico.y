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
    t_bool,
    t_char
};

struct attributes {
    string label;
    string translation;
    types type;
};

struct symbol {
    string name;
    types type;
    string address;
    bool istemp;
    bool implicit;
};

static int var_temp_qnt = 0;
static vector<symbol> declarations;
static map<string, symbol> symbols;

int yylex(void);
void yyerror(string message);

string newTempName();
string typeToC(types type);
string typeToText(types type);
bool isNumeric(types type);
bool canAssign(types target, types source);
bool canExplicitCast(types target, types source);
symbol declareSymbol(const string& name, types type);
symbol getOrCreateSymbol(const string& name);
symbol createTemp(types type);
attributes makeLiteral(types type, const string& value);
attributes makeIdentifier(const string& name);
attributes makeAssignment(const attributes& target, const attributes& expr);
attributes makeBinary(const attributes& left, const string& op, const attributes& right);
attributes makeRelational(const attributes& left, const string& op, const attributes& right);
attributes makeLogicalNot(const attributes& expr);
attributes makeCast(types targetType, const attributes& expr);
void printProgram(const string& body);
%}

%token TK_NUM TK_REAL TK_BOOL TK_CHAR
%token TK_ID TK_TYPE_INT TK_TYPE_FLOAT TK_TYPE_BOOLEAN TK_TYPE_CHAR
%token TK_OP_GREATER_EQUAL TK_OP_LESS_EQUAL TK_OP_EQUAL TK_OP_DIF
%token TK_OP_AND TK_OP_OR
%token TK_IF TK_ELSE TK_SWITCH TK_CASE TK_DEFAULT TK_DO TK_WHILE TK_FOR
%token TK_BREAK TK_CONTINUE TK_READ TK_PRINT
%token TK_END TK_ERROR

%start S

%right '='
%left TK_OP_OR
%left TK_OP_AND
%left TK_OP_EQUAL TK_OP_DIF
%left '>' '<' TK_OP_GREATER_EQUAL TK_OP_LESS_EQUAL
%left '+' '-'
%left '*' '/' '%'
%right '!'
%right UCAST

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
      }
    | /* vazio */
      {
          $$.translation = "";
          $$.label = "";
          $$.type = t_null;
      }
    ;

COMMAND
    : DECLARATION ';'
      {
          $$.translation = "";
          $$.label = "";
          $$.type = t_null;
      }
    | E ';'
      {
          $$ = $1;
      }
    ;

DECLARATION
    : TYPE TK_ID
      {
          declareSymbol($2.label, $1.type);
          $$.translation = "";
          $$.label = "";
          $$.type = t_null;
      }
    ;

TYPE
    : TK_TYPE_INT
      {
          $$.type = t_int;
          $$.label = "";
          $$.translation = "";
      }
    | TK_TYPE_FLOAT
      {
          $$.type = t_float;
          $$.label = "";
          $$.translation = "";
      }
    | TK_TYPE_BOOLEAN
      {
          $$.type = t_bool;
          $$.label = "";
          $$.translation = "";
      }
    | TK_TYPE_CHAR
      {
          $$.type = t_char;
          $$.label = "";
          $$.translation = "";
      }
    ;

LVALUE
    : TK_ID
      {
          symbol target = getOrCreateSymbol($1.label);
          $$.label = target.address;
          $$.type = target.type;
          $$.translation = "";
      }
    ;

E
    : LVALUE '=' E
      {
          $$ = makeAssignment($1, $3);
      }
    | '(' E ')'
      {
          $$ = $2;
      }
    | '(' TYPE ')' E %prec UCAST
      {
          $$ = makeCast($2.type, $4);
      }
    | E '+' E
      {
          $$ = makeBinary($1, $2.label, $3);
      }
    | E '-' E
      {
          $$ = makeBinary($1, $2.label, $3);
      }
    | E '*' E
      {
          $$ = makeBinary($1, $2.label, $3);
      }
    | E '/' E
      {
          $$ = makeBinary($1, $2.label, $3);
      }
    | E '%' E
      {
          $$ = makeBinary($1, $2.label, $3);
      }
    | E '>' E
      {
          $$ = makeRelational($1, $2.label, $3);
      }
    | E '<' E
      {
          $$ = makeRelational($1, $2.label, $3);
      }
    | E TK_OP_GREATER_EQUAL E
      {
          $$ = makeRelational($1, $2.label, $3);
      }
    | E TK_OP_LESS_EQUAL E
      {
          $$ = makeRelational($1, $2.label, $3);
      }
    | E TK_OP_EQUAL E
      {
          $$ = makeRelational($1, $2.label, $3);
      }
    | E TK_OP_DIF E
      {
          $$ = makeRelational($1, $2.label, $3);
      }
    | E TK_OP_AND E
      {
          $$ = makeBinary($1, $2.label, $3);
      }
    | E TK_OP_OR E
      {
          $$ = makeBinary($1, $2.label, $3);
      }
    | '!' E
      {
          $$ = makeLogicalNot($2);
      }
    | TK_NUM
      {
          $$ = makeLiteral(t_int, $1.label);
      }
    | TK_REAL
      {
          $$ = makeLiteral(t_float, $1.label);
      }
    | TK_BOOL
      {
          $$ = makeLiteral(t_bool, $1.label);
      }
    | TK_CHAR
      {
          $$ = makeLiteral(t_char, $1.label);
      }
    | TK_ID
      {
          $$ = makeIdentifier($1.label);
      }
    ;

%%

#include "lex.yy.c"

string newTempName()
{
    ++var_temp_qnt;
    return "T" + to_string(var_temp_qnt);
}

string typeToC(types type)
{
    switch (type) {
        case t_int:   return "int";
        case t_float: return "float";
        case t_bool:  return "int";
        case t_char:  return "char";
        default:      return "void";
    }
}

string typeToText(types type)
{
    switch (type) {
        case t_int:   return "int";
        case t_float: return "float";
        case t_bool:  return "boolean";
        case t_char:  return "char";
        default:      return "null";
    }
}

bool isNumeric(types type)
{
    return type == t_int || type == t_float;
}

bool canAssign(types target, types source)
{
    if (target == source) return true;
    return target == t_float && source == t_int;
}

bool canExplicitCast(types target, types source)
{
    if (target == t_null || source == t_null) return false;
    return true;
}

symbol declareSymbol(const string& name, types type)
{
    if (symbols.find(name) != symbols.end()) {
        yyerror("variavel ja declarada: " + name);
    }

    symbol variable;
    variable.name = name;
    variable.type = type;
    variable.address = newTempName();
    variable.istemp = false;
    variable.implicit = false;

    symbols[name] = variable;
    declarations.push_back(variable);
    return variable;
}

symbol getOrCreateSymbol(const string& name)
{
    auto found = symbols.find(name);
    if (found != symbols.end()) {
        return found->second;
    }

    symbol variable;
    variable.name = name;
    variable.type = t_int;
    variable.address = newTempName();
    variable.istemp = false;
    variable.implicit = true;

    symbols[name] = variable;
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
    result.translation = "    " + result.label + " = " + value + ";\n";
    return result;
}

attributes makeIdentifier(const string& name)
{
    symbol variable = getOrCreateSymbol(name);

    attributes result;
    result.label = variable.address;
    result.type = variable.type;
    result.translation = "";
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
    result.translation = expr.translation;

    if (target.type == expr.type) {
        result.translation += "    " + target.label + " = " + expr.label + ";\n";
    } else {
        symbol converted = createTemp(target.type);
        result.translation += "    " + converted.address + " = (" + typeToC(target.type) + ") " + expr.label + ";\n";
        result.translation += "    " + target.label + " = " + converted.address + ";\n";
    }

    return result;
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

        resultType = (l.type == t_float || r.type == t_float) ? t_float : t_int;

        if (resultType == t_float && l.type == t_int) {
            symbol converted = createTemp(t_float);
            code += "    " + converted.address + " = (float) " + l.label + ";\n";
            l.label = converted.address;
            l.type = t_float;
        }

        if (resultType == t_float && r.type == t_int) {
            symbol converted = createTemp(t_float);
            code += "    " + converted.address + " = (float) " + r.label + ";\n";
            r.label = converted.address;
            r.type = t_float;
        }
    } else {
        yyerror("operador binario desconhecido: " + op);
    }

    symbol temporary = createTemp(resultType);

    attributes result;
    result.label = temporary.address;
    result.type = resultType;
    result.translation = code + "    " + result.label + " = " + l.label + " " + op + " " + r.label + ";\n";
    return result;
}

attributes makeRelational(const attributes& left, const string& op, const attributes& right)
{
    attributes l = left;
    attributes r = right;
    string code = l.translation + r.translation;

    bool equalityOperator = (op == "==" || op == "!=");

    if (isNumeric(l.type) && isNumeric(r.type)) {
        types comparisonType = (l.type == t_float || r.type == t_float) ? t_float : t_int;

        if (comparisonType == t_float && l.type == t_int) {
            symbol converted = createTemp(t_float);
            code += "    " + converted.address + " = (float) " + l.label + ";\n";
            l.label = converted.address;
            l.type = t_float;
        }

        if (comparisonType == t_float && r.type == t_int) {
            symbol converted = createTemp(t_float);
            code += "    " + converted.address + " = (float) " + r.label + ";\n";
            r.label = converted.address;
            r.type = t_float;
        }
    } else if (equalityOperator && l.type == r.type && (l.type == t_bool || l.type == t_char)) {
        /* igualdade e diferenca sao permitidas para boolean e char do mesmo tipo */
    } else {
        yyerror("operador " + op + " nao aceita " + typeToText(l.type) + " e " + typeToText(r.type));
    }

    symbol temporary = createTemp(t_bool);

    attributes result;
    result.label = temporary.address;
    result.type = t_bool;
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
    result.translation = expr.translation + "    " + result.label + " = (" + typeToC(targetType) + ") " + expr.label + ";\n";
    return result;
}

void printProgram(const string& body)
{
    cout << "#include <stdio.h>\n\n";
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

    return yyparse();
}
