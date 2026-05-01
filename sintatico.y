%{
#include <iostream>
#include <map>
#include <string>
#include <sstream>
#include <stack>
#include <list>

#define YYSTYPE attributes

using namespace std;

int var_temp_qnt;
int label_temp_qnt;

enum types{
	null = 0,
	t_int = 1,
	t_float = 2,
	t_bool = 3,
	t_char = 4,
};

struct attributes
{
	string label;
	string translation;
	types type;
};

typedef struct{
	string name;
	types type;
	string address;
	bool istemp;
}symbol;

typedef struct{
	void *staticlink;
	list <symbol> table;
}activationRecord;

typedef struct{
	types parameter1;
	types parameter2;
	string operation;
	types action;
	bool orderMatters;
}comparison;
 
stack<map<string, attributes>> switchCase;

stack<map<string, string>> labelTable;

map<string, comparison> comparisonTable;

list <symbol> global;

stack< activationRecord > symbolTable;

int yylex(void);
void yyerror(string);
bool findSymbol(symbol);
bool findSymbolOneScope(symbol);
symbol getSymbol(string);
symbol getSymbolAddress(string);
void insertTable(string, types, string, bool);
void existInTable(string, types);
void printScope();
types findComparison(types, types, string);
string getEnum(types);
string gentempcode();
string gentemplabel();
attributes binaryOperator(attributes, attributes, attributes);
attributes relationalOperator(attributes, attributes, attributes);
%}

%token TK_NUM TK_REAL TK_BOOL TK_CHAR
%token TK_MAIN TK_ID TK_TYPE_INT TK_TYPE_FLOAT TK_TYPE_BOOL TK_TYPE_CHAR
%token TK_OP_GREATER_EQUAL TK_OP_LESS_EQUAL TK_OP_EQUAL TK_OP_DIF
%token TK_OP_AND TK_OP_OR
%token TK_IF TK_ELSE TK_SWITCH TK_CASE TK_DEFAULT TK_DO TK_WHILE TK_FOR TK_BREAK TK_CONTINUE TK_SCAN TK_PRINT
%token TK_END TK_ERROR

%start S

%left TK_OP_OR
%left TK_OP_AND
%left TK_OP_EQUAL TK_OP_DIF
%left '>' '<' TK_OP_GREATER_EQUAL TK_OP_LESS_EQUAL
%left '+' '-'
%left '*' '/' '%'
%left '!'
%left '(' ')'

%%

S 			: COMANDS
			{
				string code = "/*AERITH Compiler*/\n"
								"#include <iostream>\n"
								"#include <string.h>\n"
								"#include <stdio.h>\n"
								"#define bool int\n"
								"#define True 1\n"
								"#define False 0\n"
								"int main(void) {\n";

				for(auto it = symbolTable.top().table.begin(); it != symbolTable.top().table.end(); ++it){
					code += "\t" + getEnum(it->type) + " " + it->address + "; " + "//" + it->name + "\n" ;
				}
								
				code += "\n" + $1.translation;
								
				code += 	"\treturn 0;"
							"\n}";

				cout << code << endl;
			}
			;

BEGIN_BLOCK : '{'
			{
				activationRecord newActivationRecord;
				list<symbol> block;
				newActivationRecord.staticlink = &symbolTable.top();
				newActivationRecord.table = block;

				symbolTable.push(newActivationRecord);
				$$.translation = "";
			}

BEGIN_SWITCH: '{'
			{
				map<string, attributes> switchInstance;
				map<string, string> whileInstance;
				activationRecord newActivationRecord;
				list<symbol> block;
				newActivationRecord.staticlink = &symbolTable.top();
				newActivationRecord.table = block;

				labelTable.push(whileInstance);
				switchCase.push(switchInstance);
				symbolTable.push(newActivationRecord);

				labelTable.top()["break"] = gentemplabel();
				$$.translation = "";
			}

BEGIN_WHILE : '{'
			{ 
				map<string, string> whileInstance;
				activationRecord newActivationRecord;
				list<symbol> block;
				newActivationRecord.staticlink = &symbolTable.top();
				newActivationRecord.table = block;

				labelTable.push(whileInstance);
				symbolTable.push(newActivationRecord);

				labelTable.top()["break"] = gentemplabel();
				labelTable.top()["continue"] = gentemplabel();
				$$.translation = "";
			}

BLOCK		: BEGIN_BLOCK COMANDS '}'
			{
				for(auto it = symbolTable.top().table.begin(); it != symbolTable.top().table.end(); ++it){
					$$.translation += "\t" + getEnum(it->type) + " " + it->address + "; " + "//" + it->name + "\n" ;
				}

				printScope();
				$$.translation += $2.translation;
				symbolTable.pop();
			}
			| COMAND
			{
				$$.translation = $1.translation;
			}
			;

COMANDS		: COMAND COMANDS
			{
				$$.translation = $1.translation + $2.translation;
			}
			| BLOCK COMANDS
			{
				$$.translation = $1.translation + $2.translation;
			}
			|
			{
				$$.translation = "";
			}
			;

TYPE 		: TK_TYPE_INT
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
			| TK_TYPE_BOOL
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

CASES		: CASE CASES
 			{
				$$.translation = $1.translation;
				$$.translation += "\tgoto " + labelTable.top()["break"] + ";\n";
				$$.translation += $2.translation;
			}
			| TK_DEFAULT ':' COMANDS
			{
				string caseLabel = gentemplabel();

				switchCase.top()["default"] = {caseLabel};
				$$.translation = "\t" + caseLabel + ":\n";
				$$.translation += $3.translation;
				$$.translation += "\tgoto " + labelTable.top()["break"] + ";\n";
			}
			|
			{
				$$.label = gentemplabel();
				$$.translation = "";
			}
			;

CASE		: TK_CASE E ':' COMANDS
			{
				string caseLabel = gentemplabel();
				$$.type = $2.type;

				switchCase.top()[$2.label] = {caseLabel, $2.translation};

				$$.translation = "\t" + caseLabel + ":\n"; 
				$$.translation += $4.translation;
			}
			;

COMAND 		: E ';'
			{
				$$ = $1;
			}
			| TYPE TK_ID ';'
			{
				$$.type = $1.type;
				$$.label = "";
				$$.translation = "";

				insertTable($2.label, $$.type, gentempcode(), false);
			}
			| TK_IF '(' E ')' BLOCK
			{
				string end = gentemplabel();
				$$.label = gentempcode();
				$$.type = $3.type;

				if($$.type != t_bool){
					yyerror($1.label + " apenas aceita o tipo bool");
				}

				$$.translation = $3.translation + "\t" + $$.label + " = " + "!" + $3.label + ";\n";
				$$.translation += "\t" + $1.label + " (" + $$.label + ")" + " goto " + end + ";\n";
				$$.translation += $5.translation;
				$$.translation += "\t" + end + ":\n";

				insertTable("", $$.type, $$.label, true);
			}
			| TK_IF '(' E ')' BLOCK TK_ELSE BLOCK
			{
				string ELSE = gentemplabel();
				string end = gentemplabel();
				$$.label = gentempcode();
				$$.type = $3.type;

				if($$.type != t_bool){
					yyerror($1.label + " apenas aceita o tipo bool");
				}

				$$.translation = $3.translation + "\t" + $$.label + " = " + "!" + $3.label + ";\n";
				$$.translation += "\t" + $1.label + " (" + $$.label + ")" + " goto " + ELSE + ";\n";
				$$.translation += $5.translation;
				$$.translation += "\t" "go to " + end + ";\n";
				$$.translation += "\t" + ELSE + ":\n";
				$$.translation += $7.translation;
				$$.translation += "\t" + end + ":\n";

				insertTable("", $$.type, $$.label, true);
			}
			| TK_SWITCH '(' TK_ID ')' BEGIN_SWITCH CASES '}'
			{
				string test = gentemplabel();

				for(auto it = symbolTable.top().table.begin(); it != symbolTable.top().table.end(); ++it){
					$$.translation += "\t" + getEnum(it->type) + " " + it->address + "; " + "//" + it->name + "\n" ;
				}

				$$.translation += "\tgoto " + test + ";\n";
				$$.translation += $6.translation;
				$$.translation += "\t" + test + ":\n";

				for(auto it = switchCase.top().begin(); it != switchCase.top().end(); ++it){
					if(it->first == "default")
						continue;

					symbol id1 = getSymbol($3.label);
					symbol id2 = getSymbolAddress(it->first);
					attributes translation;

					attributes temp1 = {$3.label, "", id1.type};
					attributes temp2 = {"=="};
					attributes temp3 = {it->first, "", id2.type};

					translation = relationalOperator(temp1, temp2, temp3);
					symbol id3 = getSymbolAddress(translation.label);
					
					$$.translation += "\t" + getEnum(id3.type) + " " + id3.address + "; " + "//" + id3.name + "\n" ;
					$$.translation += it->second.translation;
					$$.translation += translation.translation;
					$$.translation += "\tif (" + translation.label + ") goto " + it->second.label + ";\n";
				}
				
				map<string, attributes>::iterator it = switchCase.top().find("default");
				if(it != switchCase.top().end()){
					$$.translation += "\tgoto " + it->second.label + ";\n";
				}

				$$.translation += "\t" + labelTable.top()["break"] + ":\n";

				labelTable.pop();
				symbolTable.pop();
				switchCase.pop();
			}
			| TK_WHILE '(' E ')' BEGIN_WHILE COMANDS '}'
			{
				string loop = labelTable.top()["continue"];
				string end = labelTable.top()["break"];
				$$.label = gentempcode();
				$$.type = $3.type;
								
				insertTable("", $$.type, $$.label, true);

				for(auto it = symbolTable.top().table.begin(); it != symbolTable.top().table.end(); ++it){
					$$.translation += "\t" + getEnum(it->type) + " " + it->address + "; " + "//" + it->name + "\n" ;
				}

				$$.translation += "\t" + loop + ":\n";
				$$.translation += $3.translation;
				$$.translation += "\t" + $$.label + " = !" + $3.label + ";\n";
				$$.translation += "\tif (" + $$.label + ")" + " goto " + end + ";\n";
				$$.translation += $6.translation;
				$$.translation += "\tgoto " + loop + ";\n";
				$$.translation += "\t" + end + ":\n";

				symbolTable.pop();
				labelTable.pop();
			}
			| TK_DO BEGIN_WHILE COMANDS '}' TK_WHILE '(' E ')' ';'
			{
				string loop = labelTable.top()["continue"];
				string end = labelTable.top()["break"];

				for(auto it = symbolTable.top().table.begin(); it != symbolTable.top().table.end(); ++it){
					$$.translation += "\t" + getEnum(it->type) + " " + it->address + "; " + "//" + it->name + "\n" ;
				}

				$$.type = $7.type;

				if($$.type != t_bool){
					yyerror($1.label + " apenas aceita o tipo bool");
				}

				$$.translation += "\t" + loop + ":\n";
				$$.translation += $7.translation + $3.translation;
				$$.translation += "\tif (" + $7.label + ")" + " goto " + loop + ";\n";
				$$.translation += "\t" + end + ":\n";

				symbolTable.pop();
				labelTable.pop();
			}
			| TK_FOR '(' E ';' E ';' E ')' BEGIN_WHILE COMANDS '}'
			{
				string loop = gentemplabel();
				string end = labelTable.top()["break"];
				$$.label = gentempcode();
				$$.type = $5.type;
				
				insertTable("", $$.type, $$.label, true);

				for(auto it = symbolTable.top().table.begin(); it != symbolTable.top().table.end(); ++it){
					$$.translation += "\t" + getEnum(it->type) + " " + it->address + "; " + "//" + it->name + "\n" ;
				}

				$$.translation += $3.translation;
				$$.translation += "\t" + loop + ":\n";
				$$.translation += $5.translation;
				$$.translation += "\t" + $$.label + " = " + "!" + $5.label + ";\n";
				$$.translation += "\tif (" + $$.label + ")" + " goto " + end + ";\n";
				$$.translation += $10.translation;
				$$.translation += "\t" + labelTable.top()["continue"] + ":\n";
				$$.translation += $7.translation;
				$$.translation += "\tgoto " + loop + ";\n";
				$$.translation += "\t" + end + ":\n";

				symbolTable.pop();
				labelTable.pop();
			}
			| TK_BREAK ';'
			{
				if(labelTable.empty()){
				 	yyerror("nao eh possivel usar o comando break fora de um loop ou switch.");
				}

				$$.translation = "\tgoto " + labelTable.top()["break"] + ";\n";
			}
			| TK_CONTINUE ';'
			{ 
				if(labelTable.empty()){
				 	yyerror("nao eh possivel usar o comando continue fora de um loop.");
				}

				$$.translation = "\tgoto " + labelTable.top()["continue"] + ";\n";
			} 
			| TK_SCAN '(' TK_ID ')' ';'
			{
				symbol id = getSymbol($3.label);

				existInTable($3.label, $3.type);

				$$.translation = $3.translation + "\t";
				$$.translation += "cin >> " + id.address + ";\n";
			}
			| TK_PRINT '(' E ')' ';'
			{
				$$.translation = $3.translation + "\t";
				$$.translation += "cout << " + $3.label + ";\n";
			}
			;

E 			: '(' E ')'
			{
				$$.type = $2.type;
				$$.label = $2.label;
				$$.translation = $2.translation;
			}
			| '(' TYPE ')' E
			{
				$$.type = $2.type;
				$$.label = gentempcode();

				$$.translation = $4.translation + "\t" + $$.label + " = " + "(" + getEnum($2.type) + ") " + $4.label + ";\n";

				insertTable("", $$.type, $$.label, true);	
			}
			| E '+' E
			{
				$$ = binaryOperator($1, $2, $3);
			}
			| E '-' E
			{
				$$ = binaryOperator($1, $2, $3);
			}
			| E '*' E
			{
				$$ = binaryOperator($1, $2, $3);
			}
			| E '/' E
			{
				$$ = binaryOperator($1, $2, $3);
			}
			| E '%' E
			{
				$$ = binaryOperator($1, $2, $3);
			}
			| E '>' E
			{
				$$ = relationalOperator($1, $2, $3);
			}
			| E '<' E
			{
				$$ = relationalOperator($1, $2, $3);
			}
			| E TK_OP_GREATER_EQUAL E
			{
				$$ = relationalOperator($1, $2, $3);
			}
			| E TK_OP_LESS_EQUAL E
			{
				$$ = relationalOperator($1, $2, $3);
			}
			| E TK_OP_EQUAL E
			{
				$$ = relationalOperator($1, $2, $3);
			}
			| E TK_OP_DIF E
			{
				$$ = relationalOperator($1, $2, $3);
			}
			| E TK_OP_AND E
			{
				$$ = binaryOperator($1, $2, $3);
			}
			| E TK_OP_OR E
			{
				$$ = binaryOperator($1, $2, $3);
			}
			|'!' E
			{
				types resultType = findComparison($2.type, null, $1.label);

				if(resultType == null){
					yyerror("não é possivel fazer a operação de " + $1.label + " com o tipo " + getEnum($2.type));
				}

				$$.translation = $2.translation + "\t";

				$$.label = gentempcode();
				$$.type = resultType;
				$$.translation += $$.label + " = " + $1.label + $2.label + ";\n";

				insertTable("", $$.type, $$.label, true);
			}
			| TK_ID '=' E
			{
				symbol id = getSymbol($1.label);

				$$.label = id.address;
				$$.type = id.type;

				existInTable($1.label, $1.type);

				types resultType = findComparison($$.type, $3.type, $2.label);

				if(resultType == null){
					yyerror("não é possivel converter " + getEnum($3.type) + " para o tipo " + getEnum($$.type));
				}

				if($3.type != $$.type){
					$$.translation = $1.translation + $3.translation + "\t" + id.address + " = " + "(" + getEnum($$.type)+ ") " + $3.label + ";\n";
				}
				else{
					$$.translation = $1.translation + $3.translation + "\t" + id.address + " = " + $3.label + ";\n";
				}

			}
			| TK_NUM
			{
				$$.label = gentempcode();
				$$.translation = "\t" + $$.label + " = " + $1.label + ";\n";
				$$.type = t_int;

				insertTable("", $$.type, $$.label, true);
			}
			| TK_REAL
			{
				$$.label = gentempcode();
				$$.translation = "\t" + $$.label + " = " + $1.label + ";\n";
				$$.type = t_float;

				insertTable("", $$.type, $$.label, true);
			}
			| TK_BOOL
			{
				$$.label = gentempcode();
				$$.translation = "\t" + $$.label + " = " + $1.label + ";\n";
				$$.type = t_bool;

				insertTable("", $$.type, $$.label, true);
			}
			| TK_CHAR
			{
				$$.label = gentempcode();
				$$.translation = "\t" + $$.label + " = " + $1.label + ";\n";
				$$.type = t_char;

				insertTable("", $$.type, $$.label, true);
			}
			| TK_ID
			{
				symbol id = getSymbol($1.label);
				$$.label = id.address;
				$$.translation = "";
				$$.type = id.type;

				existInTable($1.label, $1.type);
			}
			;

%%

#include "lex.yy.c"

int yyparse();

int main(int argc, char* argv[])
{
	activationRecord first;

	first.table = global;
	first.staticlink = NULL;

	symbolTable.push(first);

	/* adding operators type rules */
	comparisonTable["= (int-int)"] = {t_int, t_int, "=", t_int, 1};
	comparisonTable["= (float-float)"] = {t_float, t_float, "=", t_float, 1};
	comparisonTable["= (float-int)"] = {t_float, t_int, "=", t_float, 1};
	comparisonTable["= (bool-bool)"] = {t_bool, t_bool, "=", t_bool, 1};
	comparisonTable["= (char-char)"] = {t_char, t_char, "=", t_char, 1};
	comparisonTable["* (int-int)"] = {t_int, t_int, "*", t_int, 0};
	comparisonTable["* (float-float)"] = {t_float, t_float, "*", t_float, 0};
	comparisonTable["* (int-float)"] = {t_int, t_float, "*", t_float, 0};
	comparisonTable["/ (int-int)"] = {t_int, t_int, "/", t_int, 0};
	comparisonTable["/ (float-float)"] = {t_float, t_float, "/", t_float, 0};
	comparisonTable["/ (int-float)"] = {t_int, t_float, "/", t_float, 0};
	comparisonTable["% (int-int)"] = {t_int, t_int, "%", t_int, 0};
	comparisonTable["% (float-float)"] = {t_float, t_float, "%", t_float, 0};
	comparisonTable["% (int-float)"] = {t_int, t_float, "%", t_float, 0};
	comparisonTable["+ (int-int)"] = {t_int, t_int, "+", t_int, 0};
	comparisonTable["+ (float-float)"] = {t_float, t_float, "+", t_float, 0};
	comparisonTable["+ (int-float)"] = {t_int, t_float, "+", t_float, 0};
	comparisonTable["- (int-int)"] = {t_int, t_int, "-", t_int, 0};
	comparisonTable["- (float-float)"] = {t_float, t_float, "-", t_float, 0};
	comparisonTable["- (int-float)"] = {t_int, t_float, "-", t_float, 0};
	comparisonTable["> (int-int)"] = {t_int, t_int, ">", t_int, 0};
	comparisonTable["> (float-float)"] = {t_float, t_float, ">", t_float, 0};
	comparisonTable["> (int-float)"] = {t_int, t_float, ">", t_float, 0};
	comparisonTable["< (int-int)"] = {t_int, t_int, "<", t_int, 0};
	comparisonTable["< (float-float)"] = {t_float, t_float, "<", t_float, 0};
	comparisonTable["< (int-float)"] = {t_int, t_float, "<", t_float, 0};
	comparisonTable[">= (int-int)"] = {t_int, t_int, ">=", t_int, 0};
	comparisonTable[">= (float-float)"] = {t_float, t_float, ">=", t_float, 0};
	comparisonTable[">= (int-float)"] = {t_int, t_float, ">=", t_float, 0};
	comparisonTable["<= (int-int)"] = {t_int, t_int, "<=", t_int, 0};
	comparisonTable["<= (float-float)"] = {t_float, t_float, "<=", t_float, 0};
	comparisonTable["<= (int-float)"] = {t_int, t_float, "<=", t_float, 0};
	comparisonTable["== (int-int)"] = {t_int, t_int, "==", t_int, 0};
	comparisonTable["== (float-float)"] = {t_float, t_float, "==", t_float, 0};
	comparisonTable["== (int-float)"] = {t_int, t_float, "==", t_float, 0};
	comparisonTable["== (char-char)"] = {t_char, t_char, "==", t_char, 0};
	comparisonTable["== (bool-bool)"] = {t_bool, t_bool, "==", t_bool, 0};
	comparisonTable["!= (int-int)"] = {t_int, t_int, "!=", t_int, 0};
	comparisonTable["!= (float-float)"] = {t_float, t_float, "!=", t_float, 0};
	comparisonTable["!= (int-float)"] = {t_int, t_float, "!=", t_float, 0};
	comparisonTable["!= (char-char)"] = {t_char, t_char, "!=", t_char, 0};
	comparisonTable["!= (bool-bool)"] = {t_bool, t_bool, "!=", t_bool, 0};
	comparisonTable["&& (bool-bool)"] = {t_bool, t_bool, "&&", t_bool, 0};
	comparisonTable["|| (bool-bool)"] = {t_bool, t_bool, "||", t_bool, 0};
	comparisonTable["! (bool)"] = {t_bool, null, "!", t_bool, 0};

	var_temp_qnt = 0;

	yyparse();

	printScope();

	return 0;
}

string gentempcode()
{
	var_temp_qnt++;
	return "t" + to_string(var_temp_qnt);
}

string gentemplabel()
{
	label_temp_qnt++;
	return "label" + to_string(label_temp_qnt);
}

// exibe uma mensagem de erro e encerra o programa.
void yyerror(string MSG)
{
	cout << MSG << endl;
	exit (0);
}

// retorna verdadeiro se existe a variavel em todas as tabelas de simbolos, falso caso contrario.
bool findSymbol(symbol variable){
	activationRecord *Iterator = &symbolTable.top();

	while(Iterator != NULL){
		for(auto it = Iterator->table.begin(); it != Iterator->table.end(); ++it){
			if(it->istemp == false && it->name == variable.name){
				return true;
			}	
		}

		Iterator = (activationRecord *) Iterator->staticlink;
	}

	return false;
}

// retorna verdadeiro se existe a variavel na tabela de simbolos atual, falso caso contrario.
bool findSymbolOneScope(symbol variable){

	for(auto it = symbolTable.top().table.begin(); it != symbolTable.top().table.end(); ++it){
		if(it->istemp == false && it->name == variable.name){
			return true;
		}	
	}

	return false;
}

// retorna a variavel na tabela de simbolos correspondente ao seu nome, retorna vazio caso contrario.
symbol getSymbol(string name){
	symbol variable;
	activationRecord *Iterator = &symbolTable.top();

	while(Iterator != NULL){
		for(auto it = Iterator->table.begin(); it != Iterator->table.end(); ++it){
			if(it->istemp == false && it->name == name){
				return *it;
			}	
		}

		Iterator = (activationRecord *) Iterator->staticlink;
	}

	return variable;
}

// retorna a variavel na tabela de simbolos correspondente ao seu enderesso, retorna vazio caso contrario.
symbol getSymbolAddress(string address){
	symbol variable;
	activationRecord *Iterator = &symbolTable.top();

	while(Iterator != NULL){
		for(auto it = Iterator->table.begin(); it != Iterator->table.end(); ++it){
			if(it->address == address){
				return *it;
			}	
		}

		Iterator = (activationRecord *) Iterator->staticlink;
	}

	return variable;
}

// exibe no terminal a tabela de simbolos no escopo atual.
void printScope(){

	for(auto it = symbolTable.top().table.begin(); it != symbolTable.top().table.end(); ++it){
		cout << it->name << " | " << getEnum(it->type) << " | " << it->address <<  " | " << it->istemp << endl;
		cout << endl;
	}

	return;
}

// retorna o nome dos tipos em string
string getEnum(types type){
	if(type == t_int)
		return "int";
	else if(type == t_float)
		return "float";
	else if(type == t_bool)
		return "bool";
	else if(type == t_char)
		return "char";
		
	return "";
}

// adiciona na tabela uma variavel, dado um nome, tipo, endereço(apelido gerado), e um boolean para saber se eh temporaria.
void insertTable(string name, types type, string address, bool istemp){
	symbol variable;
	variable.name = name;
	variable.type = type;
	variable.address = address;
	variable.istemp = istemp;

	if(!findSymbolOneScope(variable)){
		symbolTable.top().table.push_back(variable);
	}
	else{
		yyerror("A Variável " + variable.name + " ja foi declarada.");
	}
}

// verifica se foi declarada a variavel.
void existInTable(string name, types type){
	symbol variable;
	variable.name = name;
	variable.type = type;

	if(!findSymbol(variable)){
		yyerror("A Variável " + variable.name + " não foi declarada");
	}
}

// procura na tabela de comparações as operações com seus tipos permitidos, retorna o tipo para a conversão caso exista, retorna null caso não seja permitida essa operação.
types findComparison(types parameter1, types parameter2, string operation){
	for(auto it = comparisonTable.begin(); it != comparisonTable.end(); ++it){
		if(it->second.orderMatters == 1){
			if(it->second.operation == operation && parameter1 == it->second.parameter1 &&  parameter2 == it->second.parameter2){
				return it->second.action;
			}
		}
		else{
			if(it->second.operation == operation && parameter1 == it->second.parameter1 &&  parameter2 == it->second.parameter2){
				return it->second.action;
			}
			if(it->second.operation == operation && parameter1 == it->second.parameter2 &&  parameter2 == it->second.parameter1){
				return it->second.action;
			}
		}	
	}
	return null;
}

// realiza a gramatica para operadores binarios(exceto relacionais).
attributes binaryOperator(attributes $1, attributes $2, attributes $3){
	types resultType = findComparison($1.type, $3.type, $2.label);

	if(resultType == null){
		yyerror("não é possivel fazer a operação de " + $2.label + " com os tipos " + getEnum($1.type) + " e " + getEnum($3.type));
	}

	attributes $$;

	$$.translation = $1.translation + $3.translation + "\t";

	if($1.type != $3.type){
		symbol temp;
		temp.name = gentempcode();
		temp.type = resultType;
		$$.type = temp.type;
		$$.label = gentempcode();

		if($1.type != temp.type){
			$$.translation += temp.name + " = " + "(" + getEnum(temp.type) + ") " + $1.label + ";\n" + "\t";
			$$.translation += $$.label + " = " + temp.name + " " + $2.label + " " + $3.label + ";\n";
			insertTable("", temp.type, temp.name, true);
		}
		else{
			$$.translation += temp.name + " = " + "(" + getEnum(temp.type) + ") " + $3.label + ";\n" + "\t";
			$$.translation += $$.label + " = " + $1.label + " " + $2.label + " " + temp.name + ";\n";
			insertTable("", temp.type, temp.name, true);
		}
	}
	else{
		$$.label = gentempcode();
		$$.type = resultType;
		$$.translation += $$.label + " = " + $1.label + " " + $2.label + " " + $3.label + ";\n";
	}

	insertTable("", $$.type, $$.label, true);

	return $$;
}

// realiza a gramatica para os operadores relacionais.
attributes relationalOperator(attributes $1, attributes $2, attributes $3){
	types resultType = findComparison($1.type, $3.type, $2.label);

	if(resultType == null){
		yyerror("não é possivel fazer a operação de " + $2.label + " com os tipos " + getEnum($1.type) + " e " + getEnum($3.type));
	}

	attributes $$;

	$$.translation = $1.translation + $3.translation + "\t";

	if($1.type != $3.type){
		symbol temp;
		temp.name = gentempcode();
		temp.type = resultType;
		$$.type = t_bool;
		$$.label = gentempcode();

		if($1.type != temp.type){
			$$.translation += temp.name + " = " + "(" + getEnum(temp.type) + ") " + $1.label + ";\n" + "\t";
			$$.translation += $$.label + " = " + temp.name + " " + $2.label + " " + $3.label + ";\n";
			insertTable("", temp.type, temp.name, true);
		}
		else{
			$$.translation += temp.name + " = " + "(" + getEnum(temp.type) + ") " + $3.label + ";\n" + "\t";
			$$.translation += $$.label + " = " + $1.label + " " + $2.label + " " + temp.name + ";\n";
			insertTable("", temp.type, temp.name, true);
		}
	}
	else{
		$$.label = gentempcode();
		$$.type = t_bool;
		$$.translation += $$.label + " = " + $1.label + " " + $2.label + " " + $3.label + ";\n";
	}

	insertTable("", $$.type, $$.label, true);

	return $$;
}