// Mem.h
// memory management

// ref: Hanson p 67 and following
// unlike Hanson's inteface, this interface does not throw an exception
// if the system runs out of memory

#ifndef MEM_H
#define MEM_H

extern void *Mem_alloc(long nbytes,
                       const char *fileName,
                       int lineNumber);
#define ALLOC(nbytes) \
  Mem_alloc((nbytes), __FILE__, __LINE__);

extern void *Mem_calloc(long count,
                        long nbytes,
                        const char *fileName,
                        int lineNumber);
#define CALLOC(count, nbytes) \
  Mem_calloc((count), (nbytes), __FILE__, __LINE__);


#define NEW(p)  ((p) = ALLOC((long) sizeof *(p)))
#define NEW0(p) ((p) = CALLOC(1, (long)sizeof *(p)))

extern void Mem_free(void *ptr,
                     const char *fileName,
                     int line);
#define FREE(p) \
  ((void) Mem-free((p), __FILE__, __LINE__), (p) = NULL;)

extern void *Mem_resize(void *p, long nBytes,
                        const char *fileName, int line);
#define RESIZE(p, nbytes)                              \
  ((p) = Mem_resize((p), (nbytes), __FILE__, __LINE__))

#endif
