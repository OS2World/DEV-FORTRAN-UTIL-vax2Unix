
#include "lexerState.h"

FILE_INFO	includeStack[MAX_INCLUDE_DEPTH];
int		includeDepth;
int		stateStack[MAX_STATE_DEPTH];
int		stateDepth;


/* **************************** binaryToI ****************************** */
int binaryToI (char *pch)
{int		val;

for (val=0;	*pch;	++pch)
	val = val*2 + *pch-'0';
return val;
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
		{printError ("illegal hex constant");
		return 0;
		}
	val = (val<<4) + i;
	}
return val;
}

/* **************************** newLine ***************************** */
static void newLine (void)
{
++lineNo;
return;
}

/* ******************************** popState ***************************** */
static void popState (void)
{
if (stateDepth < 1)
	{printf ("State stack underflow\n");
	exit (4);
	}
BEGIN (stateStack[--stateDepth]);
return;
}

/* ***************************** popNStates ************************* */
void popNStates (int count)
{
if stateDepth < count)
	{printf ("State stack underflow\n");
	exit (4);
	}
stateDepth -= count;
BEGIN (stateStack[stateDepth];
return;
}

/* ***************************** printError *************************** */
void printError (char *msg)
{
printf ("%s: %s on line %d\n", currentFileName, msg, lineNo);
return;
}

/* ******************************* pushFile *************************** */
void	pushFile (char *name)
{FILE		*fp;
FILE_INFO	*pfi;
int			i,
			*ps,
			*pd;

i = strlen (name);
fp = fopen (name, "r");
if ( !fp)
	{printError ("Open failure on ");
	exit (1);
	}
pfi = includeStack + includeDepth;
if (includeDepth >= MAX_INCLUDE_DEPTH)
	{printf ("Include depth exceeded\n");
	exit (1);
	}
pfi->bufferState = YY_CURRENT_BUFFER;
pfi->fileName = currentFileName;
pfi->currentLineNo = lineNo;
pfi->stateDepth = stateDepth;
for (ps=stateStack, pd=pfi->startStates, i=0;	i<stateDepth;	++ps, ++ps, ++i)
	*pd = *ps;
*pd = YY_START;
currentFileName = (char *) malloc (i+1);
strcpy (currentFileName, name);
yy_switch_to_buffer (yy_create_buffer (fp, YY_BUF_SIZE));
lineNo = 1;
++includeDepth;
}

/* ***************************** pushState ***************************** */
static void pushState (int newState)
{
if (stateDepth > (MAX_STATE_DEPTH-1) )
	{printf ("State stack overflow\n");
	exit (3);
	}
stateStack[stateDepth++] = YY_START;
BEGIN (newState);
return;
}

/* ********************************** yywrap *************************** */
static int	yywrap (void)
{FILE_INFO		*pfi;
int			i,
			*ps,
			*pd;

if (!includeDepth)
	exit (1);
--includeDepth;
pfi = includeStack+includeDepth;
free ( (void *) currentFileName);
currentFileName = pfi->fileName;
lineNo = pfi->currentLineNo;
stateDepth = pfi->stateDepth;
for (pd=stateStack, ps=pfi->startStates, i=0;	i<stateDepth;	++ps, ++ps, ++i)
	*pd = *ps;
BEGIN *ps;
yy_delete_buffer (YY_CURRENT_BUFFER);
yy_switch_to_buffer (pfi->bufferState);
return 0;
}
