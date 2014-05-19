CC=icc
#DEBUG = -O
DEBUG = -Ti+
LINK_DEBUG = -DEBUG
CFLAGS= $(DEBUG) -c -Q+ -G5 -Wcnd- 

X = .exe
O = .obj

OBJECTS = parser$O lexer$O userHeap$O convertUtils$O symbolManagement$O

vax2Unix$X:	$(OBJECTS)
	ilink -NOLOGO $(LINK_DEBUG) -PM:VIO -O:vax2Unix$X $(OBJECTS) 

parser.c parser.h:	parser.y convert.h
	bison -t -v -l -d -o parser.c parser.y
lexer.c: lexer.l convert.h
	flex -i -L -s -olexer.c lexer.l
lexer$O:	lexer.c convert.h parser.h externalVariables.h \
	convertUtils.h symbolManagement.h
	$(CC) $(CFLAGS) -DYY_USE_PROTOS lexer.c
userHeap$O: userHeap.c userHeap.h
convertUtils$O: convert.h parser.h convertUtils.h userHeap.h externalVariables.h
parser$O:	parser.c convert.h externalVariables.h userHeap.h convertUtils.h\
	symbolManagement.h 
symbolManagement$O:	symbolManagement.h userHeap.h externalVariables.h\
	convert.h convertUtils.h parser.h
