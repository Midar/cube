// generic useful stuff for any C++ program

#ifndef _TOOLS_H
#define _TOOLS_H

#ifdef __GNUC__
# define gamma __gamma
#endif

#include <math.h>

#ifdef __GNUC__
# undef gamma
#endif

#include <assert.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef __GNUC__
# include <new>
#else
# include <new.h>
#endif

#ifdef NULL
# undef NULL
#endif
#define NULL 0

typedef unsigned char uchar;
typedef unsigned short ushort;
typedef unsigned int uint;

#define max(a, b) (((a) > (b)) ? (a) : (b))
#define min(a, b) (((a) < (b)) ? (a) : (b))
#define rnd(max) (rand() % (max))
#define rndreset() (srand(1))
#define rndtime()                                                              \
	{                                                                      \
		loopi(lastmillis & 0xF) rnd(i + 1);                            \
	}
#define loop(v, m) for (int v = 0; v < (m); v++)
#define loopi(m) loop(i, m)
#define loopj(m) loop(j, m)
#define loopk(m) loop(k, m)
#define loopl(m) loop(l, m)

#ifdef WIN32
# pragma warning(3 : 4189)
// #pragma comment(linker,"/OPT:NOWIN98")
# define PATHDIV '\\'
#else
# define __cdecl
# define _vsnprintf vsnprintf
# define PATHDIV '/'
#endif

// easy safe strings

#define _MAXDEFSTR 260
typedef char string[_MAXDEFSTR];

inline void
strn0cpy(char *d, const char *s, size_t m)
{
	strncpy(d, s, m);
	d[(m)-1] = 0;
}

inline void
strcpy_s(char *d, const char *s)
{
	strn0cpy(d, s, _MAXDEFSTR);
}

inline void
strcat_s(char *d, const char *s)
{
	size_t n = strlen(d);
	strn0cpy(d + n, s, _MAXDEFSTR - n);
}

inline void
formatstring(char *d, const char *fmt, va_list v)
{
	_vsnprintf(d, _MAXDEFSTR, fmt, v);
	d[_MAXDEFSTR - 1] = 0;
}

struct sprintf_s_f {
	char *d;

	sprintf_s_f(char *str) : d(str) {};

	void
	operator()(const char *fmt, ...)
	{
		va_list v;
		va_start(v, fmt);
		_vsnprintf(d, _MAXDEFSTR, fmt, v);
		va_end(v);
		d[_MAXDEFSTR - 1] = 0;
	}
};

#define sprintf_s(d) sprintf_s_f((char *)d)
#define sprintf_sd(d)                                                          \
	string d;                                                              \
	sprintf_s(d)
#define sprintf_sdlv(d, last, fmt)                                             \
	string d;                                                              \
	{                                                                      \
		va_list ap;                                                    \
		va_start(ap, last);                                            \
		formatstring(d, fmt, ap);                                      \
		va_end(ap);                                                    \
	}
#define sprintf_sdv(d, fmt) sprintf_sdlv(d, fmt, fmt)

#define fast_f2nat(val) ((int)(val))

extern void endianswap(void *, int, int);

// memory pool that uses buckets and linear allocation for small objects
// VERY fast, and reasonably good memory reuse

struct pool {
	enum { POOLSIZE = 4096 }; // can be absolutely anything
	enum { PTRSIZE = sizeof(char *) };
	enum {
		MAXBUCKETS = 65
	}; // meaning up to size 256 on 32bit pointer systems
	enum { MAXREUSESIZE = MAXBUCKETS * PTRSIZE - PTRSIZE };

	inline size_t
	bucket(size_t s)
	{
		return (s + PTRSIZE - 1) >> PTRBITS;
	}

	enum { PTRBITS = PTRSIZE == 2 ? 1 : PTRSIZE == 4 ? 2 : 3 };

	char *p;
	size_t left;
	char *blocks;
	void *reuse[MAXBUCKETS];

	pool();
	~pool() { dealloc_block(blocks); };

	void *alloc(size_t size);
	void dealloc(void *p, size_t size);
	void *realloc(void *p, size_t oldsize, size_t newsize);

	char *string(const char *s, size_t l);

	char *
	string(const char *s)
	{
		return string(s, strlen(s));
	}

	void
	deallocstr(char *s)
	{
		dealloc(s, strlen(s) + 1);
	}

	char *
	stringbuf(const char *s)
	{
		return string(s, _MAXDEFSTR - 1);
	}

	void dealloc_block(void *b);
	void allocnext(size_t allocsize);
};

pool *gp();

template <class T> struct vector {
	T *buf;
	int alen;
	int ulen;
	pool *p;

	vector()
	{
		this->p = gp();
		alen = 8;
		buf = (T *)p->alloc(alen * sizeof(T));
		ulen = 0;
	}

	~vector()
	{
		setsize(0);
		p->dealloc(buf, alen * sizeof(T));
	}

	vector(vector<T> &v);
	void operator=(vector<T> &v);

	T &
	add(const T &x)
	{
		if (ulen == alen)
			realloc();
		new (&buf[ulen]) T(x);
		return buf[ulen++];
	}

	T &
	add()
	{
		if (ulen == alen)
			realloc();
		new (&buf[ulen]) T;
		return buf[ulen++];
	}

	T &
	pop()
	{
		return buf[--ulen];
	}

	T &
	last()
	{
		return buf[ulen - 1];
	}

	bool
	empty()
	{
		return ulen == 0;
	}

	int
	length()
	{
		return ulen;
	}

	T &
	operator[](int i)
	{
		assert(i >= 0 && i < ulen);
		return buf[i];
	}

	void
	setsize(int i)
	{
		for (; ulen > i; ulen--)
			buf[ulen - 1].~T();
	}

	T *
	getbuf()
	{
		return buf;
	}

	void
	sort(void *cf)
	{
		qsort(buf, ulen, sizeof(T),
		    (int(__cdecl *)(const void *, const void *))cf);
	}

	void
	realloc()
	{
		int olen = alen;
		buf = (T *)p->realloc(
		    buf, olen * sizeof(T), (alen *= 2) * sizeof(T));
	}

	T
	remove(int i)
	{
		T e = buf[i];
		for (int p = i + 1; p < ulen; p++)
			buf[p - 1] = buf[p];
		ulen--;
		return e;
	}

	T &
	insert(int i, const T &e)
	{
		add(T());
		for (int p = ulen - 1; p > i; p--)
			buf[p] = buf[p - 1];
		buf[i] = e;
		return buf[i];
	}
};

#define loopv(v)                                                               \
	if (false) {                                                           \
	} else                                                                 \
		for (int i = 0; i < (v).length(); i++)
#define loopvrev(v)                                                            \
	if (false) {                                                           \
	} else                                                                 \
		for (int i = (v).length() - 1; i >= 0; i--)

inline char *
newstring(const char *s)
{
	return gp()->string(s);
}

inline char *
newstring(const char *s, size_t l)
{
	return gp()->string(s, l);
}

inline char *
newstringbuf(const char *s)
{
	return gp()->stringbuf(s);
}

#endif
