%{
#include <string>

%}

ESPACO [ \t]
DIGITO [0-9]
LETRA [A-Za-z_]

DELIM {ESPACO}+
NUM {DIGITO}+
REAL {NUM}+("."{NUM}+)?
CHAR \'({LETRA}|{DIGITO})\'
BOOL ("True"|"False")
ID {LETRA}({LETRA}|{NUM})*

%%

"\n"		{}

{DELIM} 	{}

"main"		{return TK_MAIN;}

 /* comands */
"if"        {yylval.label = yytext; return TK_IF;}
"else"      {yylval.label = yytext; return TK_ELSE;}
"switch"    {yylval.label = yytext; return TK_SWITCH;}
"case"      {yylval.label = yytext; return TK_CASE;}
"default"   {yylval.label = yytext; return TK_DEFAULT;}
"do"        {yylval.label = yytext; return TK_DO;}
"while"     {yylval.label = yytext; return TK_WHILE;}
"for"       {yylval.label = yytext; return TK_FOR;}
"scan"      {yylval.label = yytext; return TK_SCAN;}
"print"     {yylval.label = yytext; return TK_PRINT;}
"break"     {yylval.label = yytext; return TK_BREAK;}
"continue"  {yylval.label = yytext; return TK_CONTINUE;}

 /* variables types */
"int"		{return TK_TYPE_INT;}
"float"     {return TK_TYPE_FLOAT;}
"bool"      {return TK_TYPE_BOOL;}
"char"      {return TK_TYPE_CHAR;}

[(){}[\];,]	{ return *yytext; }

 /* arithmetic operators */
[+\-*/%]	{yylval.label = yytext; return *yytext; }

 /* relational operators */
[>\<]       {yylval.label = yytext; return *yytext; }
">="        {yylval.label = yytext; return TK_OP_GREATER_EQUAL; }
"<="        {yylval.label = yytext; return TK_OP_LESS_EQUAL; }
"=="        {yylval.label = yytext; return TK_OP_EQUAL; }
"!="        {yylval.label = yytext; return TK_OP_DIF; }

 /* logic operators */
[!]         {yylval.label = yytext; return *yytext; }
"&&"        {yylval.label = yytext; return TK_OP_AND; }
"||"        {yylval.label = yytext; return TK_OP_OR; }

"="		    { yylval.label = yytext; return '='; }

{NUM}		{ yylval.label = yytext; return TK_NUM; }
{BOOL}      { yylval.label = yytext; return TK_BOOL; }
{ID}		{ yylval.label = yytext; return TK_ID; }
{REAL}		{ yylval.label = yytext; return TK_REAL; }
{CHAR}      { yylval.label = yytext; return TK_CHAR; }
.			{ return *yytext; }

%%