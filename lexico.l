%{
#include <string>
%}

%option noyywrap

DIGITO [0-9]
NUM {DIGITO}+

LETRA [a-zA-Z]
ID    {LETRA}({LETRA}|{DIGITO})*

%%

"\n"          { linha++; }
[ \t\r]+      { ; }

"int"         { return TK_TIPO_INT; }
"float"       { return TK_TIPO_FLOAT; }
"char"        { return TK_TIPO_CHAR; }
"bool"        { return TK_TIPO_BOOL; }

"true"        { yylval.label = "1"; return TK_BOOL_VAL; }
"false"       { yylval.label = "0"; return TK_BOOL_VAL; }

[+\-*/()]     { return *yytext; }
"="           { return *yytext; }
";"           { return *yytext; }

[a-zA-Z][a-zA-Z0-9]* { yylval.label = yytext; return TK_ID; }

{DIGITO}+"."{DIGITO}+ { yylval.label = yytext; return TK_FLOAT_VAL; }
{NUM}         { yylval.label = yytext; return TK_NUM; }
\'.\'         { yylval.label = yytext; return TK_CHAR_VAL; }

.             { fprintf(stderr, "Caractere nao reconhecido: %s\n", yytext); }

%%