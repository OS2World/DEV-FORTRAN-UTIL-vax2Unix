typedef struct _USER_HEAP
	{char	*startOfHeap;
	char	*nextAllocate;
	int		totalSize;
	int		bytesRemaining;
	}	USER_HEAP;
void	heapCreate (USER_HEAP *heap, int size);
void	heapDestroy (USER_HEAP *heap);
char	*heapAlloc (USER_HEAP *heap, int count);
void	heapFree (USER_HEAP *heap, int count);	/* count=0 -> free all */
void	heapInit (USER_HEAP *heap, int size, char *buffer);
