%{
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "ptucc_parser.tab.h"
#include "cgen.h"

int line_num = 1;
char buf[100];
char *s ;

/* Macro buffer = 32 different macros*/
char* mactable_name[MAXMACRO];
char* mactable_def[MAXMACRO];
int mactable_size = 0;


/* Macro buffer = 32 different macros*/
//#define MAXDEF 32
char* deftable[MAXDEF];
int deftable_size;



%}

BOOL 		("true"|"false")
ID 			[a-zA-Z_][0-9a-zA-Z_]*
STRING  	((\")(\\[ntr\\\'\"]|[^\"])*(\"))|((\')(\\[ntr\\\'\"]|[^\'])*(\'))
DIGIT  		[0-9]
NUMBER  	{DIGIT}{DIGIT}*
DECIMAL 	("."{NUMBER})|({NUMBER}("."{NUMBER}?)?)
REAL    	{DECIMAL}([eE][+-]?{NUMBER})?
RELOP		["&&"|"||"|"!"]



%x comment
%x macro
%x line_comment

%%

@defmacro[ \r\t]+       BEGIN(macro);
<macro>{ID}             {
							/* Store macro name which is in yytext*/
							char* name = strdup(yytext);
							/* Everything from now to the end of line is the macro itself*/
							char* def = NULL;
							size_t deflen = 0;
							char c;
							/*open memory as IO*/
							FILE* deff = open_memstream(&def, &deflen);
							/* TODO: Use this technique for Strings*/
							/*Stream everything until '\n' to memory*/
							while((c=input())!='\n')
							   fputc(c, deff);
							/*Close memory IO stream*/   
							fclose(deff);
							/*Try to set macro using the previously created buffer*/
							if(!set_macro(name, def))
								/*if set_macro() fails print error*/
								yyerror("lexer error: failed to define macro '%s'\n", name);
							BEGIN(INITIAL);
						};

program					return KW_PROGRAM;
begin 					return KW_BEGIN;
end						return KW_END;


and						return KW_AND;
div						return KW_DIV;
function				return KW_FUNCTION;
mod						return KW_MOD;
procedure				return KW_PROCEDURE;
result					return KW_RESULT;
array					return KW_ARRAY;
do						return KW_DO;
goto					return KW_GOTO;
not 					return KW_NOT;
return					return KW_RETURN;
boolean					return KW_BOOLEAN;
else					return KW_ELSE;
if						return KW_IF;
of						return KW_OF;
real					return KW_REAL;
then					return KW_THEN;
char					return KW_CHAR;
for						return KW_FOR;
integer					return KW_INTEGER;
or						return KW_OR;
repeat					return KW_REPEAT;
until					return KW_UNTIL;
var						return KW_VAR;
while					return KW_WHILE;
to						return KW_TO;
downto					return KW_DOWNTO;
type					return KW_TYPE;

{BOOL}					{ char* token = strdup(yytext);
						  if(token[0]=='t'){
						  	yylval.crepr = strdup("1");
						  }
						  else{
						  	yylval.crepr = strdup("0");
						  }
						  return BOOL;
						}
{ID}  					{
						   /* Get the macro */
						   char* def = get_macro(yytext);	
						   int type_def = get_def(yytext);

						   if(def==NULL) {
						   		yylval.crepr = strdup(yytext);
						   		/* If no macro found, Check if ID is a defined TYPE*/
						   		if(type_def==1){
						   			/*Return ID as Defined TYPE*/
						   			return DEF_TYPE;
						   		}
						   		else{
						   			/*Return ID as IDENT*/
						   			return IDENT;
						   		}
						   }
						   /*Else put the macro back in yytext to be processed normaly */
						   for(int i=strlen(def); i>0; i--) {
						   	  unput(def[i-1]);
						   }
						}


{NUMBER}				{ yylval.crepr = strdup(yytext); return POSINT; }
{REAL}					{ yylval.crepr = strdup(yytext); return REAL; }
{STRING}				{ 
						  yylval.crepr = strdup(yytext);
						  return STRING;
						}


- 						return SY_DASH;
"/"						return SY_SLASH;
=						return SY_EQUALS;
"<"						return SY_LESS;
">"						return SY_GREATER;
"<="					return SY_LESS_EQUALS;
"<>"					return SY_LESS_BIGGER;
">="					return SY_GREATER_EQUALS;
&&						return SY_AND;
"||"					return SY_OR;
"!"						return SY_NOT;
":="					return SY_ASSIGN;

","						return SY_COMMA;
"["						return SY_LEFT_SQR_BRACKET;
"]"						return SY_RIGHT_SQR_BRACKET;
":"						return SY_COLON;


"+"						return SY_PLUS;
"*"						return SY_STAR;
";"						return SY_SEMICOLON;
"."						return SY_PERIOD;
"("						return SY_LEFT_BRACKET;
")"						return SY_RIGHT_BRACKET;


"(*"					BEGIN(comment);
<comment>[^*\n]*        /* eat anything that's not a '*' */
<comment>"*"+[^*)\n]*   /* eat up '*'s not followed by ')'s */
<comment>\n             ++line_num;
<comment>"*"+")"        BEGIN(INITIAL);


"//" 					BEGIN(line_comment);
<line_comment>[^\n]*    
<line_comment>\n        BEGIN(INITIAL);


[ \r\t]					/* skip whitespace */
\n 						++line_num;
<<EOF>>					return EOF;

.        { yyerror(LE"unrecognized literal '%s'\n", yytext); }


%%