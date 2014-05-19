#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>
#include "userHeap.h"
#include "convert.h"
#include "symbolManagement.h"
#include "convertUtils.h"
#include "parser.h"

#define EXTERN extern
#include "externalVariables.h"

#define GLOBAL_COMMON_HEAP_SIZE 200000
#define LOCAL_COMMON_HEAP_SIZE 200000
#define PROCEDURE_LIST_HEAP_SIZE 500000
#define LOCAL_VARIABLES_HEAP_SIZE 400000

SYMBOL_LIST_CONTROL globalCommon;
SYMBOL_LIST_CONTROL localCommon;
SYMBOL_LIST_CONTROL procedureList;
SYMBOL_LIST_CONTROL localVariables;

char globalCommonMem[GLOBAL_COMMON_HEAP_SIZE];
char localCommonMem[LOCAL_COMMON_HEAP_SIZE];
char procedureListMem[PROCEDURE_LIST_HEAP_SIZE];
char localVariablesMem[LOCAL_VARIABLES_HEAP_SIZE];

/* ***************************** addProcedure ***************************** */
VARIABLE_DEFINITION *addProcedure (YACC_SYMBOL *proc, YACC_SYMBOL *args)
{
VARIABLE_DEFINITION		localVar,
						*plv,
						**pv;
ARGUMENT_DEFINITION		*currentArgV,
						*newArg;
int						argIndex,
						newA,
						notFound;
YACC_SYMBOL				*currentArgS;

plv = &localVar;
memset ( (void *) plv, 0, sizeof (localVar));
localVar.name = proc->token;
pv = bsearchOB (&notFound, (void *) (&plv), procedureList.list, 
	procedureList.assignedPointers, sizeof (void *), compareVariables);
if ( !notFound)
	return *pv;
localVar.name = heapAlloc (&(procedureList.symbols), strlen (proc->token) + 1);
strcpy (localVar.name, proc->token);
pv = (VARIABLE_DEFINITION **) insertSymbol (&procedureList, (void **) pv,
	plv, sizeof (VARIABLE_DEFINITION), notFound);
initializeVariable (*pv);
(*pv)->type = ENVT_FUNCTION;
/* The name of the procedure is now in procedureList.  Next process the
	argument list
*/
for (currentArgS=args, currentArgV=0, argIndex=0
	;	currentArgS;	currentArgS=currentArgS->argListLink, ++argIndex)
	{
	newArg = (ARGUMENT_DEFINITION *) heapAlloc (&(procedureList.symbols),
		sizeof (ARGUMENT_DEFINITION));
	if (currentArgV)
		currentArgV->next = newArg;
	else
		(*pv)->argumentOrCommonLink = (void *) newArg;
	if (currentArgS->variableType & ENVT_DEFAULT_PARAM)
		newArg->variableType = ENVT_DEFAULT_PARAM;
	else
		{newArg->arithType = currentArgS->arithType;
		newArg->arithSize = currentArgS->arithSize;
		newArg->firstCharIndex = tolower( *(currentArgS->token) ) - 'a';
		newArg->dimension = currentArgS->dimensionLink;
		newArg->storageClass = currentArgS->storageClass;
		}
	currentArgV = newArg;
	newArg->next = 0;
	}
return *pv;
}

/* ************************* allocLocalMem ************************* */
char * allocLocalMem (int size)
{char *rv;
rv =  heapAlloc (&(localVariables.symbols), size);
memset ((void *)rv, 0, size);
return rv;
}

/* ************************* allocProcedureMem ************************* */
char * allocProcedureMem (int size)
{char *rv;
rv =  heapAlloc (&(procedureList.symbols), size);
memset ((void *)rv, 0, size);
return rv;
}

/* *************************** applyImplicit ****************************** */
void applyImplicit (void)
{
int			i;
VARIABLE_DEFINITION		**ppv,
						*pv;
ARGUMENT_DEFINITION		**ppa,
						*pa;
VARIABLE_TYPE			*pt;

for (ppv=(VARIABLE_DEFINITION **)(localVariables.list), i=localVariables.assignedPointers;
	i;	--i, ++ppv)
	{pv = *ppv;
	if ( pv->storageClass & ENSC_EXPLICIT_TYPE)
		continue;
	pt = implicitType + tolower( *(pv->name)) - 'a';
	pv->arithType = pt->type;
	pv->variableSize = pt->size;
	}
if ( !currentProcedureVar)
	return;
pa = (ARGUMENT_DEFINITION *)(currentProcedureVar->argumentOrCommonLink);
while (pa)
	{pt = implicitType + pa->firstCharIndex;
	pa->arithType = pt->type;
	pa->arithSize = pt->size;
	pa = pa->next;
	}
return;
}

/* ************************* argumentCountError *************************** */
void argumentCountError (YACC_SYMBOL *ps)
{
char			work[200];
int				i;


i = sprintf (work, "%s:  ", currentFileName);
i += sprintf (work+i, "line # %d, bad argument count in use of %s\n", 
  lineNo, ps->token);
work[i] = 0;
fprintf (errorFile, work);
printf (work);
return;
}

/* **************************** argumentError ***************************** */
void argumentError (YACC_SYMBOL * ps, int argNum)
{
char		work[200];
int			i;

i = sprintf (work, "%s: ", currentFileName);
i += sprintf (work+i, "Line %d - error in use of parameter %d in procedure %s\n",
	lineNo, argNum, ps->token);
work[i] = 0;
fprintf (errorFile, work);
printf (work);
return;
}

/* **************************** checkDimensions ************************** */
int checkDimensions (VARIABLE_DEFINITION *pv, YACC_SYMBOL *pa)
{DIMENSION_DEFINITION	*pdd1,
						*pdd2;
int						i;

for (i=0, pdd1=pv->dimension, pdd2=pa->dimensionLink;	pdd1 && pdd2;
	pdd1=(DIMENSION_DEFINITION *)(pdd1->nextDim), pdd2=(DIMENSION_DEFINITION *)(pdd2->nextDim), ++i)
	{if ( (pdd1->size != pdd2->size) && pdd1->nextDim && pdd2->nextDim)
		return 1;
	}
if (pdd1 || pdd2)
	return 1;
return 0;
}

/* *************************** checkProcedureArgs *************************** */
void checkProcedureArgs (YACC_SYMBOL *ps, YACC_SYMBOL *pa, 
	VARIABLE_DEFINITION *pv)
{
YACC_SYMBOL		*ps1;
ARGUMENT_DEFINITION	*pa2;
int					i;
		
for (i=0, ps1=pa, pa2 = (ARGUMENT_DEFINITION *) (pv->argumentOrCommonLink);
	ps1 && pa2;	ps1=ps1->argListLink, pa2=pa2->next, ++i)
	{if (ps1->variableType == ENVT_DEFAULT_PARAM)
		continue;
	if ( targetSystem==ENTS_VAX && pa2->arithType==ENAT_BYTE && ps1->arithType==ENAT_CHAR)
		continue;
	if (pa2->variableType == ENVT_DEFAULT_PARAM)
		{
		pa2->arithType = ps1->arithType;
		pa2->arithSize = ps1->arithSize;
		continue;
		}
	if ( (ps1->arithType==ENAT_CHAR) && (pa2->arithType==ENAT_CHAR) )
		continue;
	if ( (ps1->arithType == pa2->arithType) && 
			(ps1->arithSize == pa2->arithSize) )
		continue;
	/* if the target is little endian it is legal to call an int*2 formal
		argument with an int*4 actual argument if the value is small enough */
	if (littleEndian && (ps1->arithType==ENAT_INT) && 
		(pa2->arithType== ENAT_INT) )
		{if ( (ps1->arithSize==4) && (pa2->arithSize==2) )
			if ( ((ps1->number==INTEGER_CONSTANT)||(ps1->storageClass&ENSC_PARAMETER) )
				&& !(ps1->constantValue&0xffff0000) )
				continue;
		}
		{argumentError (ps, i);
		return;
		}
	}	/* for each argument */
if (ps1 || pa2)
	argumentCountError (ps);
return;
}

/* ************************* commonBlockError ********************* */
void commonBlockError (COMMON_DEFINITION *pc, int offset)
{
char		*pch;
int			i;

pch = errorInit ();
pch  += sprintf (pch, "Inconsistent COMMON declaration at offset %d in ",
	offset);
if ( *(pc->name) )
	pch += sprintf (pch, "block %s.\n", pc->name);
else
	pch += sprintf (pch, "BLANK common.\n");
errorWrite ();
return;
}

/* ************************* compareCommonBlocks ********************* 
	for each common block in the local common determine whether the
	common regions match the corresponding block in the global
	common.  If the local block is longer than the global, add the
	extra items to the global block
*/
void compareCommonBlocks (void)
{
int						offset,
						remainingBlocks;
COMMON_REGION			*prg,
						*prg2,
						*prl;	/* glogal and local COMMON_REGION */
COMMON_DEFINITION		*pcl,
						**ppcl,
						*pcg;

remainingBlocks = localCommon.assignedPointers;
ppcl = (COMMON_DEFINITION **) (localCommon.list);
/* for each local common block*/
for (	;	remainingBlocks;	--remainingBlocks, ++ppcl)
	{
	pcl = *ppcl;
	pcg = processCommonBlock (pcl->name, 1);
	for (offset=0, prg=pcg->list, prl=pcl->list;
			prg && prl;
			prg=prg->next, prl=prl->next
		)
		{if (pcg->inconsistentDeclaration)
			goto l5;
		if ( ((prg->type) != (prl->type))
				||  (prg->variableSize != prl->variableSize) )
			{pcg->inconsistentDeclaration = 1;
			commonBlockError (pcg, offset);
			goto l5;
			}
		if (prg->variableCount == prl->variableCount)
			{int		size;
			
			size=prl->variableSize*prl->variableCount;
			if ( (prl->type==ENAT_COMPLEX) ||(prl->type==ENAT_DOUBLE_COMPLEX) )
				size += size;
			offset += size;
			continue;
			}
		if ( (prg->variableCount > prl->variableCount) && !prl->next)
			{prl = prl->next;
			break;
			}
		if ( (prg->variableCount<prl->variableCount) && !prg->next)
			{prg->variableCount = prl->variableCount;
			prl = prl->next;
			break;
			}
		pcg->inconsistentDeclaration = 1;
		commonBlockError (pcg, offset);
		goto l5;
		}	/* for each region in the block */
	while ( prl)
	/* Add the regions at the end of the local block to the global block */
		{prg2 = (COMMON_REGION *) heapAlloc (&(globalCommon.symbols),
			sizeof (COMMON_REGION) );
		memcpy ( (void *) prg2, (void *) prl, sizeof (COMMON_REGION) );
		prg2->next = 0;
		if (prg)
			prg->next = prg2;
		else
			pcg->list = prg2;
		prg = prg2;
		prl = prl->next;
		pcg->last = prg2;
		}	/* while there are more local regions */
l5:
	continue;
	}	/* for each local common block */
return;
}

/* ******************************* compareVariables *********************** */
int compareVariables (const void *v1, const void *v2)
{
return strcmp ( (*((VARIABLE_DEFINITION **)v1))->name, 
	(*((VARIABLE_DEFINITION **)v2))->name);
}

/* *************************** defaultVariableSize ************************* */
int defaultVariableSize (EN_ARITH_TYPE at)
{VARIABLE_TYPE		*pv;


for (pv=defaultVariableSizeArray;	pv->size;	++pv)
	{if (pv->type == at)
		return pv->size;
	}
printf ("Illegal Arith type specified\n");
exit (1);
return 0;	/* just avoid a warning */
}

/* **************************** defineProcedure**************************** */
void defineProcedure (YACC_SYMBOL *proc, VARIABLE_DEFINITION *arg)
{
int			i,
			j,
			newProc;
VARIABLE_DEFINITION		localVar,
						*plv,
						**ppprocVar,
						**procVar,
						*pv;
ARGUMENT_DEFINITION		*parg1,
						**pparg;
char					*errMsg;

procVar = findProcedure (proc->token, &newProc);
if ( !newProc)
	{if ((*procVar)->storageClass & ENSC_PROC_DEFINED)
		{errMsg = errorInit();
		errMsg += sprintf (errMsg, "Procedure %s has been refedined\n",
			proc->token);
		errorWrite ();
		return;
		}
	/*	Does this definition have the same number of arguments as prior 
		declaration? */
	for (i=0, pv=arg;	pv;	pv = (VARIABLE_DEFINITION*)(pv->argumentOrCommonLink))
		++i;
	for (j=0,	parg1=(ARGUMENT_DEFINITION *) ((*procVar)->argumentOrCommonLink); parg1;
			parg1 = parg1->next)
		++j;
	if (i != j)
		{errMsg = errorInit ();
		errMsg += sprintf (errMsg, "Redefined number of arguments in procedure %s\n",
			proc->token);
		errorWrite ();
		ppprocVar = procVar;
		goto l4;
		}
	for (parg1=(ARGUMENT_DEFINITION *) ((*procVar)->argumentOrCommonLink),
			pv = arg, i=0;	pv && parg1;
			parg1=parg1->next, pv=(VARIABLE_DEFINITION *)(pv->argumentOrCommonLink), ++i)
		{if ( (parg1->arithType==pv->arithType) && (parg1->arithSize==pv->variableSize) )
			continue;
		if (parg1->storageClass & ENVT_DEFAULT_PARAM)
			{parg1->arithType =pv->type;
			parg1->arithSize = pv->variableSize;
			continue;
			}
		errMsg = errorInit ();
		
		errMsg += sprintf (errMsg, "Argument specification is inconsistent\n");
		errorWrite ();
		}
	return;
	}	/* previous module has declared this procedure */
plv = &localVar;
memset ((void *)plv, 0, sizeof(localVar));
localVar.name = heapAlloc (&(procedureList.symbols), strlen (proc->token) + 1);
strcpy (localVar.name, proc->token);
localVar.type = proc->variableType;
localVar.arithType = proc->arithType;
localVar.storageClass = proc->storageClass;
localVar.variableSize = proc->arithSize;

ppprocVar = (VARIABLE_DEFINITION **) insertSymbol( &procedureList,
	(void**) procVar, plv, sizeof (VARIABLE_DEFINITION), newProc);

l4:

(*ppprocVar)->storageClass |= ENSC_PROC_DEFINED;
pparg = (ARGUMENT_DEFINITION **)(&((*ppprocVar)->argumentOrCommonLink));
for (pv=arg;	pv;	pv=(VARIABLE_DEFINITION *)(pv->argumentOrCommonLink))
	{DIMENSION_DEFINITION		*pdim1,
								*pdim2,
								**ppdim;
	
	parg1 = (ARGUMENT_DEFINITION *) heapAlloc(&(procedureList.symbols),
			sizeof (ARGUMENT_DEFINITION));
	*pparg = parg1;
	pparg = &(parg1->next);
	parg1->variableType = pv->type;
	parg1->arithType = pv->arithType;
	parg1->arithSize = pv->variableSize;
	parg1->firstCharIndex = tolower ( *(pv->name)) - 'a';
	
	pdim1 = pv->dimension;
	ppdim = &(parg1->dimension);
	while (pdim1)
		{pdim2 = (DIMENSION_DEFINITION *)allocProcedureMem (sizeof(DIMENSION_DEFINITION));
		*pdim2 = *pdim1;
		pdim2->nextDim = 0;
		*ppdim = pdim2;
		ppdim = (DIMENSION_DEFINITION **)(&(pdim2->nextDim));
		pdim1 = (DIMENSION_DEFINITION *) (pdim1->nextDim);
		}
	parg1->storageClass = pv->storageClass;
	}
return;
}

/* ************************* defineSimpleDimension ************************** */
DIMENSION_DEFINITION *defineSimpleDimension (int size)
{DIMENSION_DEFINITION *rv;

rv = (DIMENSION_DEFINITION *) allocLocalMem (sizeof (DIMENSION_DEFINITION));
rv->size = size;
rv->lowerBound = 1;
return rv;
}

/* ************************* defineComplexDimension ************************* */
DIMENSION_DEFINITION *defineComplexDimension (int first, int last)
{DIMENSION_DEFINITION *rv;

rv = (DIMENSION_DEFINITION *) allocLocalMem (sizeof (DIMENSION_DEFINITION));
rv->size = last - first + 1;
rv->lowerBound = first;
return rv;
}

/* **************************** findProcedure ***************************** */
VARIABLE_DEFINITION **findProcedure (char *name, int *notFound)
{
VARIABLE_DEFINITION		localVar,
						*plv,
						**pv;

plv = &localVar;
localVar.name = name;
pv =  bsearchOB(notFound, (void *) (&plv), procedureList.list, 
		procedureList.assignedPointers, sizeof(void*), compareVariables);
if ( !pv)
	return 0;
return pv;
}
/* ************************** getParameterValue ************************* */
int	getParameterValue (YACC_SYMBOL *ps)
{VARIABLE_DEFINITION	localV,
						*plv,
						**ppv;
int						notFound,
						retVal;

localV.name = ps->token;
plv = &localV;
ppv = bsearchOB( &notFound, (void *) &plv, localVariables.list, 
	localVariables.assignedPointers, sizeof (void *), compareVariables);
if ( !notFound)
	retVal =  (*ppv)->constantValue;
else	/* something REAL bad has happened if we get here */
	retVal = 0;
ps->constantValue = retVal;
return retVal;
}

/* ************************* getVariableValueCount ************************** */
int getVariableValueCount (VARIABLE_DEFINITION *pv)
{int	size;
DIMENSION_DEFINITION *pdim;

size = 1;
pdim = pv->dimension;
while (pdim)
	{size *= pdim->size;
	pdim = (DIMENSION_DEFINITION *)pdim->nextDim;
	}
return size;
}

/* *********************** initAllSymbols **************************** */
void initAllSymbols (void)
{
initSymbols (&globalCommon, 
	globalCommonMem, GLOBAL_COMMON_HEAP_SIZE);
initSymbols (&localCommon, 
	localCommonMem, LOCAL_COMMON_HEAP_SIZE);
initSymbols (&procedureList, 
	procedureListMem, PROCEDURE_LIST_HEAP_SIZE);
initSymbols (&localVariables, 
	localVariablesMem, LOCAL_VARIABLES_HEAP_SIZE);

}

/* ************************* initSymbols *************************** */
void	initSymbols (SYMBOL_LIST_CONTROL *control, 
		char *heapMem, int heapSize)
{
if (control->list)
	free ((void *)control->list);
heapInit (&(control->symbols), heapSize, heapMem);
control->list = 0;
control->remainingPointers = 0;
control->totalPointers = 0;
}

/* *************************** insertSymbol ************************** */
void	**insertSymbol (SYMBOL_LIST_CONTROL *control, void **insertionPoint,
	void *symbol, int symbolSize, int notFound)
{int			i,
				j;
void			**ppv;
int				insertAfter;

insertAfter = notFound>0?	1:	0;
if ( !control->remainingPointers)
	{int	insertionIndex;
	
	insertionIndex = (char **) insertionPoint - (char **)(control->list);
	control->remainingPointers += 30;
	control->totalPointers += 30;
	if (control->list)
		control->list = (void **)realloc ((void *)control->list, 
					control->totalPointers * sizeof (void *));
	else
		{control->list = (void **)malloc (control->totalPointers * sizeof (void *));
		}
	if ( !(control->list) )
		{printf( "realloc failed in insertSymbol\n");
		exit (1);
		}
	insertionPoint = (void **) ((char **)(control->list) + insertionIndex);
	}
if ( !control->assignedPointers)
	insertAfter = 0;
j = control->assignedPointers - (insertionPoint-control->list);
ppv=control->list+control->assignedPointers;
if (insertAfter)
	{--j;
	++insertionPoint;
	}
for (i=0;	j;	--j, --ppv)
	*ppv = *(ppv-1);
++control->assignedPointers;
--control->remainingPointers;
*insertionPoint = (void *) heapAlloc (&(control->symbols), symbolSize+1);
memcpy (*insertionPoint, symbol, symbolSize);
return insertionPoint;
}

/* **************************** processCommonBlock *********************** */
COMMON_DEFINITION * processCommonBlock (char *blockName, int useGlobalArea)
{SYMBOL_LIST_CONTROL	*control;
void					**entry;
int						symbolNotFound;
COMMON_DEFINITION		def,
						*pdef;

control = useGlobalArea ? &globalCommon : &localCommon;
memset ((void *) &def, 0, sizeof (COMMON_DEFINITION));
def.name = blockName;
pdef = &def;
entry = bsearchOB (&symbolNotFound, (void *) (&pdef), control->list,
		control->assignedPointers, sizeof (void *), compareCommonNames);

if ( symbolNotFound)
	{
	pdef = &def;
	def.name = heapAlloc ( &(control->symbols), strlen (blockName) + 1);
	strcpy (def.name, blockName);
	entry = insertSymbol (control, entry, &def, 
		sizeof(COMMON_DEFINITION), symbolNotFound);
	}
return (COMMON_DEFINITION *)(*entry);
}

/* **************************** processCommonList ************************ */
void processCommonList (YACC_SYMBOL *ps)
{char			*name;
YACC_SYMBOL		*ps2;
COMMON_DEFINITION	*pblock;
VARIABLE_DEFINITION	*pv;
int				newVar;

while (ps)
	{ps2 = ps->next;
	if ( !ps2)
		break;
/*	Blank common can start at the beginning of the COMMON statement
	with no common name designator, or it can start with consecutive 
	slashes.  The following tests will process both cases.
*/
	if ( (ps->number!=SLASH) || (ps2->number == SLASH) )
		{if (ps2->number == SLASH)
			{ps = ps2->next;
			if ( !ps)
				break;
			}
		ps = ps->next;
		if ( !ps)
			break;
		name = "";
		}
	else
		{name = ps2->token;
		ps = ps2->next;
		if ( !ps)
			break;
		ps = ps->next;
		}
/*	At this point name is the name of a common block and ps points to
	the start of the variables in that block which this statement declares.
	Process each symbol until either a new common block is encountered,
	or the end of the statement is reached
*/
	pblock = processCommonBlock (name, 0);
	while (ps)
		{if (ps->number == SLASH)
			break;
		if (ps->number == L_PAREN)
			{while (ps->next)
				{ps = ps->next;
				if (ps->number == R_PAREN)
					break;
				}
			}
		if (ps->number == VARIABLE_NAME)
			{pv = processLocalSymbol (ps, &newVar);
			processCommonSymbol (pblock, &localCommon, pv);
			}
		ps = ps->next;
		}
	}	/* while there are items in COMMON list */
}

/* **************************** processCommonSymbol ********************** */
void	processCommonSymbol (COMMON_DEFINITION *block, 
	SYMBOL_LIST_CONTROL *control, VARIABLE_DEFINITION *symbol)
{COMMON_REGION		*pr1;
int					commonOffset,
					totalSize;
DIMENSION_DEFINITION	*pdim;

totalSize = 1;
pdim = symbol->dimension;
while (pdim)
	{totalSize *= pdim->size;
	pdim = (DIMENSION_DEFINITION *)pdim->nextDim;
	}
if ( !(block->last) )
	{pr1 = (COMMON_REGION *)heapAlloc (&(control->symbols), 
			sizeof (COMMON_REGION) );
	pr1->type = symbol->arithType;
	pr1->variableSize = symbol->variableSize;
	pr1->variableCount = totalSize;
	block->list = pr1;
	block->last = pr1;
	return;
	}
commonOffset = (block->last)->commonBlockOffset + 
		(block->last)->variableSize*(block->last)->variableCount;
symbol->commonOffset = commonOffset;
pr1 = block->last;
/*	if both current variable and the current comment block are of same type
	and ((the type is char) or the variable sizes are equal) 
*/
if ( (pr1->type==symbol->arithType) && 
	( (symbol->arithType==ENAT_CHAR) ||
	(pr1->variableSize==symbol->variableSize)) )
	{
	pr1->variableCount += totalSize;
	}
else
	{COMMON_REGION 			*pr2;
	pr2 = (COMMON_REGION *)heapAlloc (&(control->symbols), 
		sizeof (COMMON_REGION) );
	pr2->type = symbol->arithType;
	pr2->variableSize = symbol->variableSize;
	pr2->variableCount = totalSize;
	pr2->next = 0;
	block->last = pr2;
	pr1->next = pr2;
	}
}

/* ********************* processGlobalCommonBlock ************************ */
/*	Process the common statement defined by the *COMMON statements.  
	name is the name of the common block.  Each entry in the pvar linked
	list has its argListLink set to a COMMON_REGION *.
*/
void processGlobalCommonBlock (char *name, YACC_SYMBOL *pvar)
{COMMON_DEFINITION  *pcd;
COMMON_REGION       *firstRegion,
					*currentRegion,
					*nextRegion,
					*pcr;

/* link the COMMON_REGION structures */
firstRegion = (COMMON_REGION *) (pvar->argListLink);
currentRegion = firstRegion;
while (pvar = pvar->next)
	{nextRegion = (COMMON_REGION *) (pvar->argListLink);
	currentRegion->next = nextRegion;
	currentRegion = nextRegion;
	}
pcd = processCommonBlock (name, 1);
if (pcd->list)
    {pcd->last->next = firstRegion;
	pcd->last = currentRegion;
	}
else
	{pcd->last = currentRegion;
    pcd->list = firstRegion;
	}
}

/* *************************** processLocalSymbol **************************
	Search localVariablesHeap.
	If found, return the VARIABLE_DEFINITION pointer.  Otherwise add
	pys to localVariablesHeap 
*/
VARIABLE_DEFINITION *processLocalSymbol (YACC_SYMBOL * pys, int *newVar)
{VARIABLE_DEFINITION	localVar,
						*plv,
						**tableVar;
int						notFound;

*newVar = 1;
memset ((void *)(&localVar), 0, sizeof(VARIABLE_DEFINITION) );
localVar.name = pys->token;
plv = &localVar;
tableVar = bsearchOB (&notFound, (void *)&plv, localVariables.list, 
	localVariables.assignedPointers, sizeof (void *), compareVariables);
if ( !notFound)
	{pys->arithType = (*tableVar)->arithType;
	pys->arithSize = (*tableVar)->variableSize;
	pys->variableType = (*tableVar)->type;
	pys->constantValue = (*tableVar)->constantValue;
	pys->storageClass = (*tableVar)->storageClass;
	*newVar = 0;
	return *tableVar;
	}

localVar.name = heapAlloc (&(localVariables.symbols), 
	strlen(pys->token)+1);
strcpy (localVar.name, pys->token);
tableVar = (VARIABLE_DEFINITION **)	insertSymbol (&localVariables, 
	(void **)tableVar, plv, sizeof (VARIABLE_DEFINITION), notFound );
if ( !(pys->arithType))
	{initializeVariable (*tableVar);
	pys->arithType = (*tableVar)->arithType;
	pys->arithSize = (*tableVar)->variableSize;
	pys->variableType = (*tableVar)->type;
	}
else
	{(*tableVar)->arithType = pys->arithType;
	(*tableVar)->variableSize = pys->arithSize;
	(*tableVar)->type = pys->variableType;
	(*tableVar)->storageClass = pys->storageClass;
	}
/* a do-nothing loop loop which allows the debugger to show the results of the insertion */
	{VARIABLE_DEFINITION	**dummy;
	int						i;
	for (dummy=(VARIABLE_DEFINITION **)(localVariables.list), i=0;
			i<localVariables.assignedPointers;	++i)
		++dummy;
	}
return *tableVar;
}

/* ************************* processParameterItem *********************** */
void processParameterItem (YACC_SYMBOL *parameter, YACC_SYMBOL *value,
		int useImplicit)
{
VARIABLE_DEFINITION		*pv;
int						newVar;

pv = processLocalSymbol (parameter, &newVar);
pv->storageClass |= ENSC_PARAMETER;
if (value->number == VARIABLE_NAME)
	pv->constantValue = getParameterValue (value);
else
	pv->constantValue = value->constantValue;
parameter->constantValue = pv->constantValue;
if ( !newVar)
	return;
if (useImplicit)
	{VARIABLE_TYPE	*pt;
	
	pt = implicitType + tolower (*(parameter->token)) - 'a';
	pv->arithType = pt->type;
	pv->variableSize = pt->size;
	}
else
	{pv->arithType = value->arithType;
	pv->variableSize = value->arithSize;
	}
return;
}

/* *************************** processParenRef *************************** */
VARIABLE_DEFINITION	*processParenRef (YACC_SYMBOL *ps, YACC_SYMBOL *pa)
{VARIABLE_DEFINITION	*pv,
						**ppv;
int						newVar;

ppv = findProcedure (ps->token, &newVar);
if (ppv)
	pv = *ppv;
else
	pv = 0;
if ( !newVar)
	{checkProcedureArgs (ps, pa, pv);
	ps->arithSize = pv->variableSize;
	ps->arithType = pv->arithType;
	return pv;
	}
pv = processLocalSymbol (ps, &newVar);
if ( !newVar && (pv->type==ENVT_DIMENSIONED_VAR) )
	{checkDimensions (pv, pa);
	return pv;
	}
pv = addProcedure (ps, pa);
return pv;
}

/* ************************* processTypeList **************************** */
void processTypeList (YACC_SYMBOL *plist, YACC_SYMBOL *ptype)
{YACC_SYMBOL		*ps;
VARIABLE_DEFINITION	*pv;
int					newVar;

if ( !(ptype->arithSize))
	{ /* use default size for type  */
	ptype->arithSize = defaultVariableSize (ptype->arithType);
	}
for (ps = plist;	ps;	ps=ps->next)
	{if (ps->number != VARIABLE_NAME)
		continue;
	pv = processLocalSymbol (ps, &newVar);
	pv->arithType = ptype->arithType;
	pv->variableSize = ptype->arithSize;
	if ( (pv->storageClass & ENSC_DUMMY_VARIABLE) && currentProcedureVar)
		{int		i;
		ARGUMENT_DEFINITION * pa;
		
		for (i=0, 
		pa = (ARGUMENT_DEFINITION *)(currentProcedureVar->argumentOrCommonLink);
			i<pv->constantValue;	++i, pa=pa->next)
			;	/* nothing */
		if ( !pa)
			continue;	/* THIS SHOULD NOT HAPPEN */
		pa->arithType = ptype->arithType;
		pa->arithSize = ptype->arithSize;
		}
	}
return;
}

/* *********************** resetLocalSymbols ************************** */
void resetLocalSymbols (void)
{

resetSymbols (&localCommon);
resetSymbols (&localVariables);
}

/* ****************************** resetSymbols ***************************** */
void resetSymbols (SYMBOL_LIST_CONTROL *control)
{
control->assignedPointers = 0;
control->remainingPointers = control->totalPointers;
heapFree (&(control->symbols), 0);
}

/* ****************************** setVarsDummy ***************************** */
void setVarsDummy (YACC_SYMBOL *pys)
{int					newVar,
						i;
VARIABLE_DEFINITION		*pvar;

for (i=0;	pys;	++i, pys=pys->argListLink)
	{pys->storageClass |= ENSC_DUMMY_VARIABLE;
	pvar = processLocalSymbol (pys, &newVar);
	pys->constantValue = i;
	pvar->storageClass |= ENSC_DUMMY_VARIABLE;
	pvar->constantValue = i;
	}
return;
}

typedef struct _TYPE_CONVERT
	{EN_ARITH_TYPE	arithType;
	char			*typeName;
	} TYPE_CONVERT;

TYPE_CONVERT	typeConvert[] = 
	{ENAT_BYTE,			"BYTE",
	ENAT_CHAR,			"CHAR",
	ENAT_LOGICAL,		"LOGICAL",
	ENAT_REAL,			"REAL",
	ENAT_DOUBLE,		"DOUBLE",
	ENAT_COMPLEX,		"COMPLEX",
	ENAT_DOUBLE_COMPLEX,	"DOUBLECOMPLEX",
	ENAT_INT,			"INTEGER",
	ENAT_ALTERNATE_RETURN,	"ALTERNATE_RETURN",
	0,					0
	};

/* **************************** translateType *************************** */
char	*translateType (EN_ARITH_TYPE	type)
{
TYPE_CONVERT	*ptc;

for (ptc=typeConvert;	ptc->arithType;	++ptc)
	{if (ptc->arithType == type)
		return ptc->typeName;
	}
return 0;
}

/* ***************************** typeToInternal ************************** */
EN_ARITH_TYPE typeToInternal (char *pt)
{
TYPE_CONVERT		*pc;

for (pc = typeConvert;	pc->typeName;	++pc)
	{if ( !strcmp (pc->typeName, pt))
		return pc->arithType;
	}
return 0;
}

/* ****************************** writeGlobals ************************** */
void writeGlobals (void)
{
FILE		*outH;
int		columnsWritten,
		i,
		j,
		k;
VARIABLE_DEFINITION		*pv,
						**ppv;
ARGUMENT_DEFINITION		*pa;
DIMENSION_DEFINITION	*pd;
COMMON_DEFINITION		*pcd,
						**ppcd;
COMMON_REGION			*pcr;

outH = fopen ("V2U.globalSymbols", "w");
for (i=0, ppv=(VARIABLE_DEFINITION **) (procedureList.list);
	i<procedureList.assignedPointers;
	++i, ++ppv
	)
	{pv = *ppv;
	pa = (ARGUMENT_DEFINITION *) (pv->argumentOrCommonLink);
	if (pv->type == ENVT_FUNCTION)
		{columnsWritten =fprintf (outH, "      *FUNCTION %s*%s*%d (", 
			pv->name, translateType (pv->arithType), pv->variableSize);
		}
	else	/* subroutine */
		{columnsWritten = fprintf (outH, "      *SUBROUTINE %s(", pv->name);
		}
	while (pa)
		{if (columnsWritten > 62)
			{fprintf (outH, "\n");
			columnsWritten = fprintf (outH, "     1");
			}
		columnsWritten += fprintf (outH, "%s*%d", 
			translateType (pa->arithType), pa->arithSize);
		pd = pa->dimension;
		while (pd)
			{columnsWritten += fprintf (outH, ":%d*%d", pd->size, pd->lowerBound);
			pd = (DIMENSION_DEFINITION *)(pd->nextDim);
			}	/* for each dimension */
		pa = pa->next;
		if (pa)
			fprintf (outH, ", ");
		}	/* for each argument */
 	fprintf (outH, ")\n");
	}	/* for each procedure */
for (ppcd=(COMMON_DEFINITION **)(globalCommon.list), i=0;
	i<globalCommon.assignedPointers;	++i, ++ppcd
	)
	{pcd = *ppcd;
	columnsWritten = fprintf (outH, "      *COMMON/");
	if (*(pcd->name) )
		columnsWritten += fprintf (outH, pcd->name);
	columnsWritten += fprintf (outH, "/");
	for (pcr=pcd->list;	pcr;	pcr=pcr->next)
		{
		if (columnsWritten > 62)
			{fprintf (outH, "\n");
			columnsWritten = fprintf (outH, "     1");
			}
		columnsWritten += fprintf (outH, "%s*%d*%d ", translateType(pcr->type),
			pcr->variableSize, pcr->variableCount);
		}	/* for each region in block */
	fprintf (outH, "\n");
	}	/* for each common block */
fclose (outH);
return;
}
