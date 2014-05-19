typedef union	{
	YACC_SYMBOL		*ysym;
	int				intVal;
	} YYSTYPE;
#define	END_OF_STATEMENT	257
#define	IGNORE_THIS_TOKEN	258
#define	INCLUDE_T	259
#define	FORMAT_STATEMENT	260
#define	PASS_STATEMENT_T	261
#define	OPEN_STATEMENT_T	262
#define	IO_STATEMENT	263
#define	PASS_TEXT	264
#define	EQUALS	265
#define	INTEGER_CONSTANT	266
#define	REAL_CONSTANT	267
#define	L_PAREN	268
#define	R_PAREN	269
#define	COMMENT_STATEMENT_OUT	270
#define	IF_STATEMENT	271
#define	IF_THEN_STATEMENT	272
#define	ENCODE_DECODE	273
#define	ELSE_IF_STATEMENT	274
#define	RELATIONAL_OP_T	275
#define	IF_ARGUEMENT	276
#define	THEN_T	277
#define	ELSE_STATEMENT	278
#define	STRING_START	279
#define	STRING_ELEMENT	280
#define	END_OF_PROGRAM	281
#define	BYTE_TYPE	282
#define	LOGICAL_TYPE	283
#define	INTEGER_TYPE	284
#define	REAL_TYPE	285
#define	DOUBLE_TYPE	286
#define	COMPLEX_TYPE	287
#define	DOUBLE_COMPLEX_TYPE	288
#define	CHARACTER_TYPE	289
#define	OPEN_PASS	290
#define	OPEN_DUMP	291
#define	DO_STATEMENT	292
#define	END_DO_STATEMENT	293
#define	END_IF_STATEMENT	294
#define	GOTO_STATEMENT	295
#define	COMPUTED_GOTO_STATEMENT	296
#define	COMMON_STATEMENT	297
#define	INTRINSIC_OR_EXTERN_STATEMENT	298
#define	VARIABLE_NAME	299
#define	IO_PARAM_NAME	300
#define	STAR	301
#define	UNIT_IDENT	302
#define	APOS	303
#define	QUOTE	304
#define	COLON	305
#define	REFERENCE	306
#define	SPECIFICATION_COMPLETE	307
#define	CONCAT	308
#define	IMPLICIT_STATEMENT	309
#define	EQUIVALENCE_STATEMENT	310
#define	DIMENSION_STATEMENT	311
#define	FUNCTION	312
#define	SUBROUTINE	313
#define	NAMELIST	314
#define	PARAMETER	315
#define	DATA	316
#define	CALL	317
#define	CHAR	318
#define	DASH	319
#define	SLASH	320
#define	DOT	321
#define	GLOBAL_FUNCTION	322
#define	GLOBAL_SUBROUTINE	323
#define	GLOBAL_COMMON	324
#define	LOGICAL_OP	325
#define	LOGICAL_NOT	326
#define	ADD_OP	327
#define	MUL_OP	328
#define	EXP_OP	329
#define	COMMA	330
#define	LAST_DEFINED_TOKEN	331


extern YYSTYPE yylval;
