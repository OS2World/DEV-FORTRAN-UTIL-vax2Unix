#include <io.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <stdlib.h>
#include <ctype.h>

#include "convert.h"
#include "parser.h"
#include "convertUtils.h"
#include "userHeap.h"

#define EXTERN extern
#include "externalVariables.h"

extern YYSTYPE			yylval;
extern int				yyleng;
extern char				*yytext;


/* **************************** bsearchOB ***************************** */
/* Works just like the standard bsearch except that it returns a pointer
   to the last element in the array which is smaller than key if there is
   no exact match.  The value match type is zero if the match is exact,
   otherwise it is non-zero.
*/
void *bsearchOB( int *matchType, const void *key, const void *base,
		int num, int size, int (*compare)(const void *key, const void *element))
{
void	*midElement;
int		bottomCount,
		topCount;
int		compareResult;

if ( !num)
	{*matchType = -1;
	return (void *)base;
	}
if ( !base)
	{*matchType = 1;
	return 0;
	}
*matchType = 0;

l2:

bottomCount = num/2;
if ( !bottomCount)
	{*matchType = compare (key, base);
	return (void *)base;
	}
topCount = num - bottomCount;
midElement = (void *) ( (char *)base + bottomCount*size);
compareResult = compare (key, midElement);
if ( !compareResult)
	return (void *)midElement;
if (compareResult > 0)
	{base = midElement;
	num = topCount;
	}
else
	num = bottomCount;
goto l2;
}

/* ******************************* compareTokens ************************* */
int compareTokens (const void *t1, const void *t2)
{
return strcmp ( (*((YACC_SYMBOL **) t1))->token, (*((YACC_SYMBOL **) t2))->token);
}

/* ***************************** compareCommonNames *********************** */
int compareCommonNames (const void * c1, const void *c2)
{
#if 1
COMMON_DEFINITION	**ppc1, **ppc2;
ppc1 = (COMMON_DEFINITION **)c1;
ppc2 = (COMMON_DEFINITION **)c2;
#endif
return strcmp ( (*((COMMON_DEFINITION **) c1))->name, 
	(*((COMMON_DEFINITION **) c2))->name);
}

/* **************************** createToken ************************** */
YACC_SYMBOL *createToken (char *tokenText)
{
YACC_SYMBOL		*retVal;
int				i;

i = strlen (tokenText);
retVal = (YACC_SYMBOL *)heapAlloc (&tokenHeap, sizeof(YACC_SYMBOL) + i);
memset ( (void *) retVal, 0, sizeof(YACC_SYMBOL) + i);
retVal->tokenSize = i;
strcpy (retVal->token, tokenText);
return retVal;
}

/* **************************** dollarInFileName *********************** */
int dollarInFileName (YACC_SYMBOL *token)
{
char		*pch;
int			retVal;

retVal = 0;
pch = token->token;
while (pch=strchr (pch, '$'))
	{retVal = 1;
	*pch = '_';
	}
if (retVal && (!forioerrIncluded) && (targetSystem!=ENTS_VAX) )
	{printf ("%s: System include found.  Use \"forioerr.i\"\n", currentFileName);
	fprintf (errorFile, "System include file found\n");
	}
return retVal;
}

struct stringSubstitute {
	char		*key,
				*replace;
	};

static struct stringSubstitute sysPrefix[] = {"SS$_", "SS__", 
				"FOR$", "FOR_", 0, 0};

/* ************************** dollarInVariableName ******************* */
void dollarInVariableName (YACC_SYMBOL *token)
{
char		*pch,
			*pch2;
char		*newText;
char		*pd;
int			i;
struct stringSubstitute		*pss;

newText = 0;
pch = token->token;
for (pss = sysPrefix;	pss->key;	++pss)
	{if ( !(pch2=strstr  (pch, pss->key)) )
		continue;
  /* VERY sloppy - only works if key and replcce strings are the same length */
	strncpy (pch2, pss->replace, sizeof (pss->replace) );
	}

if (newText)
	free ( (void *) newText);
}
/* *************************** implicitLetterAssign *********************** */
void implicitLetterAssign (VARIABLE_TYPE *target, VARIABLE_TYPE *type,
	 char first)
{
target[tolower(first)-'a'] = *type;
return;
}

/* *************************** implicitRangeAssign *********************** */
void implicitRangeAssign (VARIABLE_TYPE *target, VARIABLE_TYPE *type,
	 char first, char last)
{int	i,
		limit;

limit=tolower(last-'a');
for (i=tolower (first-'a');	i<=limit;	++i)
	target[i] = *type;
return;
}

/* *************************** initializeToken ***************************** */
YACC_SYMBOL *initializeToken ( void)
{YACC_SYMBOL	*retVal;


retVal = (YACC_SYMBOL *) heapAlloc (&tokenHeap, sizeof (YACC_SYMBOL) + yyleng);
memset ( (void *) retVal, 0, sizeof (YACC_SYMBOL) );
retVal->statementCharNo = currentTokenOffset;
currentTokenOffset += yyleng;
retVal->tokenSize = yyleng;
strcpy (retVal->token, yytext);
dollarInVariableName (retVal);
if (currentSymbol)
	currentSymbol->lexerLink = retVal;
previousSymbol = currentSymbol;
currentSymbol = retVal;
yylval.ysym = retVal;
return retVal;
}

/* ********************** initializeTokenSerialization ******************** */
void initializeTokenSerialization (TOKEN_ACCESS_CONTROL *control,
		YACC_SYMBOL *firstToken)
{
control->currentToken = firstToken;
control->remainingChars = firstToken->tokenSize;
control->nextChar = firstToken->token;
}

/* ****************************** joinSymbols ****************************** */
void joinSymbols (YACC_SYMBOL **dest, YACC_SYMBOL *left, YACC_SYMBOL *right, ...)
{va_list				ap;

for (va_start (ap, right);	right; right=va_arg (ap, YACC_SYMBOL *))
	{if ( !(left)->next)
		{left->next = right;
		}
	else		/* if left->next is defined then left->last must also be defined */
		{((left)->last)->next = right;
		}
	if ( !right->last)
		{left->last = right;
		}
	else
		{left->last = right->last;
		}
	}
*dest= left;
va_end (ap);
return;
}

/* ******************************** LAL ****************************** 
	link tokens through the argListLink field */
void LAL (YACC_SYMBOL *left, YACC_SYMBOL *right, ...)
{va_list		ap;
YACC_SYMBOL		*py;

if ((int)left == 1)
	{left = createToken("");
	left->number = MISSING_ARG;
	left->variableType = ENVT_DEFAULT_PARAM;
	}
for (py=left;	py->argListLink;	py=py->argListLink)
	;		/* NOTHING */
for (va_start(ap, right);	right;	right=va_arg (ap, YACC_SYMBOL *) )
	{if ((int)right == 1)
		{right = createToken ("");
		right->number = MISSING_ARG;
		right->variableType = ENVT_DEFAULT_PARAM;
		}
	py->argListLink = right;
	py = right;
	}
va_end (ap);
return;
}

/* ****************************** makeLogicalif ************************** */
void makeLogicalIf (YACC_SYMBOL *pys, int isArith)
{
TOKEN_ACCESS_CONTROL	control;
char *newToken = " .NE. 0)";
YACC_SYMBOL			*new,
					*previous;

previous = 0;
if ( !isArith)
	return;
initializeTokenSerialization (&control, pys);
while (pys->number != R_PAREN)
	{previous = pys;
	pys = pys->next;
	}
new = substituteTokenText (pys, newToken);
previous->next = new;
if (lastComment)
	lastComment->statementOffset += 7;
return;
}

static char *blanks = "                                             \
                                                                       ";

/* ******************************** printStatement ************************* */
void printStatement (YACC_SYMBOL *statement, int statementNum, FILE *outFile)
{
COMMENT_CONTROL	*currentComment;
YACC_SYMBOL		*ct,
				*ct2;
static char		newLine = '\n';
static char		*first6Comment = "C     ";
static char		firstCols[6];
int				colNo;
int				commentWritten;
int				handle;
int				outNo;
int				effectiveTokenSize;
int				indents, level;

if (inhibitOutput || generateGlobalData )
	{currentComment = 0;
	return;
	}
if (commentsOnCurrentLine)
	currentComment = (COMMENT_CONTROL *) (commentHeap.startOfHeap);
else
	currentComment = 0;
handle = fileno(outFile);

while (currentComment && 
	(currentComment->statementOffset <= statement->statementCharNo))
	{write (handle, (void *) (currentComment->text), currentComment->length);
	write (handle, (void *) &newLine, 1);
	currentComment = currentComment->nextComment;
	}

if (statement->number == COMMENT_STATEMENT_OUT)
	{write (handle, (void *) first6Comment, 6);
	for (ct=statement;	ct;	ct=ct->next)
		write (handle ,(void *)(ct->token), ct->tokenSize);
	write (handle, (void *) &newLine, 1);
	goto l8;
	}
if (statementNum)
	sprintf (firstCols,"%5d " , statementNum);
else
	memset ( (void *)firstCols, ' ', 6);
write (handle, (void *) firstCols, 6);
memset ( (void *)firstCols, ' ', 6);
firstCols[5] = '1';
colNo = 6;
if (blockIndentLevel)
	{level = blockIndentLevel;
	switch (statement->number)
		{
	case ELSE_IF_STATEMENT:
	case ELSE_STATEMENT:
	case DO_STATEMENT:
	case IF_THEN_STATEMENT:
		if (level>=1)
			--level;
		break;
	case FORMAT_STATEMENT:
	case INCLUDE_T:
		level=0;
		break;
		}
	indents = 2*level;
	write (handle, (void *) blanks, indents);
	colNo += indents;
	}
else
	level = 0;
indents = 2*level;
commentWritten = 0;
for (ct=statement;	ct	; ct = ct->next)
	{
	commentWritten = 0;

	while ( currentComment && 
		(currentComment->statementOffset <= ct->statementCharNo) )
		{if (currentComment->commentType == ENCT_END_OF_LINE)
			{write (handle, (void *)(currentComment->text), 
					currentComment->length); 
			}
		else
			{if (colNo)
				write (handle, (void *)&newLine, 1);
			write (handle, (void *) (currentComment->text), currentComment->length);
			}
		colNo = 0;
		commentWritten = 1;
		write (handle, (void *)&newLine, 1);
		currentComment= currentComment->nextComment;
		}	/* while there are comments before current token */
	if (commentWritten)
		{commentWritten = 0;
		colNo = 6;
		write (handle, (void *) firstCols, 6);
		outNo = 6;
		}
	ct2=ct;
	effectiveTokenSize = 0;
l4:
	effectiveTokenSize += ct2->tokenSize;
	if ( ct2->printWithNextToken)
		{ct2 = ct2->next;
		if ( ct2)
			goto l4;
		}
	if ( (colNo>6) && ((effectiveTokenSize+colNo) >= 72) )
		{write (handle, (void *) &newLine, 1);
		write (handle, (void *) firstCols, 6);
		colNo = 6 + indents;
		if (level && (ct->number!=STRING_ELEMENT))
			write (handle, (void *) blanks, indents);
		}
l6:
	colNo += ct->tokenSize;
	outNo = write (handle, (void *) (ct->token), ct->tokenSize);
	if ( ( !ct->tokenSize) || (ct->printWithNextToken) )
		{ct = ct->next;
		if (ct)
			goto l6;
		}
	}	/* for each token in statement */
if (currentComment && (currentComment->commentType == ENCT_END_OF_LINE) )
	{write (handle, (void *)currentComment->text, currentComment->length);
	write (handle, (void *) &newLine, 1);
	outNo = 0;
	currentComment = currentComment->nextComment;
	}
if (outNo)
	write (handle, (void *) &newLine, 1);

l8:

/* Now write any comments that remain after the entire statement
   has been written to the output file
*/
for (	; currentComment;	currentComment = currentComment->nextComment)
	{write (handle, (void *) (currentComment->text), currentComment->length);
	write (handle, (void *) (&newLine), 1);
	}
return;
}

/* ****************************** reassignToken **************************** */
void reassignToken (YACC_SYMBOL *tok, char *newText)
{
int		i,
		newLength;

newLength = strlen (newText);
i = newLength-tok->tokenSize;
if (i>0)
	heapAlloc (&tokenHeap, i);
else if (i<0)
	heapFree (&tokenHeap, i);
strcpy (tok->token, newText);
tok->tokenSize = newLength;
return;
}

/* ****************************** returnTok **************************** */
int	returnTok (int token)
{
currentSymbol->number = token;
return token;
}

/* **************************** retIgnore ******************************* */
int retIgnore (void)
{
heapFree (&tokenHeap, yyleng + sizeof (USER_HEAP) );
currentSymbol = previousSymbol;
previousSymbol = 0;
return IGNORE_THIS_TOKEN;
}

/* ********************** serializeNextToken ******************** */
char	*serializeNextToken (TOKEN_ACCESS_CONTROL *control)
{char		retVal;

l2:

if (control->remainingChars)
	{--(control->remainingChars);
	return (control->nextChar)++;
	}
if ( !control->currentToken)
	return 0;
control->currentToken = control->currentToken->next;
if (  !control->currentToken)
	return 0;
control->nextChar = control->currentToken->token;
control->remainingChars = control->currentToken->tokenSize;
goto l2;
}

/* ******************** substituteTokenText ************************* */
YACC_SYMBOL *substituteTokenText (YACC_SYMBOL *tok, char * newText)
{
int			i;
YACC_SYMBOL	*newTok;

i = strlen (newText);
newTok = (YACC_SYMBOL *) heapAlloc (&tokenHeap, i+sizeof(YACC_SYMBOL));
newTok->number = tok->number;
newTok->statementCharNo = tok->statementCharNo;
newTok->printWithNextToken = tok->printWithNextToken;
strcpy (newTok->token, newText);
newTok->tokenSize = i;
newTok->next = tok->next;
newTok->last = tok->last;
return newTok;
}

/* ***************************** writeDependencyInfo *********************** */
void writeDependencyInfo (char *fortranFileName, char *info)
{int		outCount;
char		*pch1,
			*pch2;

if ( !generateMakeDependencies)
	return;
if ( !dependencyCharsOnCurrentLine)
	{pch1 = (char *) malloc (sizeof (fortranFileName) + 1);
	strcpy (pch1, fortranFileName);
	pch2 = strrchr (pch1, '.');
	if (pch2)
		strcpy (pch2, ".o");
	outCount = fprintf (makeDependencyFile, "%s: ", pch1);
	dependencyCharsOnCurrentLine = outCount;
 	free ((char *) pch1);
	}
if ( (dependencyCharsOnCurrentLine + strlen(info))>78 )
	{dependencyCharsOnCurrentLine = 4;
	fprintf (makeDependencyFile, "\\n\n   ");
	}
dependencyCharsOnCurrentLine += fprintf (makeDependencyFile, " %s", info);
return;
}
