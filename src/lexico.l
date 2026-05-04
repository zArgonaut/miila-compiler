%{
#include <string>
%}

%option noyywrap yylineno

ESPACO      [ \t\r]
DIGITO      [0-9]
LETRA       [A-Za-z_]
ID          {LETRA}({LETRA}|{DIGITO})*
NUM         {DIGITO}+
REAL        {DIGITO}+"."{DIGITO}+
CHAR        \'([^\\\'\n]|\\[nrt\\\'\"])\'

%%

"\n"                    { }
{ESPACO}+               { }
"//".*                  { }
"/*"([^*]|\*+[^*/])*\*+"/"  { }

"if"                    { yylval.label = yytext; return TK_IF; }
"else"                  { yylval.label = yytext; return TK_ELSE; }
"switch"                { yylval.label = yytext; return TK_SWITCH; }
"case"                  { yylval.label = yytext; return TK_CASE; }
"default"               { yylval.label = yytext; return TK_DEFAULT; }
"do"                    { yylval.label = yytext; return TK_DO; }
"while"                 { yylval.label = yytext; return TK_WHILE; }
"for"                   { yylval.label = yytext; return TK_FOR; }
"read"                  { yylval.label = yytext; return TK_READ; }
"print"                 { yylval.label = yytext; return TK_PRINT; }
"break"                 { yylval.label = yytext; return TK_BREAK; }
"continue"              { yylval.label = yytext; return TK_CONTINUE; }

"int"                   { return TK_TYPE_INT; }
"float"                 { return TK_TYPE_FLOAT; }
"bool"                  { return TK_TYPE_BOOLEAN; }
"boolean"               { return TK_TYPE_BOOLEAN; }
"char"                  { return TK_TYPE_CHAR; }

"true"                  { yylval.label = "1"; return TK_BOOL; }
"false"                 { yylval.label = "0"; return TK_BOOL; }

">="                    { yylval.label = yytext; return TK_OP_GREATER_EQUAL; }
"<="                    { yylval.label = yytext; return TK_OP_LESS_EQUAL; }
"=="                    { yylval.label = yytext; return TK_OP_EQUAL; }
"!="                    { yylval.label = yytext; return TK_OP_DIF; }
"&&"                    { yylval.label = yytext; return TK_OP_AND; }
"||"                    { yylval.label = yytext; return TK_OP_OR; }

[(){}[\];,]             { return *yytext; }
[+\-*/%]                { yylval.label = yytext; return *yytext; }
[><]                    { yylval.label = yytext; return *yytext; }
"!"                     { yylval.label = yytext; return *yytext; }
"="                     { yylval.label = yytext; return '='; }

{REAL}                  { yylval.label = yytext; return TK_REAL; }
{NUM}                   { yylval.label = yytext; return TK_NUM; }
{CHAR}                  { yylval.label = yytext; return TK_CHAR; }
{ID}                    { yylval.label = yytext; return TK_ID; }

.                       { yyerror(std::string("caractere nao reconhecido: ") + yytext); }

%%
