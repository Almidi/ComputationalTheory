%{
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include "cgen.h"
extern int yylex(void);
extern int line_num;



%}

%union
{
	char* crepr;

      /*
      adv_data[2]=="s"  :Simple Data Type
                         adv_data[0] = type
                         adv_data[1] = ""
      adv_data[2]=="f"  :Function Data Type
                         adv_data[0] = return type
                         adv_data[1] = arguments

      adv_data[2]=="m"  :Matrix Data Type
                         adv_data[0] = type
                         adv_data[1] = matrix size
      */
      char* adv_data[3]; //for functions : [return type , arguments] for matrixes [type , matrix_size]
}



%token <crepr> IDENT
%token <crepr> POSINT 
%token <crepr> REAL 
%token <crepr> STRING
%token <crepr> CAST
%token <crepr> BOOL
%token <crepr> DEF_TYPE

%left  KW_DIV
%left  KW_AND
%left  KW_MOD
%right KW_NOT
%token KW_PROGRAM 
%token KW_BEGIN 
%token KW_END
%token KW_FUNCTION
%token KW_PROCEDURE
%token KW_RESULT
%token KW_ARRAY
%token KW_DO
%token KW_GOTO
%token KW_RETURN
%token KW_BOOLEAN
%token KW_OF
%token KW_REAL
%token KW_CHAR
%token KW_FOR
%token KW_INTEGER
%token KW_OR
%token KW_REPEAT
%token KW_UNTIL
%token KW_VAR
%token KW_WHILE
%token KW_TO
%token KW_DOWNTO
%token KW_TYPE

%token KW_IF
%nonassoc KW_THEN               //PRECEDENCE FOR IF THEN ELSE
%nonassoc KW_ELSE


%right SY_DASH					/* -  */
%right SY_PLUS					/* +  */
%left SY_STAR					/* *  */
%left SY_SLASH					/* /  */
%left SY_EQUALS					/* =  */
%left SY_LESS					/* <  */
%left SY_GREATER				      /* >  */
%left SY_LESS_EQUALS			      /* <= */
%left SY_GREATER_EQUALS			      /* <> */
%left SY_LESS_BIGGER			      /* >= */
%left SY_AND					/* && */
%left SY_OR						/* || */
%left SY_ASSIGN					/* := */
%right SY_NOT					/* !  */
%left SY_COMMA					/* ,  */
%left SY_LEFT_SQR_BRACKET		      /* [  */
%left SY_RIGHT_SQR_BRACKET		      /* ]  */
%left SY_COLON					/* :  */
%right SY_SEMICOLON				/* ;  */
%left SY_PERIOD					/* .  */
%right SY_LEFT_BRACKET			      /* (  */
%left SY_RIGHT_BRACKET			      /* )  */


%start program

%type <crepr> program_decl  var_decl
%type <crepr> proc_call arguments  
%type <crepr> arglist expression binary_exp unary_exp
%type <adv_data> adv_matrix_data_type adv_func_data_type advanced_data_type

%type <crepr> matrix_n var_decl_list var_list
%type <crepr> simple_data_type type_def type_list shortcut_data_type

%type <crepr> return_type function_header function_body
%type <crepr> args_decl args_decl_list  procedure_body subprogram subprogram_list procedure_header args_decl_excl args_decl_excl_list cmd_list_ws
%type <crepr> cmd_list cmd_list_wr all_commands complex_cmd simple_cmd  for_cmd while_cmd  if_cmd  func_complex_cmd 


%%


/**********************************PROGRAM***********************************************/

program   		   : program_decl type_def var_decl subprogram_list complex_cmd  SY_PERIOD			            { 
                               																/* We have a successful parse! 
                               																	Check for any errors and generate output. 
                               																*/
                               																if(yyerror_count==0) {
                               																	puts(c_prologue);
                               																	printf("/* program  %s */ \n\n", $1);
                               																	printf("%s\n",$2);
                               																	printf("%s\n",$3);
                               																	printf("%s\n",$4);
                               																	printf("int main(){%s} \n", $5);
                               																}
                               																else{
                               																	printf("%d Errors Detected. Exiting\n",yyerror_count);
                               																}
                               															}
                   | program_decl type_def var_decl subprogram_list complex_cmd error                                   { yyerror(SE"Period Expected\n");YYABORT;}
                   | program_decl type_def var_decl subprogram_list error                                               { yyerror(SE"Complex Command Expected\n");YYABORT; }
                   | error 														           							 	{ yyerror(SE"Program Declaration Expected\n");YYABORT;}
                   ;



program_decl       : KW_PROGRAM IDENT SY_SEMICOLON                                                                      { $$ = $2; } /*Return Identifier*/
			 | KW_PROGRAM IDENT  error                                                                     		{ yyerror(SE"Semicolon missing\n");} /*Return Identifier*/
			 | KW_PROGRAM error                                                                				{ yyerror(SE"Identifier missing\n");} /*Return Identifier*/
			 | error                                                                     					{ yyerror(SE"Keyword program missing\n");} /*Return Identifier*/
			 ; 

arguments          : %empty                                                                                             { $$ = ""; } /* init empty argumetns */
                   | arglist                                                                                            { $$ = $1; } /* list arguments */ 
                   | error                                                                                              { yyerror(SE"Incorect Arguments\n");}                            
                   ; 

arglist            : expression                                                                                         { $$ = $1; }  
                   | arglist SY_COMMA expression                                                                        { $$ = template("%s,%s", $1, $3);  } /*recursive for more expressions */
                   ; 


/************************************** Expressions ***************************************************/

unary_exp          : SY_PLUS                                expression                                                  { $$ = template("+%s", $2);}
unary_exp          : SY_DASH 						expression                                                  { $$ = template("-%s", $2);}
                   | KW_NOT                                 expression                                                  { $$ = template("!%s", $2);}
                   | SY_NOT 						expression                                                  { $$ = template("!%s", $2);}
                   | expression 					KW_NOT                                                      { $$ = template("%s!", $1);}
                   | expression                             SY_NOT		                                                      { $$ = template("%s!", $1);}
                   | SY_LEFT_BRACKET simple_data_type SY_RIGHT_BRACKET expression                                       { $$ = template("(%s)%s",$2,$4);}//Casting
                   ; 
                  

binary_exp         : expression SY_DASH				expression                                                  { $$ = template("%s-%s" , $1, $3);};
                   | expression SY_PLUS				expression                                                  { $$ = template("%s+%s" , $1, $3);};
                   | expression SY_STAR				expression                                                  { $$ = template("%s*%s" , $1, $3);};
                   | expression SY_SLASH			      expression                                                  { $$ = template("%s/%s" , $1, $3);};
                   | expression SY_EQUALS			      expression                                                  { $$ = template("%s==%s" , $1, $3);};
                   | expression SY_LESS				expression                                                  { $$ = template("%s<%s" , $1, $3);};
                   | expression SY_GREATER			expression                                                  { $$ = template("%s>%s" , $1, $3);};
                   | expression SY_LESS_EQUALS		      expression                                                  { $$ = template("%s<=%s", $1, $3);};
                   | expression SY_GREATER_EQUALS	      expression                                                  { $$ = template("%s>=%s", $1, $3);};
                   | expression SY_LESS_BIGGER		      expression                                                  { $$ = template("%s!=%s", $1, $3);};
                   | expression SY_AND				expression                                                  { $$ = template("%s&&%s", $1, $3);};
                   | expression SY_OR                       expression                                                  { $$ = template("%s||%s", $1, $3);};
                   | expression SY_ASSIGN                   expression                                                  { $$ = template("%s:=%s", $1, $3);};
                   | expression KW_AND				expression                                                  { $$ = template("%s&&%s", $1, $3);};
                   | expression KW_DIV				expression                                                  { $$ = template("%s/%s" , $1, $3);};
                   | expression KW_MOD				expression                                                  { $$ = template("%s %% %s" , $1, $3);}
                   ;


expression         : POSINT
                   | REAL							
                   | STRING                                                                                             { $$ = string_ptuc2c($1); };
	             | BOOL 							
                   | IDENT
                   | KW_RESULT                                                                                          { $$ = "result";}
                   | SY_LEFT_BRACKET expression SY_RIGHT_BRACKET                                                        { $$ = $2;} /* needs fixing for precedence */
                   | SY_LEFT_BRACKET error                                                                              { yyerror(SE"Right Bracket Expected");} /* needs fixing for precedence */
                   | unary_exp 
                   | binary_exp 
                   | proc_call 
                   | IDENT matrix_n                                                                                     { $$  = template("%s%s",$1,$2);}
                   ;



/************************************** Data types ***************************************************/

type_def           : %empty                                                                                             { $$ = ""; } /* in case of "type" at least one typedef must be found*/
                   | KW_TYPE type_list                                                                                  { $$=$2; }
                   ; 


type_list          : shortcut_data_type                                                                                  /*TODO Make sure this is correct ??*/
                   | type_list shortcut_data_type												{ $$ = template("%s\n%s", $1,$2); } 
                   //| error {yyerror(SE"Incorrect expression at type\n");}
                   ;

shortcut_data_type : IDENT SY_EQUALS advanced_data_type SY_SEMICOLON                                                    { $$ = template("typedef %s;\n",data_spread($3,$1,"")); 
																   		        	  set_def(strdup($1));} //SAVE SOMEWHERE THE DEFINED DATA TYPES					 
			 | IDENT SY_EQUALS error 							                                    {yyerror(SE"data type expected\n");}
					//| IDENT error							  			{yyerror(SE"equals expected\n");}
			 | IDENT SY_EQUALS advanced_data_type error   		                                                {yyerror(SE"semicolon expected\n"); }
			 ;

advanced_data_type : simple_data_type                                                                                   { $$[0] = $1; $$[1] = ""; $$[2]="s"; } //TODO split to all_data_types
                   | adv_func_data_type                                                                                 
                   | adv_matrix_data_type                                                                               
                   ;

//Distinct Function advanced data type due to syntax differences in compiling
adv_func_data_type : KW_FUNCTION SY_LEFT_BRACKET args_decl_excl SY_RIGHT_BRACKET return_type                            { $$[0] = $5; $$[1] = $3; $$[2] = "f";} // [return_type , arguments]
                   | KW_FUNCTION error                                                                                  { yyerror(SE"error using function data type\n"); }
                   ;

//Distinct Function advanced data type due to syntax differences in compiling
adv_matrix_data_type : KW_ARRAY KW_OF simple_data_type                                                                  { $$[0] = template("%s*",$3); $$[1] = ""; $$[2] = "m";} // [return_type , arguments]
                     | KW_ARRAY matrix_n KW_OF simple_data_type                                                         { $$[0] = template("%s",$4); $$[1] = $2; $$[2] = "m";}
                     | KW_ARRAY error                                                                                   { yyerror(SE"Error using array data type\n"); }
                     ;




matrix_n           : SY_LEFT_SQR_BRACKET expression SY_RIGHT_SQR_BRACKET                                                { $$ = template("[%s]",$2) ;}
                   | matrix_n SY_LEFT_SQR_BRACKET expression SY_RIGHT_SQR_BRACKET                                       { $$ = template("%s[%s]",$1,$3) ;}
                   | SY_LEFT_SQR_BRACKET error   					                                          { yyerror(SE"error declaring array\n");}
                   ;


simple_data_type   : KW_INTEGER                                                                                         { $$ = "int";    }
                   | KW_CHAR                                                                                            { $$ = "char"; 	 }
                   | KW_BOOLEAN                                                                                         { $$ = "int";   }
                   | KW_REAL                                                                                            { $$ = "double"; }
                   | DEF_TYPE										
                   ;



/********************************************* Variables *********************************************/


var_decl           : %empty                                                                                             { $$ = ""; } 
                   | KW_VAR var_decl_list SY_SEMICOLON                                                                  { $$ = $2; }
                 //   | KW_VAR var_decl_list error   {yyerror("var decl semicolon expected\n");} 
                   ;

var_decl_list      : var_list SY_COLON advanced_data_type                                                               { $$ = template("%s;",data_spread($3,$1,";"));}
                   | var_decl_list SY_SEMICOLON var_list SY_COLON advanced_data_type                                    { $$ = template("%s %s;",$1,data_spread($5,$3,";"));} //////////needs treatment
                   | var_list SY_COLON     									 	                  { yyerror("data type expected\n");}
                   ;



var_list           : IDENT                                                                                              { $$ = template("%s",$1);}
                   | var_list SY_COMMA IDENT                                                                            { $$ =template("%s,%s",$1,$3);}
                   ;



/********************************************* Procedures *********************************************/

subprogram         : procedure_header                                                                                   { $$ =$1;}
                   | function_header                                                                                    { $$ =$1;}
                   ;

subprogram_list    : %empty                                                                                             { $$="";}
                   | subprogram_list subprogram                                                                         { $$ = template("%s%s", $1,$2);}
                   ;


//procedure_header 
procedure_header   : KW_PROCEDURE IDENT SY_LEFT_BRACKET args_decl SY_RIGHT_BRACKET SY_SEMICOLON procedure_body          { $$ = template("void %s (%s){%s}\n",$2,$4,$7);}
			 | KW_PROCEDURE IDENT SY_LEFT_BRACKET args_decl SY_RIGHT_BRACKET error 						{ yyerror(SE"semicolon expected at the end of procedure declaration\n");} ;
			 | KW_PROCEDURE IDENT SY_LEFT_BRACKET args_decl  error 				 				{ yyerror(SE"')' expected at procedure declaration\n");} ;
			 | KW_PROCEDURE IDENT  error  						 				 		{ yyerror(SE"'(argumetns);' expected at procedure declaration\n");} ;
			 | KW_PROCEDURE error 								 				 		{ yyerror(SE"procedure declaration incomplete\n");} ;
//function_header  
function_header    : KW_FUNCTION IDENT SY_LEFT_BRACKET args_decl SY_RIGHT_BRACKET return_type SY_SEMICOLON function_body{ $$ = template("%s %s(%s){\n %s result; %s\n }\n",$6,$2,$4,$6,$8);}
			 | KW_FUNCTION IDENT SY_LEFT_BRACKET args_decl SY_RIGHT_BRACKET return_type error 				{ yyerror(SE"semicolon expected at funciton declaration\n");} ;
			 | KW_FUNCTION IDENT SY_LEFT_BRACKET args_decl  error 								{ yyerror(SE"')' expected at funciton declaration\n");} ;
			 | KW_FUNCTION IDENT  error 													{ yyerror(SE"'(argumetns);' expected at funciton declaration\n");} ;
			 | KW_FUNCTION error 														{ yyerror(SE"funciton declaration incomplete\n");} ;



//Arguments Declaration demanding argument names
args_decl          : %empty                                                                                             { $$ = "";}
                   | args_decl_list                                                                                     { $$ = $1;}
                   ;

args_decl_list     : var_list SY_COLON advanced_data_type                                                               { $$ = template("%s",data_spread($3,$1,","));}
                   | args_decl_list SY_SEMICOLON var_list SY_COLON advanced_data_type                                   { $$ = template("%s, %s",$1,data_spread($5,$3,","));} //////////needs treatment
                   | args_decl_list SY_SEMICOLON advanced_data_type                                                     { yyerror(SE" Argument Name Expected\n");}
                   | advanced_data_type                                                                                 { yyerror(SE" Argument Name Expected\n");}
                   ;

//Arguments Declaration List Excluding Anguments names and not demanding argument names
args_decl_excl     : %empty                                                                                             { $$ = "";}
                   | args_decl_excl_list                                                                                { $$ = $1;}
                   ;


args_decl_excl_list: var_list SY_COLON advanced_data_type                                                               { $$ = template("%s",data_spread($3,$1,","));}
                   | args_decl_excl_list SY_SEMICOLON var_list SY_COLON advanced_data_type                              { $$ = template("%s, %s",$1,data_spread($5,$3,","));} //////////needs treatment
                   | advanced_data_type                                                                                 { $$ = template("%s",data_spread($1,"",","));}
                   | args_decl_excl_list SY_SEMICOLON advanced_data_type                                                { $$ = template("%s, %s",$1,data_spread($3,"",","));} //////////needs treatment
                   ;



//TODO  put rules for error detection





return_type        : %empty                                                                                             { yyerror(SE"return type expected\n");}
                   | SY_COLON advanced_data_type                                                                        { $$ = template("%s",data_spread($2,"",""));};
                   ;


procedure_body     : var_decl subprogram_list complex_cmd SY_SEMICOLON                                                  { $$ = template("\n%s%s%s",$1,$2,$3);}
			 | var_decl subprogram_list complex_cmd error   														{ yyerror(SE"semicolon expected at end of procedure body\n");} ;
			 | var_decl subprogram_list  error 																	{ yyerror(SE"Complex command expected\n");}
			 ;

function_body    : var_decl subprogram_list func_complex_cmd SY_SEMICOLON                                             { $$ = template("\n%s%s%s",$1,$2,$3);}
		     | var_decl subprogram_list complex_cmd SY_SEMICOLON                                             		{ yyerror(SE"return expected\n");}
		     | var_decl subprogram_list  error 																	{ yyerror(SE"Complex command expected\n");}
		     | var_decl subprogram_list func_complex_cmd error   													{ yyerror(SE"semicolon expected at end of function body\n");} ;
		     ;



/********************************************* Commands *********************************************/

all_commands       : complex_cmd // Complex Comands or just a simple command
                   | simple_cmd 
                   ;

complex_cmd        : KW_BEGIN cmd_list KW_END                                                                           { $$ = template("\n%s\n",$2) ;}//Only complex commands "BEGIN foo END"
			 	  // | KW_BEGIN cmd_list error  		{ yyerror(SE" Keyword 'end' expected");}
			 ; 

func_complex_cmd   : KW_BEGIN cmd_list_wr cmd_list_ws KW_END									      { $$ = template("\n%s\n%s\n",$2,$3) ;} // when we have a funciton we expect a return


cmd_list_ws        : %empty {$$ = "";}
                   | SY_SEMICOLON cmd_list                                                                              { $$ = $2;}

cmd_list           : %empty                                                                                             { $$ = "";} //list of simple commands
                   | simple_cmd 																							
                   | cmd_list SY_SEMICOLON simple_cmd                                                                   { $$ = template("%s\n%s",$1,$3) ;}
                   //| error SY_SEMICOLON 		{ yyerror(SE"wrong command\n");}
                   ;

simple_cmd         : IDENT SY_ASSIGN expression                                                                         { $$ =template("%s=%s;",$1,$3);}	//assign_cmd
                   | IDENT matrix_n SY_ASSIGN expression                                                                { $$ =template("%s%s=%s;",$1,$2,$4);}
                   | KW_RESULT SY_ASSIGN expression                                                                     { $$ =template("result=%s;",$3);}
                   | if_cmd                                                                                             { $$ = $1;}
                   | for_cmd                                                                                            { $$ = $1;}
                   | while_cmd                                                                                          { $$ = template("%s;",$1);}
                   | IDENT SY_COLON all_commands                                                                        { $$ = template("%s: %s;",$1,$3);} //TODO does all_commands need brackets in labels ? // no but it accepts them
                   | KW_GOTO IDENT                                                                                      { $$ = template("goto %s;",$2);}
                   | IDENT SY_LEFT_BRACKET arglist                                                                      { $$ = template("%s(%s)\n;",$1,$3);}
                   | proc_call                                                                                          { $$ = template("%s;", $1); }
                   ;

cmd_list_wr        : KW_RETURN                                                                                          {$$ = "return result;";} //list of simple commands
                   | cmd_list SY_SEMICOLON KW_RETURN                                                                    {$$ = template("%s; return result;",$1 );}                                                                                                             
                   //| error SY_SEMICOLON             { yyerror(SE"wrong command\n");}
                   ;



/*Processes and functions call*/
proc_call          : IDENT SY_LEFT_BRACKET arguments SY_RIGHT_BRACKET                                                   { $$ = template("%s(%s)", $1, $3); } /* identifier (arguments)*/
			 ;

/*While Loop*/
while_cmd          : KW_WHILE expression KW_DO all_commands                                                             { $$ =template("while(%s){%s}",$2,$4);}
                   | KW_REPEAT all_commands KW_UNTIL expression                                                         { $$ =template("do{%s}\nwhile(%s)",$2,$4);}
                   | KW_WHILE expression  all_commands  																{ yyerror(SE"Keyword 'do' expected\n");}
                   //| KW_REPEAT error 																					{ yyerror(SE"error at repeat command\n");} 
                   ;

/*For Loop*/
for_cmd            : KW_FOR IDENT SY_ASSIGN expression KW_TO expression KW_DO all_commands                              { $$ =template("for(%s=%s; %s<=%s; %s++){\n\t%s\n}",$2,$4,$2,$6,$2,$8); }
                   | KW_FOR IDENT SY_ASSIGN expression KW_DOWNTO expression KW_DO all_commands                          { $$ =template("for(%s=%s; %s>=%s; %s--){\n\t%s\n}",$2,$4,$2,$6,$2,$8); }
                 //  | KW_FOR IDENT SY_ASSIGN expression KW_TO expression KW_DO 											{ yyerror(SE" complex_cmd expected\n");}
                   | KW_FOR IDENT SY_ASSIGN expression KW_TO expression all_commands 									{ yyerror(SE" Keyword 'DO' expected\n");}
                   | KW_FOR IDENT SY_ASSIGN expression KW_TO expression error											{ yyerror(SE" error at for loop\n");}
                   | KW_FOR IDENT SY_ASSIGN expression error  KW_DO all_commands 										{ yyerror(SE"Keyword 'TO' or 'DOWNTO' expected\n");}
                   | KW_FOR IDENT  expression KW_TO expression KW_DO all_commands 										{ yyerror(SE"Assign missing\n");}
                   | KW_FOR IDENT error expression KW_TO expression KW_DO all_commands 									{ yyerror(SE"Assignment error\n");}
                   | KW_FOR IDENT error {yyerror(SE"error at for loop\n");}
                   | KW_FOR  error {yyerror(SE"error at for loop\n");}
                   ;


if_cmd		 : KW_IF expression KW_THEN all_commands                                 				    			{ $$ = template("if(%s){\n\t%s}\n",$2,$4);}            
			 | KW_IF expression KW_THEN all_commands KW_ELSE all_commands                              			{ $$ = template("if(%s){\n\t%s}\nelse{\n%s}",$2,$4,$6);}
			 | KW_IF  error 																						{yyerror(SE"error at if statement\n");}
			 	  // | KW_IF expression KW_THEN all_commands KW_ELSE error  	{yyerror(SE"error at else statement\n");}
			 ;				   

%%


