%{
#define YY_DECL int forlex (void)
#define MAX_INCLUDE_DEPTH	10
#include <stdlib.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <string.h>
#include <ctype.h>
#if defined (__IBMC__)
#include <io.h>
#endif

#define YY_USER_ACTION initializeToken ();
/* #define YY_USER_INIT	initLexer() */

#include "convert.h"
#include "parser.h"
#include "userHeap.h"
#include "convertUtils.h"
#include "symbolManagement.h"
#define MAX_STATE_DEPTH 20

#define EXTERN extern
#define INITIALIZE_EXTERNALS
#include "externalVariables.h"
	
typedef struct _FILE_INFO
    	{YY_BUFFER_STATE    bufferState;
	    int                 currentLineNo;
	    char                *fileName;
	    }   FILE_INFO;

typedef struct _INCLUDE_SEGMENT
	{struct _INCLUDE_SEGMENT	*next;
	char						name[1];
	} INCLUDE_SEGMENT;

static INCLUDE_SEGMENT	*includeDirectories;
static FILE_INFO    includeStack[MAX_INCLUDE_DEPTH];

/* Always return to this state when returning
   an END_OF_STATEMENT token
*/
static int		endStatementRevertState;
static int		currentState;
static int		structureNestDepth;

/* The following variable is used to define the meaning of an
	apostrophe in an io control list */
static int	apostropheSemanticsLevel;

static int		stateStack[MAX_STATE_DEPTH];
static int		stateDepth;

static char	*currentLineErrorMsg = NULL;

int binaryToI (char *pch);
static void convertOctal (void);
int	decimalToI (char *pch);
static int octalToI (char *pch);
int	hexToI (char *pch);
static int newLine (void);
static void popState (void);
static void popNStates (int count);
static void printError (char *msg);
static void processComment (EN_COMMENT_TYPE type);
static void pushState (int newState);
static int returnEOS (void);
static void revertToState (int desiredState);
static void swallowEOL (void);


%}

%x reading_string reading_string_next_line
%x reading_pass_through reading_error_text
%x reading_next_line reading_next_line2
%x processing_open 
%x io_statement io_statement2 io_control_key io_control_nonkey io_param
%x skip_to_end_of_module
%s encode_decode
%x reading_structure reading_structure2 reading_structure3
%s implicit_statement common_statement equivalence_statement
%s dimension_statement
%s intrinsic_or_external
%s function_statement
%s pass_until_slash

 /* The Next 3 start conditions are related.  Whenever the lexer is in state
	detailed_type_spec, one of the states transition_to_initialize_program 
	or accept_type_statement must be at the top of the state stack.  
	These states are structured this way in order to allow the processing
	which is done by detailed_type_spec to be shared by subroutine statements,
	type definition statements and statement function definitions
 */
%s detailed_type_spec 
%x transition_to_initialize_program 

%s processing_if1 processing_if2 
%s initialize_module initialize_program program_body 
%s parse_file_option
%s processing_include
%s do_statement
%s reading_file_spec passing_file_open_option
%s arith_statement
%s ip_pb_common
%s global_definition

ALPHA_CHAR	[_a-zA-Z]
COMMENT_LINE ^[cd!*].*
CONTINUATION_INDICATOR ^(\t[1-9])|([ ]{5}[^0 \n\t])
DIRECTORY_NAME_CHAR {ALPHA_CHAR}|{NUMERIC_CHAR}|[./]
FILE_NAME_CHAR {ALPHA_CHAR}|{NUMERIC_CHAR}|[.$]
FIXED_POINT_CONSTANT ({INTEGER_CONSTANT}\.{INTEGER_CONSTANT}*)|(\.{INTEGER_CONSTANT})
HEX_CHAR [a-f]|[A-F]|[0-9]
INTEGER_CONSTANT {NUMERIC_CHAR}+
REAL_CONSTANT ({INTEGER_CONSTANT}|{FIXED_POINT_CONSTANT})[DE][+-]?{INTEGER_CONSTANT}
NUMERIC_CHAR [0-9]
OCTAL_CHAR [0-7]
RELATIONAL_OP \.((LT)|(LE)|(EQ)|(NE)|(GT)|(GE))\.
STATEMENT_NUMBER1 ^({NUMERIC_CHAR}{1,5})|([ ]{NUMERIC_CHAR}{1,4})|([ ]{2}{NUMERIC_CHAR}{1,3})
STATEMENT_NUMBER2 ^(([ ]{3}{NUMERIC_CHAR}{1,2})|([ ]{4}{NUMERIC_CHAR}))
STRING_SEGMENT ((\'\')|([^'\n]))+
TYPE_DEFINITION (BYTE)|(LOGICAL)|(INTEGER)|(REAL)|(DOUBLE{WHITE}*PRECISION)|(COMPLEX)|(CHARACTER)
VARIABLE_NAME_CHAR [$_A-Z0-9]
VARIABLE_NAME {ALPHA_CHAR}{VARIABLE_NAME_CHAR}*
SLASH {WHITE}*\/{WHITE}*
WHITE [ 	]
ADD_OP {WHITE}*[+-]{WHITE}*
MUL_OP {WHITE}*[/\*]{WHITE}*
EXP_OP {WHITE}*\*\*{WHITE}*
CONCAT {WHITE}*\/\/{WHITE}*
COMMA {WHITE}*\,{WHITE}*
COLON {WHITE}*:{WHITE}*
STAR {WHITE}*\*{WHITE}*
APOS {WHITE}*\'{WHITE}*
DOT {WHITE}*\.{WHITE}*
L_PAREN {WHITE}*\({WHITE}*
R_PAREN {WHITE}*\){WHITE}*
EQUALS {WHITE}*={WHITE}*
IP_P_T1 {WHITE}*((IMPLICIT{WHITE}*NONE)|(PROGRAM)|(DICTIONARY)){WHITE}*
IP_P_T2 {WHITE}*((RECORD)|(SAVE)){WHITE}*
IP_P_T3 {WHITE}*((BLOCK{WHITE}*DATA)|(VOLATILE)|(DATA)){WHITE}*
IP_PB_COMMON NAMELIST|FORMAT|ENTRY
PB_P_T1 {WHITE}*((DATA)|(ACCEPT)|(ASSIGN)|(BACKSPACE)){WHITE}*
PB_P_T2 {WHITE}*((CLOSE)|(CONTINUE)|(DELETE)){WHITE}*
PB_P_T3 {WHITE}*((ENDFILE)|(FIND)|(GO{WHITE}*TO)|(INQUIRE)){WHITE}*
PB_P_T4 {WHITE}*((PAUSE)|(PRINT)|(RETURN)|(REWIND)|(REWRITE)|(STOP)|(TYPE)|(UNLOCK)){WHITE}*

%%

\n	return newLine ();
{WHITE}* return retIgnore ();
{WHITE}*!.*	{processComment (ENCT_END_OF_LINE); return retIgnore (); }

<reading_string>
	{  /* reading_string  */
	/* This state is probably not useful in its current form.  I include
		it to show my thoughts so far on how to proces strings  */
	{STRING_SEGMENT}	{
			{ currentSymbol->printWithNextToken = 1;
			currentSymbol->arithSize = yyleng;
			return returnTok (STRING_ELEMENT);}
		}
	\n {++lineNo; pushState (reading_string_next_line); return retIgnore (); }
	'	{popState (); return returnTok (APOS); }
	}  /*  reading_string  */

<reading_string_next_line>
	{	/* reading_string_next_line */
	{CONTINUATION_INDICATOR} {popState (); return retIgnore (); }
	{COMMENT_LINE} {processComment (ENCT_COMMENT_LINE); swallowEOL (); return retIgnore (); }
	}	/* reading_string_next_line */

<reading_pass_through>
	{  /* reading_pass_through  */
	.*	{
		pushState (reading_next_line);
		swallowEOL ();
		return returnTok (PASS_TEXT);
		}
	\n	{return newLine (); }
	}  /*  reading_pass_through  */

<reading_error_text>
	{  /* reading_error_text  */
	.*	{fputs (yytext, yyout);
		fflush (yyout);
		pushState (reading_next_line);
		swallowEOL ();
		return returnTok (PASS_TEXT);
		}
	\n	{return newLine (); }
	}  /*  reading_error_text  */

<reading_next_line>
	{	/* reading_next_line */
	\f.* return retIgnore ();
	{WHITE}*\n	{
		yyless (yyleng-1);
		swallowEOL ();
		processComment (ENCT_BLANK_LINE);
		return retIgnore ();}
	{CONTINUATION_INDICATOR}{WHITE}* {
		popState ();
			return retIgnore ();
		}
		{WHITE}*!.* { processComment (ENCT_COMMENT_LINE);
		swallowEOL ();
		return retIgnore ();
		}
	{COMMENT_LINE}	{
		processComment(ENCT_COMMENT_LINE);
		swallowEOL();
		return retIgnore ();}
	{WHITE}*	{
		retIgnore ();}
	{STATEMENT_NUMBER2}	|
	{STATEMENT_NUMBER1}	{
		nextStatementNo = atoi (yytext);
		return retIgnore ();}
	^{WHITE}*END{WHITE}*\n |
	(INCLUDE)|(CDEC)	{
		yyless (0);
		returnEOS ();		/* note we just call it - not return it */
		pushState (reading_next_line2);
		nextStatementNo = 0;
		return END_OF_STATEMENT;}
	.	{
		yyless (0); 
		return returnEOS ( ); }
		
	}		/* reading_next_line */
<reading_next_line2>
	{	/*	reading_next_line2.  This state exists to enable the
			lexer to return an END_OF_STATEMENT then process statements
			that are allowable in all parts of a program. */
	(CDEC)	{
		popState ();
		pushState (reading_pass_through);
		returnTok (COMMENT_STATEMENT_OUT);	}
	(INCLUDE){WHITE}*\'	{
		popState ();
		*(currentSymbol->token+yyleng-1) = '"';
		currentSymbol->printWithNextToken = 1;
		pushState (processing_include);
		pushState (reading_file_spec);
		return returnTok (INCLUDE_T);
		}
	{WHITE}*END{WHITE}*\n	{
		popState ();
		++lineNo;
		return returnTok (END_OF_PROGRAM);
		}
	}	/* reading_next_line2 */

<processing_include>
	{	/* processing_include  */
	\/((NO[LIST]*)|(LIST))	return retIgnore ();
	{FILE_NAME_CHAR}*	{
		return returnTok (PASS_TEXT); /* module within a text archive */
		}
	\' {currentSymbol->token[0] = '\"';
		popState (); return (QUOTE);  }
	\( return returnTok (L_PAREN);
	\) return returnTok (R_PAREN);
	. {yyless (0); popState (); return retIgnore (); }
	}	/* processing_include  */

<reading_file_spec>
	{	/* reading_file_spec */
	\'	{popState (); currentSymbol->token[0] = '"'; 
		return returnTok (QUOTE);}
	. 	{yyless(0); popState (); return retIgnore ();}
	{FILE_NAME_CHAR}*:: return retIgnore ();	/* Ignore node */
	{FILE_NAME_CHAR}+: return retIgnore ();		/* Ignore device */
	\[{FILE_NAME_CHAR}+\] {						/* Patch directory name */
		*(currentSymbol->token) = '/'; *(currentSymbol->token + yyleng-1) = '/';
		currentSymbol->printWithNextToken = 1;
		return returnTok (PASS_TEXT);
		}
	{FILE_NAME_CHAR}+ {
		currentSymbol->printWithNextToken = 1;
		return returnTok (PASS_TEXT);
		}
	;[0-9]* return retIgnore ();				/* Ignore version */
	}	/* readng_file_spec */

<transition_to_initialize_program>
	{	/* transition_to_initialize_program */
	.*	{popNStates (2); pushState (initialize_program); 
		endStatementRevertState = initialize_program;
		return returnTok (PASS_TEXT);
		}	
	}

<initialize_module>
	{	/* initialize_module */
	OPTIONS {
		pushState (reading_pass_through);
		return returnTok (COMMENT_STATEMENT_OUT);
		}
	{STAR}	{
		yyless (0);
		pushState (global_definition);
		return retIgnore ();
		}
	.	{
		yyless (0);
		popState ( );
		pushState (initialize_program);
		endStatementRevertState = initialize_program;
		return retIgnore ();
		}
	}

<initialize_program>
	{	/* initialize_program */
	{IP_PB_COMMON}	{
		yyless (0);
		pushState (ip_pb_common);
		return retIgnore ();
		}
	STRUCTURE {
		structureNestDepth = 1;
		pushState (reading_structure); 
		pushState (reading_structure3);
		return returnTok (PASS_STATEMENT_T);
		}
	FUNCTION{WHITE}* {pushState (function_statement); return returnTok (FUNCTION); }
	SUBROUTINE{WHITE}* {pushState (function_statement); return returnTok (SUBROUTINE); }
	LOGICAL{WHITE}*	{
		pushState (detailed_type_spec); return returnTok (LOGICAL_TYPE);
		}
	BYTE{WHITE}*	{
		pushState (detailed_type_spec);return returnTok (BYTE_TYPE);
		}
	INTEGER{WHITE}*	{
		pushState (detailed_type_spec);return returnTok (INTEGER_TYPE);
		}	
	REAL{WHITE}*	{
		pushState (detailed_type_spec);return returnTok (REAL_TYPE);
		}
	DOUBLE{WHITE}*PRECISION{WHITE}*	{
		pushState (detailed_type_spec);return returnTok (DOUBLE_TYPE);
		}
	COMPLEX{WHITE}*	{
		pushState (detailed_type_spec);return returnTok (COMPLEX_TYPE);
		}
	DOUBLE{WHITE}*COMPLEX{WHITE}*	{
		pushState (detailed_type_spec);return returnTok (DOUBLE_COMPLEX_TYPE);
		}
	CHARACTER{WHITE}*	{
		pushState (detailed_type_spec); return returnTok (CHARACTER_TYPE);
		}
	IMPLICIT{WHITE}* {
		pushState (implicit_statement); 
		return returnTok (IMPLICIT_STATEMENT);
		}
	COMMON{WHITE}*	{pushState (common_statement); return returnTok (COMMON_STATEMENT); }
	{IP_P_T1}|{IP_P_T2}|{IP_P_T3}	{
		pushState (reading_pass_through);
		return returnTok (PASS_STATEMENT_T); }
	EQUIVALENCE{WHITE}* {
		pushState (common_statement);
		return returnTok (EQUIVALENCE_STATEMENT);
		}
	DIMENSION{WHITE}* {
		pushState (dimension_statement); 
		return returnTok (DIMENSION_STATEMENT); }
	.	{
		if (generateGlobalData)
			{while (includeDepth)
				popFile ();
			pushState (skip_to_end_of_module);
			return IGNORE_THIS_TOKEN;
			}
		yyless (0);
		popState ( );
		pushState (program_body);
		endStatementRevertState = program_body;
		retIgnore ();
		return SPECIFICATION_COMPLETE;
		}
	PARAMETER{WHITE}* {pushState (arith_statement); return returnTok (PARAMETER); }
	((EXTERNAL)|(INTRINSIC)){WHITE}+ {
		pushState (intrinsic_or_external);
		return returnTok (INTRINSIC_OR_EXTERN_STATEMENT);
		}
	((FUNCTION)|(SUBROUTINE)){WHITE}*[=(] {
		if (generateGlobalData)
			{while (includeDepth)
				popFile ();
			pushState (skip_to_end_of_module);
			return IGNORE_THIS_TOKEN;
			}
		yyless (0);
		popState ( );
		pushState (program_body);
		endStatementRevertState = program_body;
		retIgnore ();
		return SPECIFICATION_COMPLETE;
		}
	{VARIABLE_NAME} {
		if (generateGlobalData)
			{while (includeDepth)
				popFile ();
			pushState (skip_to_end_of_module);
			return IGNORE_THIS_TOKEN;
			}
		yyless (0);
		popState ( );
		pushState (program_body);
		endStatementRevertState = program_body;
		retIgnore ();
		return SPECIFICATION_COMPLETE;
		}
	}	/* initialize_program */

<skip_to_end_of_module>
	{	/* skip_to_end_of_module */
	{WHITE}*END{WHITE}*\n	{
		popState ();
		++lineNo;
		return returnTok (END_OF_PROGRAM);
		}
	.*\n {heapFree (&tokenHeap, 0 ); return IGNORE_THIS_TOKEN; }
	}	/* skip_to_end_of_module */

<global_definition>
	{	/* global_definition */
	{STAR}FUNCTION {return returnTok (GLOBAL_FUNCTION); }
	{STAR}SUBROUTINE { return returnTok (GLOBAL_SUBROUTINE);}
	{STAR}COMMON {return returnTok (GLOBAL_COMMON); }
	BYTE { currentSymbol->arithType = ENAT_BYTE; 
		return returnTok (VARIABLE_NAME);}
	INTEGER {currentSymbol->arithType = ENAT_INT; 
		return returnTok (VARIABLE_NAME);}
	REAL {currentSymbol->arithType = ENAT_REAL; 
		return returnTok (VARIABLE_NAME);}
	DOUBLEPRECISION {currentSymbol->arithType = ENAT_DOUBLE; 
		return returnTok (VARIABLE_NAME);}
	DOUBLECOMPLEX {currentSymbol->arithType = ENAT_DOUBLE_COMPLEX; 
		return returnTok (VARIABLE_NAME);}
	CHAR {currentSymbol->arithType = ENAT_CHAR; 
		return returnTok (VARIABLE_NAME);}
	LOGICAL {currentSymbol->arithType = ENAT_LOGICAL; 
		return returnTok (VARIABLE_NAME);}
	{INTEGER_CONSTANT} {currentSymbol->constantValue = atoi(currentSymbol->token);
		currentSymbol->arithType = ENAT_INT;
		return returnTok (INTEGER_CONSTANT); }
	{STAR} { return returnTok (STAR);}
	{COLON} {return returnTok (COLON); }
	{ADD_OP} {return returnTok (ADD_OP); }
	{VARIABLE_NAME} {return returnTok (VARIABLE_NAME); }
	{L_PAREN} {return returnTok (L_PAREN); }
	{R_PAREN} {return returnTok (R_PAREN); }
	{COMMA} {return returnTok (COMMA); }
	{SLASH} {return returnTok (SLASH); }
	
	}	/* global_definition */

<reading_structure>
	{	/* reading_structure  
	Here it is:  The requirement here is to read statements and pass
	them through to the parser until the enclosing
			END STRUCTURE 
	statement is encountered.  Until then Structure and enclosed
	END STRUCTURE statements are noted and passed.
	The eading_structure state checks for the 3 special cases and 
	processes then as they occur.  The two sub-states are required 
	because any attempt to read the whole line will also swallow the
	special cases, so they will not be recognized.  the state 
	reading_structure2 reads entire lines up to the \n.
	reading_structure3 is only used to read that part of a line which
	follows the STRUCTURE token.  I had to create it because the 
	^ character is not recognized in reading_structure2.  This may be 
	caused by the top level state reading a character then putting it back.
	*/
	{WHITE}*END{WHITE}*STRUCTURE.*\n {
		--structureNestDepth;
		if ( !structureNestDepth)
			{popState ();
			pushState (reading_next_line);
			}
		yyless (yyleng-1);
		return returnTok (PASS_STATEMENT_T);
		}
	^(({NUMERIC_CHAR})|({WHITE}))*STRUCTURE{WHITE}+ {
		++structureNestDepth;
		pushState (reading_structure3);
		return returnTok (PASS_STATEMENT_T);
		}
	\n {
		++lineNo; 
		return returnTok (END_OF_STATEMENT);
		}
	^. {yyless (0); pushState (reading_structure2); return retIgnore (); }
	. {yyless (0); pushState (reading_structure2); return retIgnore (); }
	}	/* reading_structure */

<reading_structure2>
	{	/* reading_structure2 
	*/
	.* {popState (); return returnTok (PASS_STATEMENT_T); }
	}	/* reading_structure2 */

<reading_structure3>
	{	/* reading_structure3 
	*/
	.* {popState (); return returnTok (PASS_TEXT); }
	}	/* reading_structure3 */


<detailed_type_spec>
	{	/* detailed_type_spec */
	FUNCTION{WHITE}* 	{
		popState ();
		pushState (function_statement);
		return returnTok (FUNCTION);
		}
	{WHITE}*\*{WHITE}*	{return returnTok (STAR);  }
	{WHITE}*{INTEGER_CONSTANT}{WHITE}*	{
		currentSymbol->constantValue = atoi (currentSymbol->token);
		return returnTok (INTEGER_CONSTANT);  }
	{APOS}{OCTAL_CHAR}+{APOS}O {
		currentSymbol->constantValue = octalToI (currentSymbol->token+1);
		return returnTok (INTEGER_CONSTANT);}
	{APOS}{HEX_CHAR}+{APOS}X { 
		currentSymbol->constantValue = hexToI (currentSymbol->token+1);
		return returnTok (INTEGER_CONSTANT); }
	\.FALSE\. {return returnTok (INTEGER_CONSTANT);}
	\.TRUE\. {currentSymbol->constantValue = 1; return returnTok (INTEGER_CONSTANT); }
	{APOS} {pushState (reading_string);
  	  currentSymbol->printWithNextToken = 1; return returnTok (STRING_START); }
	{WHITE}*\({WHITE}*	{return returnTok (L_PAREN);  }
	{WHITE}*\){WHITE}*	{return returnTok (R_PAREN);  }
	{WHITE}*\,{WHITE}*	{return returnTok (COMMA);  }
	{WHITE}*:{WHITE}*	{return returnTok (COLON);  }
	{VARIABLE_NAME} return returnTok (VARIABLE_NAME);
	{FIXED_POINT_CONSTANT} { return returnTok (REAL_CONSTANT); }
	{REAL_CONSTANT} { return returnTok (REAL_CONSTANT); }
	{SLASH} { return returnTok (SLASH); }
	{ADD_OP} return returnTok (ADD_OP);
	}  /* detailed_type_spec */

<pass_until_slash>
	{	/* pass_until_slash  */
	[^/] {return returnTok (PASS_TEXT);  }
	{SLASH} {popState (); return returnTok (SLASH);  }
	}	/* pass_until_slash  */

<function_statement>
	{	/* function_statement */
	{STAR} return returnTok (STAR);
	{COMMA} return returnTok (COMMA);
	{L_PAREN} return returnTok (L_PAREN);
	{R_PAREN} return returnTok (R_PAREN);
	{VARIABLE_NAME} return returnTok (VARIABLE_NAME);
	{INTEGER_CONSTANT} 	{
		currentSymbol->constantValue = atoi (currentSymbol->token);
		return returnTok (INTEGER_CONSTANT);
		}
	}	/* function_statement */

<implicit_statement>
	{	/* implicit_statement  */
	LOGICAL{WHITE}*	{
		return returnTok (LOGICAL_TYPE);
		}
	BYTE{WHITE}*	{
		return returnTok (BYTE_TYPE);
		}
	INTEGER{WHITE}*	{
		return returnTok (INTEGER_TYPE);
		}	
	REAL{WHITE}*	{
		return returnTok (REAL_TYPE);
		}
	DOUBLE{WHITE}*PRECISION{WHITE}*	{
		return returnTok (DOUBLE_TYPE);
		}
	COMPLEX{WHITE}*	{
		return returnTok (COMPLEX_TYPE);
		}
	DOUBLE{WHITE}*COMPLEX{WHITE}*	{
		return returnTok (DOUBLE_COMPLEX_TYPE);
		}
	CHARACTER return returnTok (CHARACTER_TYPE);
	{WHITE}*[a-z]{WHITE}*	{return returnTok (CHAR); }
	{WHITE}*\*{WHITE}*	{return returnTok (STAR);  }
	{WHITE}*{INTEGER_CONSTANT}{WHITE}*	{
		currentSymbol->constantValue = atoi (currentSymbol->token);
		return returnTok (INTEGER_CONSTANT);  }
	{WHITE}*\({WHITE}*	{return returnTok (L_PAREN);  }
	{WHITE}*\){WHITE}*	{return returnTok (R_PAREN);  }
	{WHITE}*\,{WHITE}*	{return returnTok (COMMA);  }
	{WHITE}*-{WHITE}*	{return returnTok (DASH);  }
	
	}	/* implicit_statement */

<common_statement>
	{	/* common_statement  */
	{INTEGER_CONSTANT} 	{
		currentSymbol->constantValue = atoi (currentSymbol->token);
		return returnTok (INTEGER_CONSTANT); }
	{SLASH} return returnTok (SLASH);
	{L_PAREN} return returnTok (L_PAREN);
	{R_PAREN} return returnTok (R_PAREN);
	{COMMA} return returnTok (COMMA);
	{VARIABLE_NAME} return returnTok (VARIABLE_NAME);
	{COLON} return returnTok (COLON);
	{ADD_OP} return returnTok (ADD_OP);
	}	/* common_statement  */

<intrinsic_or_external>
	{	/* intrinsic_or_external */
	{VARIABLE_NAME}	return returnTok (VARIABLE_NAME);
	{COMMA} return returnTok (COMMA);
	}	/* intrinsic_or_external */

<dimension_statement>
	{	/* dimension_statement */
	{VARIABLE_NAME} return returnTok (VARIABLE_NAME);
	{INTEGER_CONSTANT} 	{
		currentSymbol->constantValue = atoi (currentSymbol->token);
		currentSymbol->arithType = ENAT_INT;
		return returnTok (INTEGER_CONSTANT);}
	{L_PAREN} return returnTok (L_PAREN);
	{R_PAREN} return returnTok (R_PAREN);
	{COLON} return returnTok (COLON);
	{COMMA} return returnTok (COMMA);
	{ADD_OP} return returnTok (ADD_OP);
	{MUL_OP} return returnTok (MUL_OP);
	}	/* dimension_statement */

<ip_pb_common>
	{  /* ip_pb_common */
	FORMAT	{
		popState (); 
		pushState (reading_pass_through); 
		return returnTok (FORMAT_STATEMENT);
		}
	NAMELIST|ENTRY	{
		popState ();
		pushState (reading_pass_through);
		return returnTok (PASS_STATEMENT_T);
		}
	}	/* ip_pb_common  */

<program_body>
	{	/* program_body */
	{IP_PB_COMMON}	{
		yyless (0);
		pushState (ip_pb_common);
		return retIgnore ();
		}
	{PB_P_T1}|{PB_P_T2}|{PB_P_T3}|{PB_P_T4}	{
		pushState (reading_pass_through);
		return returnTok (PASS_STATEMENT_T);
		}
	OPEN{WHITE}*\(		{
		pushState (processing_open);
		return returnTok (OPEN_STATEMENT_T);
		}
	CALL{WHITE}* {
		pushState (arith_statement);
		return returnTok (CALL);
		}
	IF{WHITE}*\( {
		pushState (processing_if1);
		parenNestingLevel = 0;
		return returnTok (IF_STATEMENT);
		}
	.	{ 
		yyless (0);
		pushState (arith_statement);
		currentSymbol->tokenSize = 0;
		return retIgnore ( );
		}
	(READ|WRITE|REWRITE){WHITE}*\(	{
		pushState (io_statement);
		apostropheSemanticsLevel = 0;
		parenNestingLevel = 0;
		return returnTok (IO_STATEMENT);
		}
	(ENCODE|DECODE){WHITE}*	{
		pushState (encode_decode);
		parenNestingLevel = 0;
		return returnTok (ENCODE_DECODE);
		}
	(DO{WHITE}+)|(DO{WHITE}*WHILE) {
		pushState (do_statement); return returnTok (DO_STATEMENT);
		}
	END{WHITE}*DO	{
		pushState (reading_pass_through); return returnTok (END_DO_STATEMENT);
		}
	END{WHITE}*IF	{
		pushState (reading_pass_through); return returnTok (END_IF_STATEMENT);
		}
	ELSE{WHITE}*IF{WHITE}*\(	{
		/* We can not combine elseif processing with if processing even though
			they are treated the same in the lexer.  The reason is that the
			output process needs to recognize the elseif in order to get
			block indention correct. */
		pushState (processing_if1);
		parenNestingLevel = 0;
		return returnTok (ELSE_IF_STATEMENT);
		}
	ELSE{WHITE}*	{return returnTok (ELSE_STATEMENT);
		}

		
	}  /* program_body */

	/*	This statement is commented out because processing I/O statements
		will take too long for now.  When you want to do I/O statements
		put this commented block back into the <program_body> block
		and remove the obvious stuff
	*/

<processing_if1>
	{  /* processing_if1  */
	{APOS} {pushState (reading_string); 
		currentSymbol->printWithNextToken = 1; return returnTok (STRING_START); }
	\. return returnTok (IF_ARGUEMENT);
	\( {
		++parenNestingLevel;
		return returnTok (IF_ARGUEMENT);
		}
	\) {
		if (parenNestingLevel)
			{--parenNestingLevel;
			return returnTok (IF_ARGUEMENT);
			}
		popState ();
		pushState (processing_if2);
		return returnTok (R_PAREN);
		}
	[^\n.()]* return returnTok (IF_ARGUEMENT);
	{RELATIONAL_OP} {
		return returnTok (RELATIONAL_OP_T);
		}
	}  /* processing_if1  */

<processing_if2>
	{  /*  processing_if2  */
	{WHITE}*\,{WHITE}* return returnTok (COMMA);
	{WHITE}*[0-9]+{WHITE}* return returnTok (INTEGER_CONSTANT);
	{WHITE}*THEN{WHITE}* return returnTok (THEN_T);
	. {
		popState ();
		pushState (reading_pass_through);
		yyless (0);
		return retIgnore ();
		}
		
	}  /*  processing_if2  */

<processing_open>
	{  /* processing_open  */
	{WHITE}*,{WHITE}* return returnTok (COMMA);
	{WHITE}*\){WHITE}*	{
		popState ();
		return returnTok (R_PAREN);
		}
	\n {
		return newLine ();}
	!.* {processComment (ENCT_END_OF_LINE); return retIgnore (); }
	{WHITE}*[0-9]+{WHITE}* return returnTok (INTEGER_CONSTANT);
	{WHITE}*FILE{WHITE}*	{
		pushState (parse_file_option);
		return returnTok (OPEN_PASS);
		}
	{WHITE}*NAME{WHITE}*	{
		pushState (parse_file_option);
		reassignToken (currentSymbol, "FILE");
		return returnTok (OPEN_PASS);
		}
	{WHITE}*((UNIT)|(ACCESS)|(ASSOCIATEVARIABLE)|(BLANK)|(ERR)|(FORM)|(IOSTAT)|(KEY)){WHITE}* |
	{WHITE}*((RECL)|(SHARED)|(STATUS)|(USEROPEN)|(DISPOSE)){WHITE}*	{
		pushState (passing_file_open_option);
		parenNestingLevel = 0;
		return returnTok (OPEN_PASS);
		}
	{WHITE}*((BLOCKSIZE)|(BUFFERCOUNT)|(CARRIAGECONTROL)|(EXTENDSIZE)|(INITIALSIZE)){WHITE}* |
	{WHITE}*((MAXREC)|(NOSPANBLOCKS)|(ORGANIZATION)|(READONLY)|(RECORDTYPE)|(DEFAULTFILE)){WHITE}* {
		pushState (passing_file_open_option);
		parenNestingLevel = 0;
		return returnTok (OPEN_DUMP);
		}
	{WHITE}*TYPE{WHITE}* {
		reassignToken (currentSymbol, "STATUS");
		pushState (passing_file_open_option);
		parenNestingLevel = 0;
		return returnTok (OPEN_PASS);
		}
	{WHITE}*RECORDSIZE{WHITE}* {
		reassignToken (currentSymbol, "RECL");
		pushState (passing_file_open_option);
		parenNestingLevel = 0;
		return returnTok (OPEN_PASS);
		}
		
	}  /* processing_open */
	
<parse_file_option>
	{	/* parse_file_option */
	'	{
		popState (); 
		pushState (reading_file_spec);
		currentSymbol->printWithNextToken = 1;
		currentSymbol->token[0] = '\"';
		return returnTok (PASS_TEXT);
		}
	=	return returnTok (PASS_TEXT);
	.	{yyless (0); 	/* file spceification is a variable */
		popState ();
		pushState (passing_file_open_option);
		parenNestingLevel = 0;
		return retIgnore ( ); }
	}	/* parse_file_option */

<do_statement>
	{ /* do_statement */
	{INTEGER_CONSTANT}{WHITE}*	{return returnTok (INTEGER_CONSTANT);}
	\,{WHITE}*	{return returnTok (COMMA);}
	.	{
		popState (); 
		yyless(0); 
		pushState (reading_pass_through); 
		return retIgnore ();}
	}	/* do_statement */

<passing_file_open_option>
	{  /* passing_file_open_option  */
	[^,\n()!]* return returnTok (PASS_TEXT);
	\(	{++parenNestingLevel;	return returnTok (PASS_TEXT); }
	\,	{
		if (parenNestingLevel)
			return returnTok (PASS_TEXT);
		popState ();
		yyless (0);
		return retIgnore ();
		}
	\)	{
		if (parenNestingLevel)
			{--parenNestingLevel;
			return returnTok (PASS_TEXT);
			}
		popState ();
		yyless (0);
		return retIgnore ();
		}
	}	/* passing_file_open_option */

<io_statement>
	{	/* io_statement */
	\n return newLine ();
	\( {++parenNestingLevel; return returnTok (L_PAREN); }
	\) {
		if (parenNestingLevel)
			--parenNestingLevel;
		else
			{popState ();
			pushState (reading_pass_through);
			}
		return returnTok (R_PAREN);
		}
	{COMMA} 	{ /* must change states because an apostrophe has completely
			 different semantics after the unit designator  */
		++apostropheSemanticsLevel;
		/*
		popState  ();
		pushState (io_statement2);*/
		return returnTok (COMMA);
		}
	' {
		if ( !apostropheSemanticsLevel)
			return returnTok (APOS);
		else
			{pushState (reading_string);
			currentSymbol->printWithNextToken = 1; return returnTok (STRING_START);
			}
		}
	{VARIABLE_NAME} return returnTok (VARIABLE_NAME);
	{INTEGER_CONSTANT} return returnTok (INTEGER_CONSTANT);
	\* return returnTok (MUL_OP);
	: return returnTok (COLON);
	{MUL_OP} return returnTok (MUL_OP);
	{ADD_OP} return returnTok (ADD_OP);	
	{VARIABLE_NAME}{WHITE}*= {
		yyless (yyleng-1);
		--currentSymbol->tokenSize;
		popState ();
		pushState (io_control_key);
		return returnTok (IO_PARAM_NAME);
		}
	
	}	/* io_statement */

<io_statement2>
	{	/* io_statement2 */
	\n return newLine ();
	\( {++parenNestingLevel; return returnTok (L_PAREN); }
	\) {
		if (parenNestingLevel)
			--parenNestingLevel;
		else
			popState ();
		return returnTok (R_PAREN);
		}
	' {
		pushState(reading_string);
		currentSymbol->printWithNextToken = 1; return returnTok (STRING_START);
		}
	.	return returnTok (COMMA);
	{VARIABLE_NAME}|{INTEGER_CONSTANT}|\* return returnTok (UNIT_IDENT);
	{VARIABLE_NAME}{WHITE}*= {
		yyless (yyleng-1);
		--currentSymbol->tokenSize;
		popState ();
		pushState (io_control_key);
		return returnTok (IO_PARAM_NAME);
		}
	{MUL_OP} return returnTok (MUL_OP);
	{ADD_OP} return returnTok (ADD_OP);	
	}	/* io_statement2 */

<io_control_key>
	{	/* io_control_key */
	\n return newLine ();
	\( {++parenNestingLevel; return returnTok (L_PAREN); }
	\) {
		if (parenNestingLevel)
			--parenNestingLevel;
		else
			{popState ();
			pushState (reading_pass_through);
			}
		return returnTok (R_PAREN);
		}
	{COMMA}	return returnTok (COMMA);
	{VARIABLE_NAME}{WHITE}*= {
		yyless (yyleng-1);
		--currentSymbol->tokenSize;
		return returnTok (IO_PARAM_NAME);
		}
	{WHITE}*={WHITE}*	{
		pushState (io_param);
		return returnTok (EQUALS);
		}
	}	/* io_control_key */

<io_param>
	{	/* io_param */
	\n return newLine ();
	' {
		popState ();
		pushState(reading_string);
		currentSymbol->printWithNextToken = 1; return returnTok (STRING_START);
		}
	.	{
		popState ();
		pushState (passing_file_open_option);
		parenNestingLevel = 0;
		return returnTok (PASS_TEXT);
		}
	}	/*  io_param */

<encode_decode>
	{	/*encode_decode */
	{L_PAREN} { ++parenNestingLevel; return returnTok (L_PAREN); }
	{R_PAREN} { 
		--parenNestingLevel;
		if ( !parenNestingLevel)
			{popState ();
			pushState (reading_pass_through);
			}
		return returnTok (R_PAREN); }
	{COMMA}	return returnTok (COMMA);
	{COLON} return returnTok (COLON);
	{ADD_OP} return returnTok (ADD_OP);
	{MUL_OP} return returnTok (MUL_OP);
	{DOT} return returnTok (DOT);
	{INTEGER_CONSTANT} {
		currentSymbol->constantValue = atoi(currentSymbol->token);
		return returnTok (INTEGER_CONSTANT); }
	{VARIABLE_NAME} { return returnTok (VARIABLE_NAME);}
	{WHITE}*={WHITE}*	{ return returnTok (EQUALS); }
	}	/*encode_decode */

<arith_statement>
	{	/* arith_statement */
	{WHITE}*\%REF{WHITE}* 	{return returnTok (REFERENCE);}
	(\%VAL)|(\%REF)|(\%DESCR)|(\%LOC) {return returnTok (VARIABLE_NAME); }
	{APOS}{OCTAL_CHAR}+{APOS}O {
		currentSymbol->constantValue = octalToI (currentSymbol->token+1);
		currentSymbol->arithType = ENAT_INT;
		currentSymbol->arithSize = defaultVariableSize (ENAT_INT);
		return 	returnTok (INTEGER_CONSTANT);}
	\"{OCTAL_CHAR}+  {
		currentSymbol->arithType = ENAT_INT;
		currentSymbol->arithSize = defaultVariableSize (ENAT_INT);
		convertOctal (); return returnTok (INTEGER_CONSTANT); }
	{APOS}{HEX_CHAR}+{APOS}X {
		currentSymbol->constantValue = hexToI (currentSymbol->token+1);
		currentSymbol->arithType = ENAT_INT;
		currentSymbol->arithSize = defaultVariableSize (ENAT_INT);
		return returnTok (INTEGER_CONSTANT);}
	{EQUALS} return returnTok (EQUALS);
	{L_PAREN} return returnTok (L_PAREN);
	{R_PAREN} return returnTok (R_PAREN);
	{COMMA} return returnTok (COMMA);
	{ADD_OP} return returnTok (ADD_OP);
	{MUL_OP} return returnTok (MUL_OP);
	{EXP_OP} return returnTok (EXP_OP);
	{CONCAT} return returnTok (CONCAT);
	{WHITE}*\.NOT\.{WHITE}* return returnTok (LOGICAL_NOT);
	{WHITE}*((\.AND\.)|(\.OR\.)|(\.NEQV\.)|(\.XOR\.)|(\.EQV\.)){WHITE}* {
		return returnTok (LOGICAL_OP); }
	{WHITE}*{RELATIONAL_OP}{WHITE}* return returnTok (LOGICAL_OP);
	{COLON} return returnTok (COLON);
	{VARIABLE_NAME} return returnTok (VARIABLE_NAME);
	{INTEGER_CONSTANT} {
		currentSymbol->arithType = ENAT_INT;
		currentSymbol->arithSize = defaultVariableSize (ENAT_INT);
		currentSymbol->constantValue = atoi(currentSymbol->token);
		return returnTok (INTEGER_CONSTANT); }
	{FIXED_POINT_CONSTANT} {
		currentSymbol->arithType = ENAT_REAL;
		currentSymbol->arithSize = defaultVariableSize (ENAT_REAL);
		return returnTok (REAL_CONSTANT);}
	{REAL_CONSTANT} {
		if (strcspn (currentSymbol->token, "eE") < yyleng)
			{currentSymbol->arithType = ENAT_REAL;
			currentSymbol->arithSize = defaultVariableSize (ENAT_REAL);}
		else
			{currentSymbol->arithType = ENAT_REAL;
			currentSymbol->arithSize = defaultVariableSize (ENAT_DOUBLE);}
		return returnTok (REAL_CONSTANT);}
	{WHITE}*' {pushState (reading_string); currentSymbol->printWithNextToken = 1; 
		return returnTok (STRING_START);}
	{WHITE}*\.{WHITE}* return returnTok (DOT);
	\.TRUE\. {
		currentSymbol->arithType = ENAT_INT; 
		currentSymbol->arithSize = 4;
		currentSymbol->constantValue = 1;
		return returnTok (INTEGER_CONSTANT);
		}
	\.FALSE\. {
		currentSymbol->arithType = ENAT_INT; 
		currentSymbol->arithSize = 4;
		currentSymbol->constantValue = 0;
		return returnTok (INTEGER_CONSTANT);
		}
	}	/* arith_statement */

%%

/* **************************** addIncludeSegment ********************** */
void addIncludeSegment (char *name)
{INCLUDE_SEGMENT	*pi;
char			*lastChar,
				work[500];
int				length;

strcpy (work, name);
length = strlen (name);
lastChar = work + length;
if ( (*lastChar!='/') && (*lastChar !='\\') )
	{strcat (work, "/");
	++length;
	}
if ( !includeDirectories)
	{includeDirectories = (INCLUDE_SEGMENT *) malloc (sizeof (INCLUDE_SEGMENT) + length);
	pi = includeDirectories;
	}
else
	{for (pi=includeDirectories;	pi->next;	)
		pi = pi->next;
	pi->next = (INCLUDE_SEGMENT *)malloc (sizeof (INCLUDE_SEGMENT) + length);
	pi = pi->next;
	}
pi->next = 0;
strcat (pi->name, work);
}

/* **************************** binaryToI ****************************** */
int binaryToI (char *pch)
{int		val;

for (val=0;	*pch;	++pch)
	val = val*2 + *pch-'0';
return val;
}

/* **************************** convertOctal ************************** */
/*	Convert the token in currentSymbol from the old VAX octal format to 
	the new version and calculate the binary equivalent.  
*/

void convertOctal (void)
{
char work[20];

work[0] = '\'';
strcpy (&work[1], currentSymbol->token+1);
strcat (work, "'O");
reassignToken (currentSymbol, work);
currentSymbol->constantValue = atoi (&work[1]);
return;
}

/* **************************** decimalToI ************************ */
int	decimalToI (char *pch)
{int		i, val;

for (val=0; *pch;	++pch)
	{if ( (*pch >= '0') && (*pch <= '9') )
		val = val*10 + (*pch-'0');
	else
		{printError ("illegal decimal constant");
		return 0;
		}
	}
return val;
}

static char		errorMessage[500];
/* **************************** errorInit ************************ */
/*	Initialize an error message by formattint ethe current file and line
	number for output.  If the current file has been INCLUDED ed, all
	of the including files are also formatted.  The result is placed
	in a loage static buffer.  The return value points to the 
	terminating  NULL of the formatted string.  The caller may use
	this pointer fo place additional information in the buffer.  
	after ading such data, the user calls errorWrite (below) to 
	write the buffer
*/
char	*errorInit (void)
{FILE_INFO			*pfi;
int					depth;
char				*pch;

pch = errorMessage;

pch += sprintf (pch, "%s Line %d: " ,currentFileName, lineNo);

for (depth=includeDepth;	depth;	--depth)
	{pfi = includeStack + depth;
	pch+= sprintf (pch, "\n        included from: %s line %d",
		pfi->fileName, pfi->currentLineNo);
	}
return pch;
}

/* ******************************** errorWrite ************************ */
void errorWrite (void)
{
printf (errorMessage);
if (errorFile)
	fprintf (errorFile, errorMessage);
return;
}

/* ***************************** hexToI ************************** */
int	hexToI (char *pch)
{int		i, val;

for (val=0;	*pch;	++pch)
	{if ( (*pch>='a') && (*pch<='f') )
		i = 10 +*pch-'a';
	else if ( (*pch>='A') && (*pch<='F') )
		i = 10 + *pch-'A';
	else if ( (*pch>='0') && (*pch<='9') )
		i = *pch-'0';
	else
		break;
	val = (val<<4) + i;
	}
return val;
}

/* ************************** processIncludeEnvironment ******************* */
void processIncludeEnvironment (void )
{char		*pch,
			*pip;
char		work[300];

pip = getenv ("CONVERTINCLUDES");
if ( !pip)
	return;
while (strlen (pip))
	{pch = strpbrk (pip, ":;");
	if (pch)
		{strncpy (work, pip, pch-pip);
		work[pch-pip] = 0;}
	else
		strcpy (work, pip);
	addIncludeSegment (work);
	if ( !pch)
		break;
	pip = pch+1;
	}
return;
}

/* **************************** octalToI ************************ */
int	octalToI (char *pch)
{int		i, val;

for (val=0; *pch;	++pch)
	{if ( (*pch >= '0') && (*pch <= 'y') )
		val = val*8 + (*pch-'0');
	else
		break;
	}
return val;
}

/* *************************** initLexer *************************** */
void initLexer (void)
{
stateDepth = 0;
BEGIN (0);
currentState = 0;
pushState (initialize_module);
pushState (reading_next_line);
endStatementRevertState=initialize_module;
return;
}

/* ************************ lexerEndOfStatementProc ************************ */
void lexerEndOfStatementProc (void)
{
currentStatementNo = nextStatementNo;
nextStatementNo = 0;
currentSymbol = 0;
previousSymbol = 0;
currentTokenOffset = 0;
lastComment = 0;
commentsOnCurrentLine = 0;
return;
}

static char *errorMessage1 = "Parse error on the following line\n";
static char *errorMessage2 = "\n before the following text\n";
/* ************************** lexerErrorProc ************************** */
/* Come here when the parser detects an error */
void lexerErrorProc (void)
{YACC_SYMBOL	*pys;
int				handle;

handle = fileno (yyout);
fputs (errorMessage1, yyout);
pys = (YACC_SYMBOL *) (tokenHeap.startOfHeap);
for (	; pys;	pys = pys->lexerLink)
	fwrite ( (void *)(pys->token), 1, pys->tokenSize, yyout);

fputs (errorMessage2, yyout);
fflush (yyout);
revertToState (endStatementRevertState);
pushState (reading_error_text);
return;
}

/* **************************** newLine ***************************** */
static int newLine (void)
{
++lineNo;
pushState (reading_next_line);
return IGNORE_THIS_TOKEN;
}

/* ******************************** popFile ****************************** */
void popFile (void)
{
FILE_INFO		*pfi;
int			i;

--includeDepth;
fclose (yyin);
pfi = includeStack+includeDepth;
free ( (void *) currentFileName);
currentFileName = pfi->fileName;
lineNo = pfi->currentLineNo;
yy_delete_buffer (YY_CURRENT_BUFFER);
yy_switch_to_buffer (pfi->bufferState);
EOFRead = 1;
BEGIN(currentState);
return;
}

/* ******************************** popState ***************************** */
static void popState (void)
{
if (stateDepth < 1)
	{printf ("State stack underflow\n");
	exit (4);
	}
currentState = stateStack[--stateDepth];
BEGIN (currentState);
return;
}

/* ***************************** popNStates ************************* */
void popNStates (int count)
{
if (stateDepth < count)
	{printf ("State stack underflow\n");
	exit (4);
	}
stateDepth -= count;
currentState =  stateStack[stateDepth];
BEGIN(currentState);
return;
}

/* ***************************** printError *************************** */
static void printError (char *msg)
{char		buff[200];

sprintf (buff, "%s: %s on line %d\n", currentFileName, msg, lineNo);
printf (buff);
fprintf (errorFile, buff);
return;
}

/* ******************************* processComment ************************ */
static void processComment (EN_COMMENT_TYPE type)
{
COMMENT_CONTROL		*pc;

pc = (COMMENT_CONTROL *) heapAlloc (&commentHeap, 
		sizeof (COMMENT_CONTROL) + yyleng );
pc->commentType = type;
pc->nextComment = 0;
pc->length = yyleng;
/*currentTokenOffset -= yyleng;*/
pc->statementOffset = currentTokenOffset;
strcpy (pc->text, yytext);
if ( !lastComment)
	lastComment = pc;
else
	{lastComment->nextComment = pc;
	lastComment = pc;
	}
++commentsOnCurrentLine;
return;
}

/* ******************************* pushFile *************************** */
void	pushFile (char *name)
{FILE		*fp;
FILE_INFO	*pfi;
int			i;
INCLUDE_SEGMENT		*pi;
char		work[300];

#if 1
if (currentSourceDir)
	{strcpy (work, currentSourceDir);
	strcat (work, name);
	fp = fopen (work, "r");
	if (fp)
	goto l4;
	}
#endif
i = strlen (name);
fp = fopen (name, "r");
if ( fp)
	goto l4;
	
for (pi=includeDirectories;	pi;	pi=pi->next)
	{strcpy (work, pi->name);
	strcat (work, name);
	fp = fopen (work, "r");
	if (fp)
		break;
	}
if ( !fp)
	{char		msg[100];
	
	strcpy (msg, "Open failure on ");
	strcat (msg, name);
	printError (msg);
	return;
	}

l4:

pfi = includeStack + includeDepth;
if (includeDepth >= MAX_INCLUDE_DEPTH)
	{printf ("Include depth exceeded\n");
	exit (1);
	}
pfi->bufferState = YY_CURRENT_BUFFER;
pfi->fileName = currentFileName;
pfi->currentLineNo = lineNo;
currentFileName = (char *) malloc (i+1);
strcpy (currentFileName, name);
yy_switch_to_buffer (yy_create_buffer (fp, YY_BUF_SIZE));
lineNo = 1;
++includeDepth;
filePushed = 1;
/*currentState = endStatementRevertState;*/
currentState = reading_next_line;
pushState(currentState);
writeDependencyInfo (includeStack[0].fileName, name);
}

/* ***************************** pushState ***************************** */
static void pushState (int newState)
{
if (stateDepth > (MAX_STATE_DEPTH-1) )
	{printf ("State stack overflow\n");
	exit (3);
	}
stateStack[stateDepth++] = YY_START;
currentState = newState;
BEGIN (newState);
return;
}

/* **************************** returnEOS ********************************** */
/* NOTE - you CAN NOT use this procedure if you are switching to a new base
   state
*/
static int returnEOS (void)
{
revertToState (endStatementRevertState);
return (END_OF_STATEMENT);
}

/* *************************** revertToState ****************************** */
static void revertToState (int desiredState)
{
while (YY_START != desiredState)
	popState ();
}

/* **************************** swallowEOL ****************************** */
static void swallowEOL (void)
{
int		size;
char	ch;

ch = input ();
++lineNo;
return;
}

/* ********************************** yywrap *************************** */
static int	yywrap (void)
{
if (!includeDepth)
	return (1);
popFile ();
return 0;
}
