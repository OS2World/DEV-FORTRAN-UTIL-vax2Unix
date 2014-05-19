#define CONFORMING_SIZE -1

typedef struct _SYMBOL_LIST_CONTROL
    {void               **list;  /* a list of COMMON_DEFINITION
									or VARIABLE_DEFINITION */
    int                 assignedPointers,
						remainingPointers,
                        totalPointers;
	USER_HEAP			symbols;
	}	SYMBOL_LIST_CONTROL;

VARIABLE_DEFINITION *addProcedure (YACC_SYMBOL *proc, YACC_SYMBOL *args);
char * allocLocalMem (int size);
char * allocProcedureMem (int size);
void applyImplicit (void);
int checkDimensions (VARIABLE_DEFINITION *pv, YACC_SYMBOL *pa);
void checkProcedureArgs (YACC_SYMBOL *ps, YACC_SYMBOL *pa, 
	VARIABLE_DEFINITION *pv);
void commonBlockError (COMMON_DEFINITION *pc, int offset);
void	compareCommonBlocks (void);
int		compareVariables (const void *v1, const void *v2);
int		defaultVariableSize (EN_ARITH_TYPE at);
DIMENSION_DEFINITION *defineComplexDimension (int first, int last);
void defineProcedure (YACC_SYMBOL *proc, VARIABLE_DEFINITION *arg);
DIMENSION_DEFINITION *defineSimpleDimension (int size);
VARIABLE_DEFINITION **findProcedure (char *name, int *notFound);
int getParameterValue (YACC_SYMBOL *ps);
int	getVariableValueCount (VARIABLE_DEFINITION *pv);
void	initAllSymbols (void);
void	initSymbols (SYMBOL_LIST_CONTROL *control, 
			char *heapMem, int heapSize);
void	**insertSymbol (SYMBOL_LIST_CONTROL *control, void **insertionPoint, 
		void *symbol, int symbolSize, int notFound);
void localCommonVariable (COMMON_DEFINITION *block, 
	VARIABLE_DEFINITION *var);
void	mergeCommonBlocks (void);
COMMON_DEFINITION *processCommonBlock (char *blockName, int useGlobalArea);
void processCommonList (YACC_SYMBOL *ps);
void	processCommonSymbol (COMMON_DEFINITION *block, 
	SYMBOL_LIST_CONTROL *control, VARIABLE_DEFINITION *symbol);
void processGlobalCommonBlock (char *name, YACC_SYMBOL *pvar);
VARIABLE_DEFINITION *processLocalSymbol (YACC_SYMBOL * pys, int *newVar);
void processParameterItem (YACC_SYMBOL *parameter, YACC_SYMBOL *value,
        int useImplicit);
void processParameterList (YACC_SYMBOL *pl, int useImplicit);
VARIABLE_DEFINITION	*processParenRef (YACC_SYMBOL *ps, YACC_SYMBOL *pa);
void processTypeList (YACC_SYMBOL *plist, YACC_SYMBOL *ptype);
void	procesCommonSymbol (COMMON_DEFINITION *block, 
	SYMBOL_LIST_CONTROL *control, VARIABLE_DEFINITION *symbol);
void	resetLocalSymbols (void);
void resetSymbols (SYMBOL_LIST_CONTROL *control);
void setVarsDummy (YACC_SYMBOL *pys);
void writeGlobals (void);
