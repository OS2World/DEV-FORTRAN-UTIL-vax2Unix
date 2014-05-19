#define MAX_STATE_DEPTH 20
EXTERN FILE			*yyin,
					*yyout;
EXTERN USER_HEAP	commentHeap,
					tokenHeap;
EXTERN char			commentData[COMMENT_DATA_SIZE];
EXTERN char			tokenData[TOKEN_DATA_SIZE];
EXTERN int			currentStatementNo;
EXTERN int 			nextStatementNo;
EXTERN int			lineNo;
EXTERN int			forioerrIncluded;

EXTERN FILE			*errorFile;
EXTERN char			*currentFileName;
EXTERN char			*currentSourceDir;

EXTERN int			includeDepth;
EXTERN int			parenNestingLevel;
EXTERN int			blockIndentLevel;
/* Always return to this state when returning
   an END_OF_STATEMENT token
*/
EXTERN int				commentsOnCurrentLine;
EXTERN int				inhibitOutput;
EXTERN int				EOFRead;
EXTERN int				filePushed;

EXTERN YACC_SYMBOL		*currentSymbol,
						*previousSymbol;
/*	If the current execution unit is a procedure the next variable points
	to the YACC_SYMBOL which defines the name of the procedure
*/
EXTERN VARIABLE_DEFINITION		*currentProcedureVar;

EXTERN int					currentTokenOffset;
EXTERN COMMENT_CONTROL		*lastComment;

EXTERN int				generateGlobalData;
EXTERN EN_TARGET_SYSTEM targetSystem;
EXTERN int				littleEndian;

EXTERN	int				dependencyCharsOnCurrentLine,
						generateMakeDependencies;
EXTERN FILE				*makeDependencyFile;

EXTERN VARIABLE_TYPE	implicitType[26];
EXTERN VARIABLE_TYPE	defaultVariableSizeArray[] 
#if defined (INITIALIZE_EXTERNALS)
= {	ENAT_BYTE, 1,
	ENAT_CHAR, 1,
	ENAT_LOGICAL, 1,
	ENAT_INT, 4,
	ENAT_REAL, 4,
	ENAT_DOUBLE, 8,
	ENAT_COMPLEX, 8,
	ENAT_DOUBLE_COMPLEX, 16,
	ENAT_ALTERNATE_RETURN, 0,
	0, 0
	}
#endif
;
