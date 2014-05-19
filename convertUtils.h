typedef struct _TOKEN_ACCESS_CONTROL {
	YACC_SYMBOL		*currentToken;
	int				remainingChars;
	char			*nextChar;
	}	TOKEN_ACCESS_CONTROL;

void *bsearchOB( int *matchType, const void *key, const void *base,
		int num, int size, int (*compare)(const void *key, const void *element));
int compareTokens (const void *t1, const void *t2);
int compareCommonNames (const void * c1, const void *c2);
YACC_SYMBOL *createToken (char *tokenText);
int dollarInFileName (YACC_SYMBOL *token);
void dollarInVariableName (YACC_SYMBOL *token);
YACC_SYMBOL *initializeToken ( void);
void implicitLetterAssign (VARIABLE_TYPE *target, VARIABLE_TYPE *type,
	 char first);
void implicitRangeAssign (VARIABLE_TYPE *target, VARIABLE_TYPE *type,
	 char first, char last);
void initializeTokenSerialization (TOKEN_ACCESS_CONTROL *control,
		YACC_SYMBOL *firstToken);
void joinSymbols (YACC_SYMBOL **dest, YACC_SYMBOL *left, YACC_SYMBOL *right, ...);
void LAL (YACC_SYMBOL *left, YACC_SYMBOL *right, ...);
void makeLogicalIf (YACC_SYMBOL *pys, int isArith);
void printStatement (YACC_SYMBOL *statement, int statementNum, 
		FILE *outFile);
void pushFile (char *name);
void reassignToken (YACC_SYMBOL *tok, char *newText);
int	returnTok (int token);
int retIgnore (void);
char *serializeNextToken (TOKEN_ACCESS_CONTROL *control);
YACC_SYMBOL *substituteTokenText (YACC_SYMBOL *tok, char * newText);
void writeDependencyInfo (char *fortranFileName, char *info);

#define NEXT_TOKEN_CHAR (control, result) \
if ( !conrol.remainingChars) result=serializeNextToken (&control);  \
else	{result=*((control.nextChar)++); --control.remainingChars;}

#define MISSING_ARG LAST_DEFINED_TOKEN
#define COMMON_BLOCK_NAME LAST_DEFINED_TOKEN + 1

