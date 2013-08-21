// Atom.h
// An atom is a unique immutable sequence of zero or more arbitrary bytes.
// Unlike Hanson's interface, this interface is an ADT

// Ref: Hanson, p.33 and following

#ifndef ATOM_H
#define ATOM_H

#include <stdlib.h>

#define T Atom_T
typedef struct T *T;

struct Atom_T {
  struct Atom_T *link;
  unsigned       length;
  char           str[1];
};


// constructors
extern T Atom_new(const char *str, size_t len);
extern T Atom_newFromString(char *str);
extern T Atom_newFromInt64(int64_t n);

// there are no destructors

// inquiries
extern size_t  Atom_length(T self);
extern char   *Atom_str(T self);

#undef T

#endif
