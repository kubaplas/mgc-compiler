%option noyywrap
%option yylineno

%{
#include "bison.tab.h"
#include <iostream>
#include <string>
#include <vector>
using namespace std;
int yylex();
%}
%x KOM
%%
<INITIAL>{
"(*"            BEGIN(KOM);
"CONST"			{ return CONST; }
"VAR"			{ return VAR; }
"BEGIN"			{ return START; }
"END"			{ return END; }
"READ"			{ return READ; }
"WRITE"			{ return WRITE; }
"IF"            { return IF; }
"THEN"          { return THEN; }
"ELSE"          { return ELSE; }
"WHILE"         { return WHILE; }
"DO"            { return DO; }
">"             { return GT; }
"<"             { return LT; }
"!="            { return NE; }
"<="            { return LE; }
">="            { return GE; }
"="				{ return EQ; }
":="			{ return ASSIGN; }
"+"				{ return ADD; }
"-"				{ return SUB; }
"*"             { return MUL; }
"/"             { return DIV; }
"%"             { return MOD; }
";"				{ return SEMICOLON; }
[0-9]+			{
					yylval.str = strdup(yytext);
					return NUM;
				}
[a-z]+			{ 	yylval.str = strdup(yytext);
					return ID;
				}
[ \t\r\n]+  	{ }
.				{ return BLAD; }
}
<KOM>"*)"       { BEGIN(0); }
<KOM>[ \t\r\n]+  { }
<KOM>. { }
%%
