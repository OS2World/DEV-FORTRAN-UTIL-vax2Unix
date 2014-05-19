%{
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <io.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <ctype.h>

#include "convert.h"
#include "userHeap.h"
#include "convertUtils.h"
#include "symbolManagement.h"

#define EXTERN
#include "externalVariables.h"

#define OLD_PROC 0

extern SYMBOL_LIST_CONTROL	globalCommon;
extern SYMBOL_LIST_CONTROL	procedureList;

/*	See the comments in setProcedureToken for an explanation of the
	nest three variables  */
static YACC_SYMBOL	*currentProcedureToken;
static int			procedureDeclarationPending;
static VARIABLE_DEFINITION			*pcurrentArgVar;

#define NP (void *)0
/* macro SAP - SetArithProperties */
#define SAP(a,b) a->arithType=b->arithType;a->arithSize=b->arithSize;
#define MAX_DO_NEST_LEVEL 50
/*  PAT means Propagate Arithmetic Type.  It is used to express
    the type of a result of an arithmetic operation.  */
	#define PAT(d,l,r) d->arithType = max (l->arithType, r->arithType); \
	        d->arithSize = max (l->arithSize, r->arithSize);


static void ignoreStatement (void);
static void	includeFromLibrary (char	*baseName);
static void initParser (void);
static int popDoLevel (void);
static void processBinaryOp (YACC_SYMBOL *l, YACC_SYMBOL *op, YACC_SYMBOL *r);
static void processUnaryOp (YACC_SYMBOL *op, YACC_SYMBOL *r);	
static void pushDoLevel (int statementNo);
static void setProcedureToken (YACC_SYMBOL *proc, YACC_SYMBOL *arg);
static void testAlternateReturn (YACC_SYMBOL *pys);
static void __yy_bcopy (char *from, char *to, int count);
void yyerror (char *msg);


static int	doNestLevel;
static int	doEndStack[MAX_DO_NEST_LEVEL];

FILE 		*errorFile;
char		*currentFileName;
static int			ifArgIsArithmetic;
static YACC_SYMBOL	*nonkeyRecordNumber;

void endOfStatementProc ( YACC_SYMBOL *topToken);
int			forlex (void);
int			yylex (void);
int			yyparse (void);
%}

%union	{
	YACC_SYMBOL		*ysym;
	int				intVal;
	}


%token <intVal> END_OF_STATEMENT IGNORE_THIS_TOKEN 
%token <ysym> INCLUDE_T FORMAT_STATEMENT PASS_STATEMENT_T OPEN_STATEMENT_T IO_STATEMENT
%token <ysym> PASS_TEXT EQUALS INTEGER_CONSTANT
%token <ysym> REAL_CONSTANT
%token <ysym> L_PAREN R_PAREN COMMENT_STATEMENT_OUT
%token <ysym> IF_STATEMENT IF_THEN_STATEMENT
%token <ysym> ENCODE_DECODE
%token <ysym> ELSE_IF_STATEMENT RELATIONAL_OP_T
%token <ysym> IF_ARGUEMENT THEN_T
%token <ysym> ELSE_STATEMENT
%token <ysym> STRING_START STRING_ELEMENT 
%token <ysym> END_OF_PROGRAM 
%token <ysym> BYTE_TYPE LOGICAL_TYPE INTEGER_TYPE REAL_TYPE DOUBLE_TYPE
%token <ysym> COMPLEX_TYPE DOUBLE_COMPLEX_TYPE CHARACTER_TYPE
%token <ysym> OPEN_PASS OPEN_DUMP
%token <ysym> DO_STATEMENT END_DO_STATEMENT END_IF_STATEMENT
%token <ysym> GOTO_STATEMENT COMPUTED_GOTO_STATEMENT
%token <ysym> COMMON_STATEMENT INTRINSIC_OR_EXTERN_STATEMENT
%token <ysym> VARIABLE_NAME
%token <ysym> IO_PARAM_NAME STAR UNIT_IDENT
%token <ysym> APOS QUOTE COLON 
%token <ysym> REFERENCE
%token <ysym> SPECIFICATION_COMPLETE
%right <ysym> CONCAT
%token <ysym> IMPLICIT_STATEMENT
%token <ysym> EQUIVALENCE_STATEMENT
%token <ysym> DIMENSION_STATEMENT
%token <ysym> FUNCTION SUBROUTINE NAMELIST PARAMETER DATA
%token <ysym> CALL
%token <ysym> CHAR DASH SLASH DOT
%token <ysym> GLOBAL_FUNCTION GLOBAL_SUBROUTINE GLOBAL_COMMON
%left <ysym> LOGICAL_OP
%right <ysym> LOGICAL_NOT
%left <ysym> ADD_OP
%left <ysym> MUL_OP 
%right <ysym> EXP_OP

%right <ysym> COMMA
 /* DO NOT PLACE ANY TOKEN DEFINITIONS AFTER THIS POINT */
%token <ysym> LAST_DEFINED_TOKEN

%type <ysym> pass_text io_statement open_statement
%type <ysym> fake_statement statement
%type <ysym> include_statement format_statement
%type <ysym> if_statement if_statement_start base_if if_arguement 
%type <ysym> else_statement logical_arguement
%type <ysym> pass_statement comment_statement_out
%type <ysym> open_arg open_arg2 open_dump open_pass 
%type <ysym> expression arg_list paren_ref
%type <ysym> string string_element substring
%type <ysym> io_control_list io_control_list_key io_control_list_nonkey
%type <ysym> io_param
%type <ysym> do_statement do_limit end_do_statement end_if_statement
%type <ysym> goto_statement computed_goto_statement
%type <ysym> common_statement common_block_list 
%type <ysym> common_item common_block_name common_item_list
%type <ysym> operation literal signed_integer
%type <ysym> implicit_statement 
%type <ysym> implicit_specifier_list implicit_specifier_item
%type <ysym> implicit_specifier_code_list implicit_specifier_code
%type <ysym> intrinsic_or_extern_statement
%type <ysym> equivalence_statement equivalence_list
%type <ysym> equivalence_group equivalence_item
%type <ysym> dimension_statement array_declarator array_list
%type <ysym> type_definition_statement
%type <ysym> dimension_list dimension_element dimension_atom
%type <ysym> base_type
%type <ysym> type_specifier 
%type <ysym> type_variable_list variable_list_element
%type <ysym> type_variable_item extended_type_variable_item
%type <ysym> function_statement variable_list
%type <ysym> base_function_spec base_function_name
%type <ysym> subroutine_statement
%type <ysym> namelist_statement namelist_list namelist_group
%type <ysym> parameter_statement parameter_list
%type <ysym> vax_parameter_list
%type <ysym> data_statement arithmetic_statement
%type <ysym> structure_ref
%type <ysym> encode_decode_statement encode_optional encode_optional2 format_spec
%type <ysym> value_list value_element value_atom
%type <ysym> variable_reference
%type <ysym> global_function_statement global_subroutine_statement
%type <ysym> global_common_statement global_common_list global_common_item
%type <ysym> global_call_spec global_arg_list global_arg_item

%%

fake_statement:	{ $$ = 0; }/* nothing */
	|fake_statement statement {$$ = $2; }

statement:	include_statement { endOfStatementProc ($1);}
	| format_statement {endOfStatementProc ($1); }
	| open_statement	{ endOfStatementProc ($1);}
	| encode_decode_statement { endOfStatementProc ($1); }
	| io_statement	{ endOfStatementProc ($1);}
	| pass_statement { endOfStatementProc ($1);}
	| if_statement	{endOfStatementProc ($1);}
	| else_statement	{ endOfStatementProc ($1); }
	| comment_statement_out { endOfStatementProc ($1);}
	| goto_statement {endOfStatementProc ($1); }
	| computed_goto_statement {endOfStatementProc ($1); }
	| common_statement {endOfStatementProc ($1); }
	| dimension_statement {endOfStatementProc ($1); }
	| implicit_statement {endOfStatementProc ($1); }
	| intrinsic_or_extern_statement {endOfStatementProc ($1);}
	| type_definition_statement {endOfStatementProc ($1); }
	| equivalence_statement {endOfStatementProc ($1); }
	| function_statement {endOfStatementProc ($1);  }
	| subroutine_statement { endOfStatementProc ($1);  }
	| namelist_statement { endOfStatementProc ($1);  }
	| parameter_statement {endOfStatementProc ($1);  }
	| data_statement {endOfStatementProc ($1);  }
	| arithmetic_statement {endOfStatementProc ($1);  }
	| global_function_statement {ignoreStatement (); }
	| global_subroutine_statement {ignoreStatement (); }
	| global_common_statement {ignoreStatement (); }
	| do_statement {
		++blockIndentLevel;
		endOfStatementProc ($1);}
	| end_do_statement {
		if (blockIndentLevel)
			--blockIndentLevel; 
		endOfStatementProc ($1);}
	| end_if_statement{
		if (blockIndentLevel)
			--blockIndentLevel; 
		endOfStatementProc ($1);}
	| END_OF_PROGRAM { /* END_OF_PROGRAM */
		if (procedureDeclarationPending)
			{defineProcedure (currentProcedureToken, pcurrentArgVar);
			procedureDeclarationPending = 0;
			}
 		compareCommonBlocks ();
		initLexer (); 
		initParser ();
		endOfStatementProc ($1)}
	| END_OF_STATEMENT {}
	| error END_OF_STATEMENT {fputs ("\n", yyout); fflush (yyout); }
	| SPECIFICATION_COMPLETE {
		if (procedureDeclarationPending)
			{defineProcedure (currentProcedureToken, pcurrentArgVar);
			procedureDeclarationPending = 0;
			}
		}
	;

global_function_statement: GLOBAL_FUNCTION VARIABLE_NAME STAR
	VARIABLE_NAME STAR signed_integer global_call_spec END_OF_STATEMENT
		{VARIABLE_DEFINITION	*pvd;
		
		$$ = $1;
		pvd = addProcedure ($2, 0);
		pvd->argumentOrCommonLink = (void *)($7->argListLink);
		pvd->type = ENVT_FUNCTION;
		pvd->arithType = $6->arithType;
		pvd->variableSize = $6->constantValue;
		}
	;
global_call_spec: L_PAREN R_PAREN
		{$$ = $1;
		$$->argListLink = 0;
		}
	| L_PAREN global_arg_list R_PAREN
		{$$ = $1; $$->argListLink = $2->argListLink;}
	;
global_arg_list: global_arg_item
	| global_arg_list COMMA global_arg_item
		{/* link the current item to the end of the list */
		ARGUMENT_DEFINITION		**ppa,
								*pa;
		
		$$ = $1;
		pa = (ARGUMENT_DEFINITION *) ($1->argListLink);
		ppa = &(pa);
		while (pa->next)
			pa = pa->next;
		pa->next = (ARGUMENT_DEFINITION *) ($3->argListLink);
		
		}
	;
global_arg_item: VARIABLE_NAME STAR signed_integer
		{ /* VARIABLE_NAME is the name of an arithmetic type eg, 
			INTEGER, REAL, etc.  signed_integer is the size of the variable
			*/
		
		ARGUMENT_DEFINITION		*parg;
	
		$$ = $1;
		parg = (ARGUMENT_DEFINITION *)allocProcedureMem (sizeof (ARGUMENT_DEFINITION) );
		$$->argListLink = (YACC_SYMBOL *) parg;
		memset ( (void *)parg, 0, sizeof (ARGUMENT_DEFINITION) );
		parg->storageClass |= ENSC_DUMMY_VARIABLE;
		parg->arithType = $1->arithType;
		parg->arithSize = $3->constantValue;
		}
	|global_arg_item COLON INTEGER_CONSTANT STAR INTEGER_CONSTANT
		{DIMENSION_DEFINITION	*pdd;
		DIMENSION_DEFINITION	*pdd2,
								*pdd3;
		ARGUMENT_DEFINITION		*parg;
		
		$$ = $1;
		/* The current argument is dimensioned - create a DIMENSION_DEFINITION */
		pdd = (DIMENSION_DEFINITION *) heapAlloc (&(procedureList.symbols),
				sizeof (DIMENSION_DEFINITION) );
		memset ( (void *)pdd, 0, sizeof (DIMENSION_DEFINITION) );
		pdd->size = $3->constantValue;
		pdd->lowerBound = $5->constantValue;
		parg = (ARGUMENT_DEFINITION *)($1->argListLink);
		/*	Link the new DIMENSION_DEFINITION to the end of the dimension
			list of the current argument */
		if (pdd2=parg->dimension)
			{while (pdd3 = (DIMENSION_DEFINITION *)(pdd2->nextDim) )
				pdd2 = pdd3;
			pdd2->nextDim = (DIMENSION_DEFINITION *)(pdd);
			}
		else
			parg->dimension = pdd;
		
		}
	;

signed_integer: INTEGER_CONSTANT
	| ADD_OP INTEGER_CONSTANT
		{ $$ = $1;
		processUnaryOp ($1, $2);
		}

global_subroutine_statement: GLOBAL_SUBROUTINE VARIABLE_NAME 
		global_call_spec END_OF_STATEMENT
		{VARIABLE_DEFINITION	*pvd;
		
		$$ = $1;
		pvd = addProcedure ($2, 0);
		pvd->argumentOrCommonLink = (void *) ($3->argListLink);
		pvd->type = ENVT_SUBROUTINE;
		}
	;

global_common_statement:GLOBAL_COMMON SLASH VARIABLE_NAME SLASH
		global_common_list END_OF_STATEMENT
		{$$ = $1;
		processGlobalCommonBlock ($3->token, $5);
		}
	| GLOBAL_COMMON SLASH SLASH global_common_list END_OF_STATEMENT
		{$$ = $1;
		processGlobalCommonBlock (0, $4);
		}
	;

global_common_list: global_common_item
	|global_common_list global_common_item
		{joinSymbols (&$$, $1, $2, NP); }
	;

global_common_item: VARIABLE_NAME STAR INTEGER_CONSTANT STAR INTEGER_CONSTANT
		{COMMON_REGION		*pcr;
		
		$$ = $1;
		pcr = (COMMON_REGION *)heapAlloc (&(globalCommon.symbols),
			sizeof (COMMON_REGION) );
		pcr->type = $1->arithType;
		pcr->variableSize = $3->constantValue;
		pcr->variableCount = $5->constantValue;
		pcr->next = 0;
		$1->argListLink = (YACC_SYMBOL *) pcr;
		}

pass_statement:	PASS_STATEMENT_T pass_text END_OF_STATEMENT
	{joinSymbols (&$$, $1, $2, NP);  }
	| PASS_STATEMENT_T END_OF_STATEMENT { }
	;



if_statement: base_if INTEGER_CONSTANT COMMA INTEGER_CONSTANT COMMA INTEGER_CONSTANT END_OF_STATEMENT
		{joinSymbols (&$$, $1, $2, $3, $4, $5, $6, NP);
		}
	|base_if THEN_T END_OF_STATEMENT
		{
		joinSymbols (&$$, $1, $2, NP);
		if ($$->number != ELSE_IF_STATEMENT)
			{$$->number = IF_THEN_STATEMENT;
			++blockIndentLevel;
			}
		makeLogicalIf ($1, ifArgIsArithmetic);
		}
	|base_if pass_text END_OF_STATEMENT
		{
		joinSymbols (&$$, $1, $2, NP);
		makeLogicalIf ($1, ifArgIsArithmetic);
		}
	;

base_if: if_statement_start if_arguement R_PAREN
		{ ifArgIsArithmetic = 1;
		joinSymbols (&$$, $1, $2, $3, NP);
		}
	|if_statement_start logical_arguement R_PAREN
		{ ifArgIsArithmetic = 0;
		joinSymbols (&$$, $1, $2, $3, NP);
		}
	;

if_statement_start: IF_STATEMENT
	| ELSE_IF_STATEMENT
	;

logical_arguement: if_arguement RELATIONAL_OP_T if_arguement
		{joinSymbols (&$$, $1, $2, $3,  NP); }
	| logical_arguement RELATIONAL_OP_T if_arguement
		{joinSymbols (&$$, $1, $2, $3,  NP); }
	;

if_arguement: IF_ARGUEMENT
	| string
	| if_arguement string
		{joinSymbols (&$$, $1, $2, NP); }
	| if_arguement IF_ARGUEMENT
		{joinSymbols (&$$, $1, $2, NP); }
	;

else_statement: ELSE_STATEMENT END_OF_STATEMENT

comment_statement_out: COMMENT_STATEMENT_OUT END_OF_STATEMENT
	| COMMENT_STATEMENT_OUT pass_text END_OF_STATEMENT
		{joinSymbols (&$$, $1, $2, NP); }
	;

open_statement:	OPEN_STATEMENT_T open_arg2 R_PAREN END_OF_STATEMENT
		{ /* forming open statement */
		joinSymbols (&$$, $1, $2, $3, NP);  }
	;

open_arg2:	open_arg	
open_arg:	open_pass
		{ $$ = $1}
	| INTEGER_CONSTANT
		{ $$ = $1}
	| open_dump
		{ $$ = $1;	$$->tokenSize = 0;}
	| open_arg COMMA open_pass
		{joinSymbols (&$$, $1, $2, $3, NP);}
	| open_arg COMMA INTEGER_CONSTANT
		{joinSymbols (&$$, $1, $2, $3, NP);}
	| open_arg COMMA open_dump
	;
	
open_dump:	OPEN_DUMP pass_text
	| OPEN_DUMP
	;

open_pass:	OPEN_PASS pass_text
		{ joinSymbols (&$$, $1, $2, NP);}
	| OPEN_PASS pass_text QUOTE
		{joinSymbols (&$$, $1, $2, $3, NP); }
	| OPEN_PASS
	;

encode_decode_statement: ENCODE_DECODE L_PAREN expression COMMA 
	format_spec COMMA encode_optional R_PAREN pass_text END_OF_STATEMENT
		{	/* encode_decode_statement */
		joinSymbols (&$$, $1, $2, $3, $4, $5, $6, $7, $8, $9, NP); }
	| ENCODE_DECODE L_PAREN expression COMMA
	format_spec COMMA encode_optional R_PAREN END_OF_STATEMENT
		{ joinSymbols (&$$, $1, $2, $3, $4, $5, $6, $7, $8, NP); }
	;

format_spec: INTEGER_CONSTANT
	| VARIABLE_NAME

encode_optional: encode_optional2
	| encode_optional COMMA VARIABLE_NAME EQUALS VARIABLE_NAME
		{joinSymbols (&$$, $1, $2, $3, $4, $5, NP); }
	| encode_optional COMMA VARIABLE_NAME EQUALS INTEGER_CONSTANT
		{joinSymbols (&$$, $1, $2, $3, $4, $5, NP); }
	;

encode_optional2: VARIABLE_NAME
	| paren_ref
	| substring
	;

io_statement:	io_control_list END_OF_STATEMENT
	|io_control_list pass_text END_OF_STATEMENT
		{joinSymbols (&$$, $1, $2, NP);}
	;

io_control_list: io_control_list_nonkey R_PAREN
		{if (nonkeyRecordNumber)
			{YACC_SYMBOL	*pys;
			
			pys = createToken (", REC = ");
			joinSymbols (&$$, $1, pys, nonkeyRecordNumber, $2, NP);
			nonkeyRecordNumber = 0;
			}
		else
			joinSymbols (&$$, $1, $2, NP); }
	| io_control_list_key R_PAREN
		{joinSymbols (&$$, $1, $2, NP); }
	;

io_control_list_nonkey: IO_STATEMENT expression
		{nonkeyRecordNumber = 0;
		joinSymbols (&$$, $1, $2, NP);
		}
	| IO_STATEMENT MUL_OP
		{joinSymbols (&$$, $1, $2, NP); }
	| io_control_list_nonkey COMMA MUL_OP
		{joinSymbols (&$$, $1, $2, $3, NP); }
	| IO_STATEMENT expression APOS expression
		{nonkeyRecordNumber = $4;
		joinSymbols (&$$, $1, $2, NP);
		}
	| io_control_list_nonkey COMMA expression
		{joinSymbols (&$$, $1, $2, $3, NP); }
	;

io_control_list_key: IO_STATEMENT io_param
		{ joinSymbols (&$$, $1, $2, NP);
		nonkeyRecordNumber = 0;
		}
	| io_control_list_key COMMA io_param
		{joinSymbols (&$$, $1, $2, $3, NP); }
	|io_control_list_nonkey COMMA io_param
		{joinSymbols (&$$, $1, $2, $3, NP) ;}
	;

io_param: IO_PARAM_NAME EQUALS pass_text
		{joinSymbols (&$$, $1, $2, $3, NP); }
	| IO_PARAM_NAME EQUALS string
		{joinSymbols (&$$, $1, $2, $3, NP); }
	;

include_statement:	INCLUDE_T L_PAREN PASS_TEXT R_PAREN QUOTE END_OF_STATEMENT
		{  /* Include a module in default text library  */
		YACC_SYMBOL				*dotI;
		char			*pc;
	
		if (dollarInFileName ($3))
			{$1->number = COMMENT_STATEMENT_OUT;
			joinSymbols (&$$, $1, $3, $5, NP);
			}
		else
			{dotI = createToken (".i");
			dotI->statementCharNo = $4->statementCharNo;
			dotI->printWithNextToken = 1;
			strlwr ($3->token);
			joinSymbols (&$$, $1, $3, dotI, $5, NP);
			includeFromLibrary ($3->token);
			}
		}
	| INCLUDE_T pass_text L_PAREN PASS_TEXT R_PAREN QUOTE END_OF_STATEMENT
		{  /* Include a module from a specified library */
		
		YACC_SYMBOL				*dotI;
		char			*pc;
	
		if (dollarInFileName ($4))
			{$1->number = COMMENT_STATEMENT_OUT;
			joinSymbols (&$$, $1, $4, $6, NP);
			}
		else
			{dotI = createToken (".i");
			dotI->statementCharNo = $5->statementCharNo;
			strcpy (dotI->token, ".i");
			strlwr ($4->token);
			joinSymbols (&$$, $1, $4, dotI, $6, NP);
			includeFromLibrary ($4->token);
			}
		}
	| INCLUDE_T PASS_TEXT QUOTE END_OF_STATEMENT
		{  /* include a file */

		if (dollarInFileName ($2))
			{$1->number = COMMENT_STATEMENT_OUT;
			}
		else
			{if ( !strcmp ("forioerr.i", $2->token) )
				forioerrIncluded = 1;
			strlwr ($2->token);
			pushFile ($2->token);
			}
		joinSymbols (&$$, $1, $2, $3, NP);
		}
	;
format_statement: FORMAT_STATEMENT pass_text END_OF_STATEMENT
	{joinSymbols (&$$, $1, $2, NP); }

do_statement: DO_STATEMENT do_limit pass_text END_OF_STATEMENT
		{
		pushDoLevel (atoi ($2->token));
		joinSymbols (&$$, $1, $2, $3, NP);
		}
	| DO_STATEMENT pass_text END_OF_STATEMENT
		{joinSymbols (&$$, $1, $2, NP);}
	;

do_limit: INTEGER_CONSTANT
	|INTEGER_CONSTANT COMMA
	;

end_do_statement: END_DO_STATEMENT END_OF_STATEMENT
	|END_DO_STATEMENT pass_text END_OF_STATEMENT
	;

end_if_statement: END_IF_STATEMENT END_OF_STATEMENT
	| END_IF_STATEMENT pass_text END_OF_STATEMENT
	;


pass_text:	PASS_TEXT
	| pass_text PASS_TEXT	{ joinSymbols (&$$, $1, $2, NP); }
	;

arg_list:	expression {/* arg_list */ $$ = $1; 
		testAlternateReturn ($1);}
	| arg_list COMMA expression  {
		joinSymbols (&$$, $1, $2, $3, NP);
		LAL($1, $3, NP);
		}
	| arg_list COMMA COMMA {
		joinSymbols (&$$, $1, $2, $3, NP);
		LAL($1, (YACC_SYMBOL *) 1, (YACC_SYMBOL *)1, NP);
		}
	| arg_list COMMA COMMA expression {
		LAL ($1, (YACC_SYMBOL *) 1, $4, NP);
		testAlternateReturn ($4);
		joinSymbols (&$$, $1, $2, $3, $4, NP);
		}
	| COMMA COMMA {
		joinSymbols (&$$, $1, $2, NP);
		LAL($1, (YACC_SYMBOL *) 1, (YACC_SYMBOL *) 1, NP);
		}
	| COMMA COMMA expression
		{joinSymbols (&$$, $1, $2, $3, NP);
		testAlternateReturn ($3);
		LAL($1, (YACC_SYMBOL *) 1, (YACC_SYMBOL *) 1, $3, NP);
		}
	;
	
variable_reference: REFERENCE L_PAREN expression R_PAREN
		{
		int		newV;
		if ($3->arithType == ENAT_CHAR)
			{joinSymbols (&$$, $1, $2, $3, $4, NP);
			$1->arithType = $3->arithType;
			$1->arithSize = $3->arithSize;}
		else
			$$ = $3;
		}
	;

paren_ref: VARIABLE_NAME L_PAREN arg_list R_PAREN 
		{ /* paren_ref */
		joinSymbols (&$$, $1, $2, $3, $4, NP);
		processParenRef ($1, $3);
		}
	| VARIABLE_NAME L_PAREN R_PAREN
		{joinSymbols (&$$, $1, $2, $3, NP);
		processParenRef ($1, 0);
		}
	| VARIABLE_NAME L_PAREN COMMA arg_list R_PAREN
		{YACC_SYMBOL	*py;
		
		py = createToken ("");
		py->number = MISSING_ARG;
		joinSymbols (&$$, $1, $2, $3, $4, $5, NP);
		LAL(py, (YACC_SYMBOL *)1, $4, NP);
		processParenRef ($1, py);
		}
	| VARIABLE_NAME L_PAREN COMMA arg_list COMMA R_PAREN
		{YACC_SYMBOL	*py;
		
		py = createToken ("");
		py->number = MISSING_ARG;
		joinSymbols (&$$, $1, $2, $3, $4, $5, $6, NP);
		LAL(py, $4, (YACC_SYMBOL *) 1, NP);
		processParenRef ($1, py);
		}
	| VARIABLE_NAME L_PAREN arg_list COMMA R_PAREN
		{YACC_SYMBOL	*py;
		
		py = createToken ("");
		py->number = MISSING_ARG;
		joinSymbols (&$$, $1, $2, $3, $4, $5, NP);
		LAL($3, (YACC_SYMBOL *) 1, NP);
		processParenRef ($1, $3);
		}
	;
	
expression: VARIABLE_NAME { /* expression */
	int		newVar;
	
	$$ = $1;
	processLocalSymbol ($1, &newVar);}
	| paren_ref
	| operation VARIABLE_NAME {
		int		newVar;
		SAP ($1, $2)
		processLocalSymbol ($2, &newVar);
		processUnaryOp ($1, $2);
		joinSymbols (&$$, $1, $2, NP); }
	| operation paren_ref {
		SAP ($1, $2)
		processUnaryOp ($1, $2);
		joinSymbols (&$$, $1, $2, NP);}
	| operation literal {
		SAP ($1, $2)
		processUnaryOp ($1, $2);
		joinSymbols (&$$, $1, $2, NP);  }
	| operation L_PAREN expression R_PAREN	{
		SAP ($1, $3)
		processUnaryOp ($1, $3);
		joinSymbols (&$$, $1, $2, $3, $4, NP); }
	| L_PAREN expression R_PAREN  {
		SAP ($1, $3)
		$1->constantValue = $2->constantValue;
		joinSymbols (&$$, $1, $2, $3, NP);  }
	| expression ADD_OP expression  {
		processBinaryOp ($1, $2, $3);
		joinSymbols (&$$, $1, $2, $3, NP);  }
	| expression MUL_OP expression  {
		processBinaryOp ($1, $2, $3);
		joinSymbols (&$$, $1, $2, $3, NP);  }
	| expression LOGICAL_OP expression
		{ joinSymbols (&$$, $1, $2, $3, NP); }
	| LOGICAL_NOT expression {joinSymbols (&$$, $1, $2, NP); }
	| expression EXP_OP expression  {
		processBinaryOp ($1, $2, $3);
		joinSymbols (&$$, $1, $2, $3, NP);  }
	| expression CONCAT expression  {joinSymbols (&$$, $1, $2, $3, NP);  }
	| structure_ref
	| literal
	| variable_reference
	;

structure_ref: VARIABLE_NAME DOT VARIABLE_NAME {
		joinSymbols (&$$, $1, $2, $3, NP);  }
	| structure_ref DOT VARIABLE_NAME {
		joinSymbols (&$$, $1, $2, $3, NP);  }
	| paren_ref DOT VARIABLE_NAME {
		joinSymbols (&$$, $1, $2, $3, NP);}
	| paren_ref DOT paren_ref
		{joinSymbols (&$$, $1, $2, $3, NP); }
	| VARIABLE_NAME DOT paren_ref
		{joinSymbols (&$$, $1, $2, $3, NP); }

operation: ADD_OP
	| MUL_OP
	| SLASH
	| STAR
	| EXP_OP
	| CONCAT
	;

string: STRING_START string_element APOS
		{$1->arithSize += $2->arithSize;
		$1->arithType = ENAT_CHAR;
		joinSymbols (&$$, $1, $2, $3, NP);
		}
	|STRING_START APOS
		{$1->arithType = ENAT_CHAR;
		joinSymbols (&$$, $1, $2, NP);
		}
	| substring
		{$$ = $1;
		$1->arithType = ENAT_CHAR;
		}
	;

string_element: STRING_ELEMENT
	| string_element STRING_ELEMENT
		{$1->arithSize += $2->arithSize;
		joinSymbols (&$$, $1, $2, NP);
		}
	;

substring:	VARIABLE_NAME L_PAREN expression COLON expression R_PAREN
		{$1->arithSize = $3->arithSize + $5->arithSize;
		joinSymbols (&$$, $1, $2, $3, $4, $5, $6, NP);}
	| VARIABLE_NAME L_PAREN COLON expression R_PAREN
		{joinSymbols (&$$, $1, $2, $3, $4, $5, NP);}
	| VARIABLE_NAME L_PAREN expression COLON R_PAREN
		{joinSymbols (&$$, $1, $2, $3, $4, $5, NP);}
	| paren_ref L_PAREN expression COLON expression R_PAREN
		{$1->arithSize = $3->arithSize + $5->arithSize;
		joinSymbols (&$$, $1, $2, $3, $4, $5, $6, NP);}
	| paren_ref L_PAREN COLON expression R_PAREN
		{joinSymbols (&$$, $1, $2, $3, $4, $5, NP);}
	| paren_ref L_PAREN expression COLON R_PAREN
		{joinSymbols (&$$, $1, $2, $3, $4, $5, NP);}
	;
	

literal:	INTEGER_CONSTANT 
		{ /* literal: INTEGER_CONSTANT */ $$=$1; }
	| string
	| REAL_CONSTANT
	;

computed_goto_statement: COMPUTED_GOTO_STATEMENT pass_text END_OF_STATEMENT
	{joinSymbols (&$$, $1, $2, NP);
	}
	;

base_type: BYTE_TYPE {
		$$ = $1;
		$1->arithType = ENAT_BYTE;
		}
	| LOGICAL_TYPE {
		$$ = $1;
		$1->arithType = ENAT_LOGICAL;
		}
	| INTEGER_TYPE {
		$$ = $1;
		$1->arithType = ENAT_INT;
		}
	| REAL_TYPE {
		$$ = $1;
		$1->arithType = ENAT_REAL;
		}
	| DOUBLE_TYPE {
		$$ = $1;
		$1->arithType = ENAT_DOUBLE;
		}
	| COMPLEX_TYPE {
		$$ = $1;
		$1->arithType = ENAT_COMPLEX;
		}
	| DOUBLE_COMPLEX_TYPE {
		$$ = $1;
		$1->arithType = ENAT_DOUBLE_COMPLEX;
		}
	| CHARACTER_TYPE {
		$$ = $1;
		$1->arithType = ENAT_CHAR;
		}
	;

goto_statement: GOTO_STATEMENT END_OF_STATEMENT
	;

implicit_statement: IMPLICIT_STATEMENT implicit_specifier_list END_OF_STATEMENT
		{joinSymbols (&$$, $1, $2, NP); }
	;

implicit_specifier_list: implicit_specifier_item
	| implicit_specifier_list COMMA implicit_specifier_item
		{joinSymbols (&$$, $1, $2, $3, NP);  }
	;

implicit_specifier_item: type_specifier L_PAREN implicit_specifier_code_list R_PAREN
		{int			first,
						last;
		YACC_SYMBOL		*ps;
		VARIABLE_TYPE	vt;

		vt.type = $1->arithType;
		vt.size = $1->arithSize;
		for (ps=$3;	ps;	ps=ps->argListLink)
			{first = (ps->constantValue)>>8;
			last = (ps->constantValue) & 0xff;
			if (first)
				implicitRangeAssign (implicitType, &vt, first, last);
			else
				implicitLetterAssign (implicitType, &vt, last);
			applyImplicit ();
			if ( ! (currentProcedureToken->storageClass & ENSC_EXPLICIT_TYPE) )
				{currentProcedureToken->arithType = vt.type;
				currentProcedureToken->arithSize = vt.size;
				}
			}
		joinSymbols (&$$, $1, $2, $3, $4, NP); 
		}
	;

implicit_specifier_code_list: implicit_specifier_code
	| implicit_specifier_code COMMA implicit_specifier_code
		{LAL ($1, $3, NP);
		joinSymbols (&$$, $1, $2, $3, NP); }
	;

implicit_specifier_code: CHAR {
		$$ = $1;
		$1->constantValue = tolower (*($1->token));
		}
	|CHAR DASH CHAR {int l=tolower(*($1->token)), h=tolower (*($3->token)),c=l<<8+h;
		$1->constantValue = ( (tolower(*($1->token)))<<8)+tolower (*($3->token));
		joinSymbols (&$$, $1, $2, $3, NP); }
	;

intrinsic_or_extern_statement: INTRINSIC_OR_EXTERN_STATEMENT 
		variable_list END_OF_STATEMENT
	{joinSymbols (&$$, $1, $2, NP); }

type_specifier: base_type
		{$$ = $1;
		$1->arithSize = defaultVariableSize ($1->arithType);
		}
	| base_type STAR INTEGER_CONSTANT
		{$1->arithSize = atoi ($3->token);
		joinSymbols (&$$, $1, $2, $3, NP); }
	| base_type STAR L_PAREN expression R_PAREN
		{joinSymbols (&$$, $1, $2, $3, $4, $5, NP);
		$1->arithSize = $4->constantValue;
		}
	| base_type STAR L_PAREN STAR R_PAREN
		{joinSymbols (&$$, $1, $2, $3, $4, $5, NP);
		$1->arithSize = CONFORMING_SIZE;
		}
	;

equivalence_statement: EQUIVALENCE_STATEMENT equivalence_list END_OF_STATEMENT
		{/* EQUIVALENCE*/joinSymbols (&$$, $1, $2, NP) ;}
	| EQUIVALENCE_STATEMENT COMMA equivalence_list END_OF_STATEMENT
		{joinSymbols (&$$, $1, $2, $3, NP);}
	;

equivalence_list: L_PAREN equivalence_group R_PAREN
		{joinSymbols (&$$, $1, $2, $3, NP); }
	|equivalence_list COMMA L_PAREN equivalence_group R_PAREN
		{joinSymbols (&$$, $1, $2, $3, $4, $5, NP); }
	;
equivalence_group: equivalence_item
	| equivalence_group COMMA equivalence_item 
		{joinSymbols (&$$, $1, $2, $3, NP);}
	;

equivalence_item: VARIABLE_NAME
	| array_declarator
	;

dimension_statement: DIMENSION_STATEMENT array_list END_OF_STATEMENT
	{/*DIMENSION*/joinSymbols (&$$, $1, $2, NP); }
	;

array_list: array_declarator
	|array_list COMMA array_declarator
		{joinSymbols (&$$, $1, $2, $3, NP); }
	;

array_declarator: VARIABLE_NAME L_PAREN dimension_list R_PAREN 
	{int		newVar;
	VARIABLE_DEFINITION		*pv;
	
	/* array_declarator */
	pv = processLocalSymbol ($1, &newVar);
	pv->type = ENVT_DIMENSIONED_VAR;
	pv->dimension = $3->dimensionLink;
	joinSymbols (&$$, $1, $2, $3, $4, NP); }
	;

dimension_list: dimension_element
	|dimension_list COMMA dimension_element
		{DIMENSION_DEFINITION	**ppd,
								*pd;
		YACC_SYMBOL				*first, *next;
		first=$1; next=$3;		/* for debugging only */
	/* Link dimension_element to the end of dimension_list */
		for (ppd=&($1->dimensionLink), pd=$1->dimensionLink;	pd;	)
			{
			ppd=(DIMENSION_DEFINITION **)(&(pd->nextDim));
			pd = (DIMENSION_DEFINITION *)(pd->nextDim);
			}
		(*ppd) = (DIMENSION_DEFINITION *)($3->dimensionLink);
		joinSymbols (&$$, $1, $2, $3, NP);
 		 }
	;

dimension_element: dimension_atom
		{	/* dimension_element */
		$$ = $1;
		$1->dimensionLink = defineSimpleDimension ($1->constantValue);}
	| dimension_atom COLON dimension_atom
		{$1->dimensionLink = defineComplexDimension ($1->constantValue,
			$3->constantValue);
		joinSymbols (&$$, $1, $2, $3, NP);  }
	;

dimension_atom: INTEGER_CONSTANT
	| VARIABLE_NAME
		{$$ = $1;
		getParameterValue ($1);
		}
	| dimension_atom operation INTEGER_CONSTANT
		{processBinaryOp ($1, $2, $3);
		joinSymbols (&$$, $1, $2, $3, NP);  }
	| dimension_atom operation VARIABLE_NAME
		{getParameterValue ($3);
		processBinaryOp ($1, $2, $3);
		joinSymbols (&$$, $1, $2, $3, NP);  }
	| ADD_OP INTEGER_CONSTANT
		{processUnaryOp ($1, $2);
		joinSymbols (&$$, $1, $2, NP)
		}
	| ADD_OP VARIABLE_NAME
		{getParameterValue ($2);
		processUnaryOp ($1, $2);
		joinSymbols (&$$, $1, $2, NP)
		}
	;

type_definition_statement: type_specifier type_variable_list END_OF_STATEMENT
	{/* type_definition_statement
		note that the followint types are used in type_definition_statement:
			type_variable_list extended_type_variable_item type_variable_item
	*/
	processTypeList ($2, $1);
	joinSymbols (&$$, $1, $2, NP);
	}
	;

type_variable_list: extended_type_variable_item
	| type_variable_list COMMA extended_type_variable_item
		{/*type_variable_list*/joinSymbols (&$$, $1, $2, $3, NP);  }
	;

extended_type_variable_item: type_variable_item
	|type_variable_item SLASH value_list SLASH
		{joinSymbols (&$$, $1, $2, $3, $4, NP);  }


type_variable_item: VARIABLE_NAME
	| array_declarator
	| array_declarator STAR INTEGER_CONSTANT
		{$1->arithSize = $3->constantValue;
		joinSymbols (&$$, $1, $2, $3, NP);
		}
	| VARIABLE_NAME STAR INTEGER_CONSTANT
		{
		$1->arithSize = atoi ($3->token);
		joinSymbols (&$$, $1, $2, $3, NP);  }
	| VARIABLE_NAME STAR L_PAREN expression R_PAREN
		{joinSymbols (&$$, $1, $2, $3, $4, $5, NP);
		$1->arithSize = $4->constantValue;
		}
	| VARIABLE_NAME STAR L_PAREN STAR R_PAREN
		{joinSymbols (&$$, $1, $2, $3, $4, $5, NP);
		$1->arithSize = CONFORMING_SIZE;
		}
	;

value_list: value_element
	| value_list COMMA value_element
		{joinSymbols (&$$, $1, $2, $3, NP); }
	;

value_element: value_atom
	| value_atom STAR value_atom
		{joinSymbols (&$$, $1, $2, $3, NP); }
	;

value_atom: VARIABLE_NAME
	| INTEGER_CONSTANT
	| REAL_CONSTANT
	| string
	;


common_statement: COMMON_STATEMENT common_block_list END_OF_STATEMENT
		{joinSymbols (&$$, $1, $2, NP);  
		processCommonList ($2);
		}
	| COMMON_STATEMENT common_item_list common_block_list END_OF_STATEMENT
		{joinSymbols (&$$, $1, $2, $3, NP);  
		processCommonList ($2);
		processCommonList ($3);
		}

common_block_name:	SLASH VARIABLE_NAME SLASH common_item
		{joinSymbols (&$$, $1, $2, $3, $4, NP);  }
	| SLASH SLASH common_item
		{joinSymbols (&$$, $1, $2, $3, NP);  }
	;

common_block_list: common_block_name
	| common_block_list common_block_name
		{joinSymbols (&$$, $1, $2, NP);  }
	| common_block_list COMMA common_block_name
		{joinSymbols (&$$, $1, $2, $3, NP);  }
	| common_block_list COMMA common_item
		{joinSymbols (&$$, $1, $2, $3, NP);  }
	;

common_item: VARIABLE_NAME
	| array_declarator
	;

common_item_list: common_item
	| common_item_list COMMA common_item
		{joinSymbols (&$$, $1, $2, $3, NP); }

function_statement: FUNCTION base_function_spec END_OF_STATEMENT
		{VARIABLE_TYPE		*vt;
		
		vt = &(implicitType[tolower(*($2->token)) - 'a']);
		$2->arithType = vt->type;
		if ( !$2->arithSize)
			$2->arithSize = vt->size;
		currentProcedureToken->arithType = $2->arithType;
		currentProcedureToken->arithSize = $2->arithSize;
		joinSymbols (&$$, $1, $2, NP);  }
	| type_specifier FUNCTION base_function_spec END_OF_STATEMENT
		{$3->arithType = $1->arithType;
		if ( !$3->arithSize)
			$3->arithSize = $1->arithSize;
		$3->storageClass |= ENSC_EXPLICIT_TYPE;
		currentProcedureToken->storageClass = $3->storageClass;
		currentProcedureToken->arithType = $3->arithType;
		currentProcedureToken->arithSize = $3->arithSize;
		joinSymbols (&$$, $1, $2, $3, NP);  }
	;

base_function_spec: base_function_name
		{$$ = $1;
		$1->variableType = ENVT_FUNCTION;
		setProcedureToken ($1,0 );
		}
	| base_function_name L_PAREN variable_list R_PAREN
		{$1->argListLink = $3;
		$1->variableType = ENVT_FUNCTION;
		setProcedureToken ($1, $3);
		joinSymbols (&$$, $1, $2, $3, $4, NP);  }
	| base_function_name L_PAREN R_PAREN
		{
		$1->variableType = ENVT_FUNCTION;
		setProcedureToken ($1, 0);
		joinSymbols (&$$, $1, $2, $3, NP);  }
	;

base_function_name:	VARIABLE_NAME
	| VARIABLE_NAME STAR INTEGER_CONSTANT
		{$1->arithSize = atoi ($3->token);
		$1->storageClass |= ENSC_EXPLICIT_TYPE;
		joinSymbols (&$$, $1, $2, $3, NP);  }
	| VARIABLE_NAME STAR L_PAREN STAR R_PAREN
		{$1->arithSize = CONFORMING_SIZE;
		$1->storageClass |= ENSC_EXPLICIT_TYPE;
		joinSymbols (&$$, $1, $2, $3, $4,$5, NP); }
	;

variable_list: variable_list_element
	| variable_list COMMA variable_list_element
		{LAL ($1, $3, NP);
		joinSymbols (&$$, $1, $2, $3, NP);  }
	;

variable_list_element: VARIABLE_NAME
		{int		newVar;
		
		$$ = $1;
		processLocalSymbol ($1, &newVar);
		}
	| STAR
		{$$ = $1; 
		$1->arithType = ENAT_ALTERNATE_RETURN;
		$1->storageClass |= ENSC_EXPLICIT_TYPE}
	| paren_ref
	| structure_ref

subroutine_statement: SUBROUTINE VARIABLE_NAME L_PAREN variable_list R_PAREN
		END_OF_STATEMENT
		{ /* subroutine_statement  */
		VARIABLE_DEFINITION		*pv;
		
		$2->variableType = ENVT_SUBROUTINE;
		
		setProcedureToken ($2, $4);
		
		joinSymbols (&$$, $1, $2, $3, $4, $5, NP);  }
	| SUBROUTINE VARIABLE_NAME END_OF_STATEMENT
		{
		VARIABLE_DEFINITION		*pv;
		$2->variableType = ENVT_SUBROUTINE;
		setProcedureToken ($2, 0);
		joinSymbols (&$$, $1, $2, NP); }
	| SUBROUTINE VARIABLE_NAME L_PAREN R_PAREN END_OF_STATEMENT
		{
		VARIABLE_DEFINITION		*pv;
		$2->variableType = ENVT_SUBROUTINE;
		setProcedureToken ($2, 0);
		joinSymbols (&$$, $1, $2, $3, $4, NP); }
	;

namelist_statement: NAMELIST namelist_list END_OF_STATEMENT
		{ /* namelist_statement */
		joinSymbols (&$$, $1, $2, NP);  }
	;

namelist_list: namelist_group VARIABLE_NAME
		{joinSymbols (&$$, $1, $2, NP);  }
	| namelist_list COMMA VARIABLE_NAME
		{joinSymbols (&$$, $1, $2, NP);  }
	| namelist_list namelist_group VARIABLE_NAME
		{joinSymbols (&$$, $1, $2, $3, NP);  }
	| namelist_list COMMA namelist_group VARIABLE_NAME
		{joinSymbols (&$$, $1, $2, $3, $4, NP);  }
	;

namelist_group: SLASH VARIABLE_NAME SLASH
	;

parameter_statement: PARAMETER vax_parameter_list END_OF_STATEMENT
		{joinSymbols (&$$, $1, $2, NP);
/*		processParameterList ($1, 0);*/
		}
	| PARAMETER L_PAREN parameter_list R_PAREN END_OF_STATEMENT
		{joinSymbols (&$$, $1, $2, $3, $4, NP);
/*		processParameterList ($1, 1); */
		}
	;

parameter_list: VARIABLE_NAME EQUALS expression
		{joinSymbols (&$$, $1, $2, $3, NP);
		$1->storageClass |= ENSC_PARAMETER;
		processParameterItem ($1, $3, 1);  }
	| parameter_list COMMA VARIABLE_NAME EQUALS expression
		{joinSymbols (&$$, $1, $2, $3, $4, $5, NP);
		$3->storageClass |= ENSC_PARAMETER;
		processParameterItem ($3, $5, 1);  }
	;

vax_parameter_list: VARIABLE_NAME EQUALS expression
		{  /* vax_parameter_list */ joinSymbols (&$$, $1, $2, $3, NP);
		$1->storageClass |= ENSC_PARAMETER;
		processParameterItem ($1, $3, 0);
		  }
	| vax_parameter_list COMMA VARIABLE_NAME EQUALS expression
		{joinSymbols (&$$, $1, $2, $3, $4, $5, NP);
		$3->storageClass |= ENSC_PARAMETER;
		processParameterItem ($3, $5, 0);
		}
	;

arithmetic_statement: VARIABLE_NAME EQUALS expression END_OF_STATEMENT
		{joinSymbols (&$$, $1, $2, $3, NP);  }
	| substring EQUALS expression END_OF_STATEMENT
		{joinSymbols (&$$, $1, $2, $3, NP); }
	| paren_ref EQUALS expression END_OF_STATEMENT
		{joinSymbols (&$$, $1, $2, $3, NP);  }
	| CALL paren_ref END_OF_STATEMENT
		{joinSymbols (&$$, $1, $2, NP);  }
	| CALL VARIABLE_NAME END_OF_STATEMENT
		{VARIABLE_DEFINITION	*pv;
		
		pv = processParenRef ($2, 0);
		pv->type = ENVT_SUBROUTINE;
		joinSymbols (&$$, $1, $2, NP); }
	| structure_ref EQUALS expression END_OF_STATEMENT {
		 joinSymbols (&$$, $1, $2, $3, NP); }
	;

data_statement:  DATA pass_text END_OF_STATEMENT
		{
	/*	This version of the DATA statement is probably all that is required.
		I include the first form because I was almost finished with the 
		description when I realized it is probably not needed.  I leave the
		first form in the grammer just in case it might be helpful
		some time.  In any event, it is not executed as long as the lexer
		only generates PASS_TEXT tokens after seeing a DATA statement */
		joinSymbols (&$$, $1, $2, NP);  
		}

%%

/*	|DATA data_specification END_OF_STATEMENT
		{ joinSymbols (&$$, $1, NP);  }
	;

data_specification: data_item_list data_value_list
	| data_specification data_item_list data_value_list
	| data_specification COMMA data_item_list data_value_list
	;

data_item_list: data_element
	|data_element COMMA data_element
	;

data_element: VARIABLE_NAME
	| VARIABLE_NAME L_PAREN dimension_list R_PAREN
	| data_implied_do
	;

data_implied_do: L_PAREN data_item_list COMMA VARIABLE_NAME EQUALS
		VARIABLE_NAME COMMA VARIABLE_NAME R_PAREN
	| L_PAREN data_item_list COMMA VARIABLE_NAME EQUALS VARIABLE_NAME
		COMMA VARIABLE_NAME COMMA VARIABLE_NAME R_PAREN
	;


data_value_list: DATA_VALUE
	{ $$ = $1;
	}
	;
*/

/* ***************************** checkArgs ********************** */
static int checkArgs (char **ppch)
{char		*pch;


pch = *ppch;
if ( !strcmp (pch, "-D") )
	{yydebug = 1;
	return 1;
	}
if ( !strcmp (pch, "-G") )
	{generateGlobalData = 1;
	return 1;
	}
if ( !strcmp (pch, "-M") )
	{generateMakeDependencies = 1;
	makeDependencyFile = fopen ("makeDependencyFile", "w");
	return 1;
	}
if ( !strncmp (pch, "-I", 2))
	{int			retVal;
	
	retVal = 1;
	pch += 2;
	if ( !*pch)
		{pch = *(ppch+1);
		retVal = 2;
		}
	addIncludeSegment (pch);
	return retVal;
	}
if ( !strncmp ("-T", pch, 2) )
	{if ( !stricmp ("vax", pch+2) )
		{targetSystem = ENTS_VAX;
		littleEndian = 1;
		return 1;
		}
	}
return 0;
}

/* *************************** endOfStatementProc ********************* */
void endOfStatementProc ( YACC_SYMBOL *topToken)
{
/* subtle trap:  if the ending statement of a do loop is an enddo 
	then blockIndentLevel will be decremented twice
*/
if (doNestLevel && (currentStatementNo == doEndStack[doNestLevel-1]) )
	{--doNestLevel;
 	if (topToken->number != END_DO_STATEMENT)
		--blockIndentLevel;
	}
printStatement (topToken, currentStatementNo, yyout);
lexerEndOfStatementProc ();
heapFree (&tokenHeap, 0);
heapFree (&commentHeap, 0);
return;
}

/* ***************************** ignoreStatement ************************* */
static void ignoreStatement (void)
{
lexerEndOfStatementProc ();
heapFree (&tokenHeap, 0);
heapFree (&commentHeap, 0);
return;

}

/* **************************** includeFromLibrary ******************* */
static void includeFromLibrary (char *baseName)
{
char		name[250];

strcpy (name, baseName);
strcat (name, ".i");
pushFile (name);
}

/* ****************************** initializeVariable ********************** */
void    initializeVariable (VARIABLE_DEFINITION *pv)
{
int	i;
pv->type = ENVT_SCALAR;
i = tolower (*(pv->name) ) - 'a';
pv->arithType = implicitType[i].type;
pv->variableSize = implicitType[i].size;
pv->dimension = 0;
pv->commonOffset = -1;
pv->argumentOrCommonLink = 0;
pv->commonLink = 0;
return;
}

/* ****************************** initParser ***************************** */
static void initParser (void)
{
VARIABLE_TYPE	defaultInt = {ENAT_INT,4},
				defaultReal = {ENAT_REAL, 4};

heapInit (&commentHeap, COMMENT_DATA_SIZE, commentData);
heapInit (&tokenHeap, TOKEN_DATA_SIZE, tokenData);
implicitRangeAssign (implicitType, &defaultReal, 'a', 'z');
implicitRangeAssign (implicitType, &defaultInt, 'i', 'n');
dependencyCharsOnCurrentLine = 0;
resetLocalSymbols ( );
currentProcedureVar = 0;
procedureDeclarationPending = 0;
return;
}

/* ****************************** yyerror **************************** */
void yyerror (char *msg)
{
char		buff[150];


lexerErrorProc ();
sprintf (buff, "%s; %s on  line %d \n", currentFileName, msg, lineNo);
printf (buff);
fprintf (errorFile, buff);
return;
}

/* ******************************* yylex **************************** */
/* This beastie is supplied as an intermediate layer between the parser and
   the real lexer.  Certain items in the source file such as comment lines
   are handled by the lexer.  After this item is processed, the desire is
   to return yylex ().  However, this could cause a stack overflow if the
   source file had a great many consecutive comment lines.  The solution
   I have found is to have the lexer return IGNORE_THIS_TOKEN after 
   processing a comment.  When my version of yylex sees this return value
   it immediately calls forlex.
*/
int yylex (void)
{static int	retVal;
static int		END_OF_STATEMENT_returned;
static int		inputIsComplete;

if (inputIsComplete)
	{inputIsComplete = 0;
	return 0;
	}
/* Must force excatly one END_OF_STATEMENT return when end of file 
	is reached */
if (EOFRead)
	{EOFRead = 0;
	if ( !includeDepth)
		inhibitOutput = 0;
	else
		inhibitOutput = 1;
	return retVal;
	}
if (filePushed)
	{filePushed = 0;
	inhibitOutput = 1;
	}

l4:

retVal = forlex ();
if ( !retVal)
	{if (END_OF_STATEMENT_returned)
		{inputIsComplete = 0;
		return 0;
		}
	inputIsComplete = 1;
	END_OF_STATEMENT_returned = 1;
	return END_OF_STATEMENT;
	}
if (retVal == END_OF_STATEMENT)
	END_OF_STATEMENT_returned = 1;
else
	END_OF_STATEMENT_returned = 0;

if ( EOFRead)
	{
	return END_OF_STATEMENT;
	}
if (IGNORE_THIS_TOKEN == retVal)
	goto l4;
return retVal;
}

/* ****************************** popDoLevel ************************ *\
static int popDoLevel (void)
static void pushDoLevel (int statementNo)
{
if ( !doNestLevel--)
	{printf ("do nest stack underflow\n");
	exit (1);
	}
return doEndStack[doNestLevel];
}

/* ****************************** processBinaryOp ************************ */
static void processBinaryOp (YACC_SYMBOL *l, YACC_SYMBOL *op, YACC_SYMBOL *r)
{
if ( (l->arithType != ENAT_INT) || (r->arithType != ENAT_INT) )
	return;
if (op->number == ADD_OP)
	{if (strchr (op->token, '+'))
		l->constantValue += r->constantValue;
	else
		l->constantValue -= r->constantValue;
	}
else if (op->number == MUL_OP)
	{if (strchr (op->token, '*'))
		l->constantValue *= r->constantValue;
	else
		{if (r->constantValue)
			l->constantValue /= r->constantValue;
		}
	}
else if (op->number == EXP_OP)
	{long		x;
	int			i;
	
	for (x=1, i=0;	i<r->constantValue;	++i)
		x *= r->constantValue;
	}
l->arithSize = max (l->arithSize, r->arithSize);
return;
}

/* ****************************** processUnaryOp ************************ */
static void processUnaryOp (YACC_SYMBOL *op, YACC_SYMBOL *r)
{

if ( (op->number != ADD_OP) || (r->arithType != ENAT_INT) )
	return;
	{if ( strchr (op->token, '+'))
		op->constantValue = r->constantValue;
	else
		op->constantValue = -r->constantValue;
	}
op->arithType = r->arithType;
op->arithSize = r->arithSize;
return;
}

/* ****************************** pushDoLevel ************************ */
static void pushDoLevel (int statementNo)
{
if (doNestLevel >= MAX_DO_NEST_LEVEL)
	{printf ("do nest stack overflow\n");
	exit (1);
	}
doEndStack[doNestLevel++] = statementNo;
return;
}

/* ****************************** setProcedureToken *********************** */
static void setProcedureToken (YACC_SYMBOL *proc, YACC_SYMBOL *arg)

/*	Porcessing explicit procedure definitions (i.e. resulting from a SUBROUTINE
	or a FUNCTION statement) can cause a spurious error message if the 
	procedure has been defined previously.  This results from the fact that
	IMPLICIT and type definition statements which follow the defining statement
	can change the type of the formal arguments.  So is the parser defines the
	procedure immediately after the end of the defining statement, the types and
	sizes of the formal arguments may not agree with previous usage.

	One solution to this problem would be to defer processing the defining
	statement until all type declarations are processed, and then perform
	normal procedure processing.  However, the normal processing requires the
	use of YACC_TOKEN s, and these structures do not persist across statements..

	My solution is to copy the procedure's YACC_SYMBOL to a static structure, 
	then to form a linked list of the VARIABLE_DEFINITION s which correspond
	to the formal arguments of the procedure.  The field constantValue in each
	VARIABLE_DEFINITION is set to the index of the variable in the procesure's
	formal parameter list.  The storageClass is set to ENSC_DUMMY_VARIABLE,
	Finally, a flag is set which will
	cause the parser to define the procedure when type specification statments
	have all been processed.
*/

{
VARIABLE_DEFINITION		**nextLink,
						*currentVar;
YACC_SYMBOL				*currentTok;
int						newVar,
						varIndex;

if ( !arg)
	{pcurrentArgVar = 0;
	goto l4;
	}
nextLink = &pcurrentArgVar;
for (currentTok = arg, varIndex=0;	currentTok;	
		currentTok = currentTok->argListLink, ++varIndex)
	{currentVar = processLocalSymbol (currentTok, &newVar);
	currentVar->constantValue = varIndex;
	currentVar->storageClass |= ENSC_DUMMY_VARIABLE;
	*nextLink = currentVar;
	nextLink = (VARIABLE_DEFINITION **)(&(currentVar->argumentOrCommonLink));
	}
currentVar->argumentOrCommonLink = 0;

l4:

memcpy ((void *)currentProcedureToken, (void *)proc, sizeof (YACC_SYMBOL) + 100);
procedureDeclarationPending = 1;

}

/* **************************** testAlternateReturn *********************** */
static void testAlternateReturn (YACC_SYMBOL *pys)
{
if ( *(pys->token)=='*' && (pys->next) && (pys->next->number==INTEGER_CONSTANT) )
	{pys->arithSize = 0;
	pys->arithType = ENAT_ALTERNATE_RETURN;
	}
return;
}


/* ****************************** unknownFileType ************************* */
static void unknownFileType (char *name)
{
printf ("%s is not a recognized file type\n", name);
return;
}

static char	currentFile[255];

/* ******************************* main ******************************** */
int main (int argc, char **argv)
{
char		*newExtent,
			**parg,
			*pch,
			*pch2;
int			baseLength,
			directoryNameLength,
			i;
char		*outputFileName;
char		*errorFileName;
FILE		*sourceNames;

initAllSymbols ();
currentProcedureToken = (YACC_SYMBOL *) malloc (sizeof(YACC_SYMBOL)+100);
yydebug = 0;
if (argc <2)
	{
	printf ("usage: vax2unix file\n	file is the FORTRAN file to convert\n");
	exit (1);
	}
parg = argv + 1;
while (i=checkArgs (parg))
	parg += i;
processIncludeEnvironment ();
if (**parg == '@')
	{
	sourceNames = fopen (*parg+1, "r");
	if ( !sourceNames )
		{printf ("Can't open indirect file\n");
		exit (1);
		}
	}
else sourceNames = 0;

l4:

if ( !sourceNames)
	strcpy (currentFile, *parg);
else
	{

l6:

	pch = fgets (currentFile, 255, sourceNames);
	if (pch)
		{if (*pch == ';')
			goto l6;
	/* ignore the newline char */
		currentFile[strlen(currentFile)-1] = 0;
		}
	else
		goto l10;
	}
if (currentSourceDir)
	{free ( (void *) currentSourceDir);
	currentSourceDir = 0;
	}
for (pch = currentFile;	pch;	)
	{pch2 = pch;
	pch = strpbrk (pch2+1, "\\/");
	}
directoryNameLength = pch2 - currentFile;
if (directoryNameLength++)
	{currentSourceDir = (char *) malloc (directoryNameLength + 1);
	strncpy (currentSourceDir, currentFile, directoryNameLength);
	*(currentSourceDir+directoryNameLength) = 0;
	}
else
	currentSourceDir = 0;
pch = strrchr (currentFile, '.');
baseLength = pch-currentFile;
if ( !pch)
	{unknownFileType (currentFileName);
	goto l8;
	}
newExtent = 0;
if ( !strnicmp (pch, ".INC", 4) )
	newExtent = ".i";
else if ( !strnicmp (pch, ".FOR", 4) )
	newExtent = ".f";
if ( !newExtent)
	{unknownFileType (currentFile);
	goto l8;
	}
yyin = fopen (currentFile, "r");
if ( !yyin)
	{printf ("Open failure on source\n");
	exit (1);
	}
currentFileName = (char *) malloc (strlen (currentFile));
strcpy (currentFileName, currentFile);
lineNo = 1;
outputFileName = (char *) malloc (baseLength + 3);
errorFileName = (char *) malloc (baseLength + 5);
strncpy (outputFileName, currentFileName, baseLength);
strcpy (outputFileName+baseLength, newExtent);
strncpy (errorFileName, currentFileName, baseLength);
strcpy (errorFileName+baseLength, ".err");
yyout = fopen (outputFileName, "wb");
errorFile = fopen (errorFileName, "w");
if (makeDependencyFile)
	fprintf (makeDependencyFile, "\n");

initLexer ();
initParser ();
yyparse ();

free ( (void *) outputFileName);
free ( (void *) errorFileName);
forioerrIncluded = 0;
fclose (yyin);
fclose (yyout);
fclose (errorFile);

l8:
if (sourceNames)
	goto l4;
++parg;
if (*parg)
	goto l4;

l10:

if (makeDependencyFile)
	fclose (makeDependencyFile);
if (generateGlobalData)
	writeGlobals ();
return 0;
}
