#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "userHeap.h"


/* package to manage a hser defined heap */

/* ************************** heapCreate ******************************* */
void    heapCreate (USER_HEAP *heap, int size)
{
heap->startOfHeap = (char *) malloc (size);
heap->totalSize = size;
heapFree (heap, 0);
return;
}

/* ********************** heapDestroy ***************************** */
void    heapDestroy (USER_HEAP *heap)
{
free (heap->startOfHeap);
return;
}

/* ************************* heapAlloc ************************** */
char    *heapAlloc (USER_HEAP *heap, int count)
{char *returnVal;

if (heap->bytesRemaining < count)
	{printf ("USER_HEAP overflow\n");
	exit (1);
	}
returnVal = heap->nextAllocate;
memset ( (void *) returnVal, 0, count);
heap->nextAllocate += count;
heap->bytesRemaining -= count;
return returnVal;
}

/* ******************************* heapFree *********************** */
void heapFree (USER_HEAP *heap, int count)	/* 0 -> free entire heap */
{
if ( !count)
	{heap->nextAllocate = heap->startOfHeap;
	heap->bytesRemaining = heap->totalSize;
	return;
	}
heap->nextAllocate -= count;
heap->bytesRemaining += count;
if (heap->bytesRemaining > heap->totalSize)
	{printf ("USER_HEAP buffer underflow\n");
	exit (2);
	}
}

/* **************************** heapInit ************************* */
void	heapInit (USER_HEAP *heap, int size, char *buffer)
{
heap->startOfHeap = buffer;
heap->nextAllocate = buffer;
heap->totalSize = size;
heap->bytesRemaining = size;
return;
}

