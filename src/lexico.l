%{
#include <string>
%}

%option noyywrap yylineno never-interactive

ESPACO      [ \t\r]
DIGITO      [0-9]
LETRA       [A-Za-z_]
ID          {LETRA}({LETRA}|{DIGITO})*
NUM         {DIGITO}+
REAL        {DIGITO}+"."{DIGITO}+
CHAR        \'([^\\\'\n]|\\[nrt\\\'\"])\'
STR         \"([^\\\"\n]|\\.)*\"

%%

"\n"                    { }
{ESPACO}+               { }
"//".*                  { }
"/*"([^*]|\*+[^*/])*\*+"/"  { }

"if"                    { yylval.label = yytext; return TK_IF; }
"else"                  { yylval.label = yytext; return TK_ELSE; }
"do"                    { yylval.label = yytext; return TK_DO; }
"while"                 { yylval.label = yytext; return TK_WHILE; }
"foreach"               { yylval.label = yytext; return TK_FOREACH; }
"for"                   { yylval.label = yytext; return TK_FOR; }
"break"                 { yylval.label = yytext; return TK_BREAK; }
"continue"              { yylval.label = yytext; return TK_CONTINUE; }
"match"                 { yylval.label = yytext; return TK_MATCH; }
"mout"                  { yylval.label = yytext; return TK_MOUT; }
"print"                 { yylval.label = yytext; return TK_PRINT; }
"log"                   { yylval.label = yytext; return TK_LOG; }
"error"                 { yylval.label = yytext; return TK_ERRORFN; }
"min"                   { yylval.label = yytext; return TK_MIN; }
"scan"                  { yylval.label = yytext; return TK_SCAN; }
"in"                    { yylval.label = yytext; return TK_IN; }
"ci"                    { yylval.label = yytext; return TK_CI; }
"all"                   { yylval.label = yytext; return TK_ALL; }
"null"                  { yylval.label = yytext; return TK_NULL; }

"int"                   { return TK_TYPE_INT; }
"float"                 { return TK_TYPE_FLOAT; }
"double"                { return TK_TYPE_DOUBLE; }
"bool"                  { return TK_TYPE_BOOLEAN; }
"boolean"               { return TK_TYPE_BOOLEAN; }
"char"                  { return TK_TYPE_CHAR; }
"string"                { return TK_TYPE_STRING; }

"true"                  { yylval.label = "1"; return TK_BOOL; }
"false"                 { yylval.label = "0"; return TK_BOOL; }

">="                    { yylval.label = yytext; return TK_OP_GREATER_EQUAL; }
"<="                    { yylval.label = yytext; return TK_OP_LESS_EQUAL; }
"=="                    { yylval.label = yytext; return TK_OP_EQUAL; }
"!="                    { yylval.label = yytext; return TK_OP_DIF; }
"&&"                    { yylval.label = yytext; return TK_OP_AND; }
"||"                    { yylval.label = yytext; return TK_OP_OR; }

"++"                    { return TK_INC; }
"--"                    { return TK_DEC; }
"+="                    { return TK_PLUS_EQ; }
"-="                    { return TK_MINUS_EQ; }
"*="                    { return TK_TIMES_EQ; }
"/="                    { return TK_DIV_EQ; }
"%="                    { return TK_MOD_EQ; }

[(){}[\];,]             { return *yytext; }
[+\-*/%]                { yylval.label = yytext; return *yytext; }
[><]                    { yylval.label = yytext; return *yytext; }
"!"                     { yylval.label = yytext; return *yytext; }
"="                     { yylval.label = yytext; return '='; }

"->"                    { return TK_ARROW; }
"_"                     { return TK_UNDERSCORE; }

{STR}                   { yylval.label = yytext; return TK_STRING; }
{REAL}                  { yylval.label = yytext; return TK_REAL; }
{NUM}                   { yylval.label = yytext; return TK_NUM; }
{CHAR}                  { yylval.label = yytext; return TK_CHAR; }
{ID}                    { yylval.label = yytext; return TK_ID; }

.                       { yyerror(std::string("caractere nao reconhecido: ") + yytext); }

%%
