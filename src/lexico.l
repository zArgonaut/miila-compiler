%{
#include <string>
extern int cur_line;
extern int cur_col;
extern int cur_tok_col;
#define YY_USER_ACTION { yylval.line = yylineno; cur_line = yylineno; \
                         yylval.col = cur_col; cur_tok_col = cur_col; cur_col += yyleng; }

static int interp_stack[32];
static int interp_sp = 0;
%}

%option noyywrap yylineno never-interactive

%x STR
%x MLSTR

ESPACO      [ \t\r]
DIGITO      [0-9]
LETRA       [A-Za-z_]
ID          {LETRA}({LETRA}|{DIGITO})*
NUM         {DIGITO}+
REAL        {DIGITO}+"."{DIGITO}+
CHAR        \'([^\\\'\n]|\\[nrt\\\'\"])\'

%%

"\n"                    { cur_col = 1; }
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
"fnc"                    { yylval.label = yytext; return TK_FNC; }
"return"                 { yylval.label = yytext; return TK_RETURN; }
"by"                     { yylval.label = yytext; return TK_BY; }
"len"                    { yylval.label = yytext; return TK_LEN; }
"push"                   { yylval.label = yytext; return TK_PUSH; }
"ext"                    { yylval.label = yytext; return TK_EXT; }
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

"**"                    { return TK_POW; }
"++"                    { return TK_INC; }
"--"                    { return TK_DEC; }
"+="                    { return TK_PLUS_EQ; }
"-="                    { return TK_MINUS_EQ; }
"*="                    { return TK_TIMES_EQ; }
"/="                    { return TK_DIV_EQ; }
"%="                    { return TK_MOD_EQ; }

"}"                     {
                            if (interp_sp > 0) { BEGIN(interp_stack[--interp_sp]); return TK_INTERP_END; }
                            return '}';
                        }
[(){[\];,]              { return *yytext; }
[+\-*/%]                { yylval.label = yytext; return *yytext; }
[><]                    { yylval.label = yytext; return *yytext; }
"!"                     { yylval.label = yytext; return *yytext; }
"="                     { yylval.label = yytext; return '='; }

"->"                    { return TK_ARROW; }
"_"                     { return TK_UNDERSCORE; }

\"\"\"                  { BEGIN(MLSTR); return TK_STR_BEGIN; }
\"                      { BEGIN(STR); return TK_STR_BEGIN; }
{REAL}                  { yylval.label = yytext; return TK_REAL; }
{NUM}                   { yylval.label = yytext; return TK_NUM; }
{CHAR}                  { yylval.label = yytext; return TK_CHAR; }
{ID}                    { yylval.label = yytext; return TK_ID; }

<STR>\"                 { BEGIN(INITIAL); return TK_STR_END; }
<STR>"#{"               { interp_stack[interp_sp++] = STR; BEGIN(INITIAL); return TK_INTERP_BEGIN; }
<STR>\\.                { yylval.label = yytext; return TK_STR_CHARS; }
<STR>"#"                { yylval.label = "#"; return TK_STR_CHARS; }
<STR>[^"\\#\n]+         { yylval.label = yytext; return TK_STR_CHARS; }
<STR>\n                 { yyerror("string de uma linha nao pode conter quebra de linha (use \"\"\" para multi-linha)"); BEGIN(INITIAL); cur_col = 1; return TK_STR_END; }

<MLSTR>\"\"\"           { BEGIN(INITIAL); return TK_STR_END; }
<MLSTR>"#{"             { interp_stack[interp_sp++] = MLSTR; BEGIN(INITIAL); return TK_INTERP_BEGIN; }
<MLSTR>\\.              { yylval.label = yytext; return TK_STR_CHARS; }
<MLSTR>\n               { cur_col = 1; yylval.label = "\\n"; return TK_STR_CHARS; }
<MLSTR>\"               { yylval.label = "\\\""; return TK_STR_CHARS; }
<MLSTR>"#"              { yylval.label = "#"; return TK_STR_CHARS; }
<MLSTR>[^"\\#\n]+       { yylval.label = yytext; return TK_STR_CHARS; }

.                       { yyerror(std::string("caractere nao reconhecido: ") + yytext); }

%%
