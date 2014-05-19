#define COMMENT_DATA_SIZE 100000
#define TOKEN_DATA_SIZE 300000

typedef enum {ENCT_BLANK_LINE, ENCT_COMMENT_LINE, ENCT_END_OF_LINE} 
	EN_COMMENT_TYPE;

typedef enum {ENAT_UNASSIGNED, ENAT_BYTE, ENAT_CHAR, ENAT_LOGICAL, 
	ENAT_INT, ENAT_REAL, ENAT_DOUBLE, ENAT_COMPLEX,
	ENAT_DOUBLE_COMPLEX, ENAT_ALTERNATE_RETURN} EN_ARITH_TYPE;

typedef enum {ENVT_SCALAR, ENVT_DIMENSIONED_VAR, ENVT_FUNCTION, 
	ENVT_SUBROUTINE, ENVT_STATEMENT_FUNCTION, 
	ENVT_COMMON_BLOCK_NAME, ENVT_NAMELIST, 
	ENVT_STRUCTURE_NAME, ENVT_DEFAULT_PARAM} EN_VARIABLE_TYPE;

typedef enum {ENSC_STATIC=0x1, ENSC_DYNAMIC=0x2, ENSC_DUMMY_VARIABLE=0x4,
	ENSC_PARAMETER=0x8, ENSC_PROC_DEFINED=0x10,
	ENSC_EXPLICIT_TYPE=0x20}	EN_STORAGE_CLASS;

typedef enum {ENTS_F77, ENTS_VAX} 
	EN_TARGET_SYSTEM;

typedef struct _ARGUMENT_DEFINITION {
	EN_VARIABLE_TYPE	variableType;
	EN_ARITH_TYPE		arithType;
	int					arithSize;
	EN_STORAGE_CLASS	storageClass;
	/* the following is needed to process IMPLICIT statements */
	int					firstCharIndex;
	struct _DIMENSION_DEFINITION	*dimension;
	struct _ARGUMENT_DEFINITION		*next;
	} ARGUMENT_DEFINITION;

typedef struct _VARIABLE_TYPE {
	EN_ARITH_TYPE		type;
	int					size;} VARIABLE_TYPE;

typedef struct _DIMENSION_DEFINITION
	{int		size;		/* =-1 if dimension is variable */
	int			lowerBound;
	struct _DIMENSION_DEFINITON	*nextDim;
	}	DIMENSION_DEFINITION;

typedef struct _COMMON_REGION
	{EN_ARITH_TYPE			type;
	int						variableSize;
	int						variableCount;
	int						commonBlockOffset;
	struct _COMMON_REGION	*next;
	} COMMON_REGION;

typedef struct _COMMON_DEFINITION
	{char			*name;
	int				inconsistentDeclaration;
	COMMON_REGION	*list;
	COMMON_REGION	*last;
	}	COMMON_DEFINITION;

typedef struct _VARIABLE_DEFINITION	{
	EN_VARIABLE_TYPE		type;
	char					*name;
	EN_ARITH_TYPE			arithType;
	EN_STORAGE_CLASS		storageClass;
	int						variableSize;
	/*	The value stored in constant value depends on the type of variable
		as follows:
			1 - Dummy variable - the index of the vriable in the
				parameter list
	*/
	int						constantValue;
	DIMENSION_DEFINITION	*dimension;
	int						commonOffset;	/* -1 if not in common */
	/* the following link points to:
		1) a COMMON_DEFINITION if the variable is in common
		2) the start of the argument list if the variable
				is the name of a procedure
		3) the first variable in a namelist if the variable is the name
			of a namelist
	*/
	void					*argumentOrCommonLink;
	struct _VARIABLE_DEFINITION	*commonLink;
	}	VARIABLE_DEFINITION;

typedef struct _COMMENT_CONTROL {
	EN_COMMENT_TYPE		commentType;
	int					statementOffset;
	struct _COMMENT_CONTROL		*nextComment;
	int					length;
	char				text[1];
	} COMMENT_CONTROL;

typedef struct _YACC_SYMBOL {
	int			number,		/* If the symbol is a token this is the
								number defined in the parse.h file.  Otherwise
								it is some synthetic value  */
				statementCharNo,	/* 
								The position on the input line where this
								token starts.  If the token starts on a
								continuation line, the first 6 columns of the
								line are not included in this value */
				printWithNextToken;	/*
								When set keep this token on the same
								output line as the following token.
								A chain of tokens can have this flag set */
	struct _YACC_SYMBOL	*next,
						*last,
						*argListLink,
						*lexerLink;
	DIMENSION_DEFINITION	*dimensionLink;
/* 	the following 2 fields are used by the parser when the symbol refers
	to a term in an arithmetic expression
*/
	EN_ARITH_TYPE		arithType;
	int					arithSize;
	EN_VARIABLE_TYPE	variableType;
	EN_STORAGE_CLASS	storageClass;
/*	if the token is an INTEGER_CONSTANT the next field is the value of 
	the constant.
	If the token is a dummy variable for a procedure, this field is the
	index (base 0) of where it appears in the argument list */
	int					constantValue;
	int					tokenSize;
	char				token[1];
	} YACC_SYMBOL;

void	addIncludeSegment (char *name);
char	*errorInit (void);
void	errorWrite (void);
void	initLexer (void);
void 	initializeVariable (VARIABLE_DEFINITION *pv);
void	lexerEndOfStatementProc (void);
void	lexerErrorProc (void);
void 	popFile (void);
void	processIncludeEnvironment (void);
