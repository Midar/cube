// command.cpp: implements the parsing and execution of a tiny script language
// which is largely backwards compatible with the quake console language.

#include "cube.h"

#include <memory>

#import "Ident.h"

void
itoa(char *s, int i)
{
	sprintf_s(s)("%d", i);
}

char *
exchangestr(char *o, const char *n)
{
	gp()->deallocstr(o);
	return newstring(n);
}

// contains ALL vars/commands/aliases
OFMutableDictionary<OFString *, Ident *> *idents;

void
alias(OFString *name, OFString *action)
{
	Ident *b = idents[name];

	if (b == nil) {
		Ident *b = [[Ident alloc] init];
		b.type = ID_ALIAS;
		b.name = name;
		b.action = action;
		b.persist = true;

		idents[b.name] = b;
	} else {
		if (b.type == ID_ALIAS)
			b.action = action;
		else
			conoutf(
			    @"cannot redefine builtin %@ with an alias", name);
	}
}
COMMAND(alias, ARG_2STR)

int
variable(OFString *name, int min, int cur, int max, int *storage, void (*fun)(),
    bool persist)
{
	if (idents == nil)
		idents = [[OFMutableDictionary alloc] init];

	Ident *v = [[Ident alloc] init];
	v.type = ID_VAR;
	v.name = name;
	v.min = min;
	v.max = max;
	v.storage = storage;
	v.fun = fun;
	v.persist = persist;

	idents[name] = v;

	return cur;
}

void
setvar(OFString *name, int i)
{
	*idents[name].storage = i;
}

int
getvar(OFString *name)
{
	return *idents[name].storage;
}

bool
identexists(OFString *name)
{
	return (idents[name] != nil);
}

OFString *
getalias(OFString *name)
{
	Ident *i = idents[name];
	return i != nil && i.type == ID_ALIAS ? i.action : nil;
}

bool
addcommand(OFString *name, void (*fun)(), int narg)
{
	if (idents == nil)
		idents = [[OFMutableDictionary alloc] init];

	@autoreleasepool {
		Ident *c = [[Ident alloc] init];
		c.type = ID_COMMAND;
		c.name = name;
		c.fun = fun;
		c.narg = narg;

		idents[name] = c;
	}

	return false;
}

char *
parseexp(char *&p, int right) // parse any nested set of () or []
{
	int left = *p++;
	char *word = p;
	for (int brak = 1; brak;) {
		int c = *p++;
		if (c == '\r')
			*(p - 1) = ' '; // hack
		if (c == left)
			brak++;
		else if (c == right)
			brak--;
		else if (!c) {
			p--;
			conoutf(@"missing \"%c\"", right);
			return NULL;
		}
	}
	char *s = newstring(word, p - word - 1);
	if (left == '(') {
		string t;
		itoa(t,
		    execute(
		        s)); // evaluate () exps directly, and substitute result
		s = exchangestr(s, t);
	}
	return s;
}

char *
parseword(char *&p) // parse single argument, including expressions
{
	p += strspn(p, " \t\r");
	if (p[0] == '/' && p[1] == '/')
		p += strcspn(p, "\n\0");
	if (*p == '\"') {
		p++;
		char *word = p;
		p += strcspn(p, "\"\r\n\0");
		char *s = newstring(word, p - word);
		if (*p == '\"')
			p++;
		return s;
	}
	if (*p == '(')
		return parseexp(p, ')');
	if (*p == '[')
		return parseexp(p, ']');
	char *word = p;
	p += strcspn(p, "; \t\r\n\0");
	if (p - word == 0)
		return NULL;
	return newstring(word, p - word);
}

char *
lookup(char *n) // find value of ident referenced with $ in exp
{
	@autoreleasepool {
		Ident *ID = idents[@(n + 1)];

		if (ID != nil) {
			switch (ID.type) {
			case ID_VAR:
				string t;
				itoa(t, *(ID.storage));
				return exchangestr(n, t);
			case ID_ALIAS:
				return exchangestr(n, ID.action.UTF8String);
			}
		}
	}

	conoutf(@"unknown alias lookup: %s", n + 1);
	return n;
}

int
execute(char *p, bool isdown) // all evaluation happens here, recursively
{
	const int MAXWORDS = 25; // limit, remove
	char *w[MAXWORDS];
	int val = 0;
	for (bool cont = true; cont;) // for each ; seperated statement
	{
		int numargs = MAXWORDS;
		loopi(MAXWORDS) // collect all argument values
		{
			w[i] = "";
			if (i > numargs)
				continue;
			char *s = parseword(p); // parse and evaluate exps
			if (!s) {
				numargs = i;
				s = "";
			}
			if (*s == '$')
				s = lookup(s); // substitute variables
			w[i] = s;
		}

		p += strcspn(p, ";\n\0");
		cont = *p++ !=
		       0; // more statements if this isn't the end of the string
		char *c = w[0];
		if (*c == '/')
			c++; // strip irc-style command prefix
		if (!*c)
			continue; // empty statement

		@autoreleasepool {
			Ident *ID = idents[@(c)];

			if (ID == nil) {
				val = ATOI(c);
				if (!val && *c != '0')
					conoutf(@"unknown command: %s", c);
			} else {
				switch (ID.type) {
				// game defined commands
				case ID_COMMAND:
					// use very ad-hoc function signature,
					// and just call it
					switch (ID.narg) {
					case ARG_1INT:
						if (isdown)
							((void(__cdecl *)(
							    int))ID.fun)(
							    ATOI(w[1]));
						break;
					case ARG_2INT:
						if (isdown)
							((void(__cdecl *)(
							    int, int))ID.fun)(
							    ATOI(w[1]),
							    ATOI(w[2]));
						break;
					case ARG_3INT:
						if (isdown)
							((void(__cdecl *)(int,
							    int, int))ID.fun)(
							    ATOI(w[1]),
							    ATOI(w[2]),
							    ATOI(w[3]));
						break;
					case ARG_4INT:
						if (isdown)
							((void(__cdecl *)(int,
							    int, int,
							    int))ID.fun)(
							    ATOI(w[1]),
							    ATOI(w[2]),
							    ATOI(w[3]),
							    ATOI(w[4]));
						break;
					case ARG_NONE:
						if (isdown)
							((void(__cdecl *)())
							        ID.fun)();
						break;
					case ARG_1STR:
						if (isdown) {
							@autoreleasepool {
								((void(
								    __cdecl *)(
								    OFString *))
								        ID.fun)(
								    @(w[1]));
							}
						}
						break;
					case ARG_2STR:
						if (isdown) {
							@autoreleasepool {
								((void(
								    __cdecl *)(
								    OFString *,
								    OFString *))
								        ID.fun)(
								    @(w[1]),
								    @(w[2]));
							}
						}
						break;
					case ARG_3STR:
						if (isdown) {
							@autoreleasepool {
								((void(
								    __cdecl *)(
								    OFString *,
								    OFString *,
								    OFString *))
								        ID.fun)(
								    @(w[1]),
								    @(w[2]),
								    @(w[3]));
							}
						}
						break;
					case ARG_5STR:
						if (isdown) {
							@autoreleasepool {
								((void(
								    __cdecl *)(
								    OFString *,
								    OFString *,
								    OFString *,
								    OFString *,
								    OFString *))
								        ID.fun)(
								    @(w[1]),
								    @(w[2]),
								    @(w[3]),
								    @(w[4]),
								    @(w[5]));
							}
						}
						break;
					case ARG_DOWN:
						((void(__cdecl *)(bool))ID.fun)(
						    isdown);
						break;
					case ARG_DWN1:
						((void(__cdecl *)(
						    bool, char *))ID.fun)(
						    isdown, w[1]);
						break;
					case ARG_1EXP:
						if (isdown)
							val = ((int(__cdecl *)(
							    int))ID.fun)(
							    execute(w[1]));
						break;
					case ARG_2EXP:
						if (isdown)
							val = ((int(__cdecl *)(
							    int, int))ID.fun)(
							    execute(w[1]),
							    execute(w[2]));
						break;
					case ARG_1EST:
						if (isdown)
							val = ((int(__cdecl *)(
							    char *))ID.fun)(
							    w[1]);
						break;
					case ARG_2EST:
						if (isdown)
							val = ((int(__cdecl *)(
							    char *,
							    char *))ID.fun)(
							    w[1], w[2]);
						break;
					case ARG_VARI:
						if (isdown) {
							// limit, remove
							string r;
							r[0] = 0;
							for (int i = 1;
							     i < numargs; i++) {
								// make
								// string-list
								// out of all
								// arguments
								strcat_s(
								    r, w[i]);
								if (i ==
								    numargs - 1)
									break;
								strcat_s(
								    r, " ");
							}
							((void(__cdecl *)(
							    char *))ID.fun)(r);
							break;
						}
					}
					break;

				// game defined variables
				case ID_VAR:
					if (isdown) {
						if (!w[1][0])
							// var with no value
							// just prints its
							// current value
							conoutf(@"%s = %d", c,
							    *ID.storage);
						else {
							if (ID.min > ID.max) {
								conoutf(
								    @"variable "
								    @"is "
								    @"read-"
								    @"only");
							} else {
								int i1 =
								    ATOI(w[1]);
								if (i1 <
								        ID.min ||
								    i1 >
								        ID.max) {
									// clamp
									// to
									// valid
									// range
									i1 =
									    i1 < ID.min
									        ? ID.min
									        : ID.max;
									conoutf(
									    @"v"
									    @"a"
									    @"l"
									    @"i"
									    @"d"
									    @" "
									    @"r"
									    @"a"
									    @"n"
									    @"g"
									    @"e"
									    @" "
									    @"f"
									    @"o"
									    @"r"
									    @" "
									    @"%"
									    @"s"
									    @" "
									    @"i"
									    @"s"
									    @" "
									    @"%"
									    @"d"
									    @"."
									    @"."
									    @"%"
									    @"d",
									    c,
									    ID.min,
									    ID.max);
								}
								*ID.storage =
								    i1;
							}
							if (ID.fun)
								// call trigger
								// function if
								// available
								((void(__cdecl
								        *)())ID
								        .fun)();
						}
					}
					break;

				// alias, also used as functions and (global)
				// variables
				case ID_ALIAS:
					for (int i = 1; i < numargs; i++) {
						@autoreleasepool {
							// set any arguments as
							// (global) arg values
							// so functions can
							// access them
							OFString *t = [OFString
							    stringWithFormat:
							        @"arg%d", i];
							alias(t, @(w[i]));
						}
					}
					// create new string here because alias
					// could rebind itself
					char *action =
					    newstring(ID.action.UTF8String);
					val = execute(action, isdown);
					gp()->deallocstr(action);
					break;
				}
			}
		}
		loopj(numargs) gp()->deallocstr(w[j]);
	}

	return val;
}

// tab-completion of all idents

int completesize = 0, completeidx = 0;

void
resetcomplete()
{
	completesize = 0;
}

void
complete(char *s)
{
	if (*s != '/') {
		string t;
		strcpy_s(t, s);
		strcpy_s(s, "/");
		strcat_s(s, t);
	}
	if (!s[1])
		return;
	if (!completesize) {
		completesize = (int)strlen(s) - 1;
		completeidx = 0;
	}
	__block int idx = 0;
	[idents enumerateKeysAndObjectsUsingBlock:^(
	    OFString *name, Ident *ident, bool *stop) {
		if (strncmp(ident.name.UTF8String, s + 1, completesize) == 0 &&
		    idx++ == completeidx) {
			strcpy_s(s, "/");
			strcat_s(s, ident.name.UTF8String);
		}
	}];
	completeidx++;
	if (completeidx >= idx)
		completeidx = 0;
}

bool
execfile(OFString *cfgfile)
{
	@autoreleasepool {
		OFMutableData *data;
		@try {
			data = [OFMutableData dataWithContentsOfFile:cfgfile];
		} @catch (id e) {
			return false;
		}

		// Ensure \0 termination.
		[data addItem:""];

		execute((char *)data.mutableItems);
		return true;
	}
}

void
exec(OFString *cfgfile)
{
	if (!execfile(cfgfile)) {
		@autoreleasepool {
			conoutf(@"could not read \"%@\"", cfgfile);
		}
	}
}

void
writecfg()
{
	OFStream *stream;
	@try {
		OFIRI *IRI = [Cube.sharedInstance.userDataIRI
		    IRIByAppendingPathComponent:@"config.cfg"];
		stream = [[OFIRIHandler handlerForIRI:IRI] openItemAtIRI:IRI
		                                                    mode:@"w"];
	} @catch (id e) {
		return;
	}

	[stream writeString:
	            @"// automatically written on exit, do not modify\n"
	            @"// delete this file to have defaults.cfg overwrite these "
	            @"settings\n"
	            @"// modify settings in game, or put settings in "
	            @"autoexec.cfg to override anything\n"
	            @"\n"];
	writeclientinfo(stream);
	[stream writeString:@"\n"];

	[idents enumerateKeysAndObjectsUsingBlock:^(
	    OFString *name, Ident *ident, bool *stop) {
		if (ident.type == ID_VAR && ident.persist) {
			[stream
			    writeFormat:@"%@ %d\n", ident.name, *ident.storage];
		}
	}];
	[stream writeString:@"\n"];

	writebinds(stream);
	[stream writeString:@"\n"];

	[idents enumerateKeysAndObjectsUsingBlock:^(
	    OFString *name, Ident *ident, bool *stop) {
		if (ident.type == ID_ALIAS &&
		    ![ident.name hasPrefix:@"nextmap_"])
			[stream writeFormat:@"alias \"%@\" [%@]\n", ident.name,
			        ident.action];
	}];

	[stream close];
}

COMMAND(writecfg, ARG_NONE)

// below the commands that implement a small imperative language. thanks to the
// semantics of
// () and [] expressions, any control construct can be defined trivially.

void
intset(OFString *name, int v)
{
	@autoreleasepool {
		alias(name, [OFString stringWithFormat:@"%d", v]);
	}
}

void
ifthen(OFString *cond, OFString *thenp, OFString *elsep)
{
	@autoreleasepool {
		std::unique_ptr<char> cmd(strdup(
		    (cond.UTF8String[0] != '0' ? thenp : elsep).UTF8String));

		execute(cmd.get());
	}
}

void
loopa(OFString *times, OFString *body_)
{
	@autoreleasepool {
		int t = (int)times.longLongValue;
		std::unique_ptr<char> body(strdup(body_.UTF8String));

		loopi(t)
		{
			intset(@"i", i);
			execute(body.get());
		}
	}
}

void
whilea(OFString *cond_, OFString *body_)
{
	@autoreleasepool {
		std::unique_ptr<char> cond(strdup(cond_.UTF8String));
		std::unique_ptr<char> body(strdup(body_.UTF8String));

		while (execute(cond.get()))
			execute(body.get());
	}
}

void
onrelease(bool on, char *body)
{
	if (!on)
		execute(body);
}

void
concat(char *s)
{
	@autoreleasepool {
		alias(@"s", @(s));
	}
}

void
concatword(char *s)
{
	for (char *a = s, *b = s; *a = *b; b++)
		if (*a != ' ')
			a++;
	concat(s);
}

int
listlen(char *a)
{
	if (!*a)
		return 0;
	int n = 0;
	while (*a)
		if (*a++ == ' ')
			n++;
	return n + 1;
}

void
at(OFString *s_, OFString *pos)
{
	@autoreleasepool {
		int n = (int)pos.longLongValue;
		std::unique_ptr<char> copy(strdup(s_.UTF8String));
		char *s = copy.get();

		loopi(n) s += strspn(s += strcspn(s, " \0"), " ");
		s[strcspn(s, " \0")] = 0;
		concat(s);
	}
}

COMMANDN(loop, loopa, ARG_2STR)
COMMANDN(while, whilea, ARG_2STR)
COMMANDN(if, ifthen, ARG_3STR)
COMMAND(onrelease, ARG_DWN1)
COMMAND(exec, ARG_1STR)
COMMAND(concat, ARG_VARI)
COMMAND(concatword, ARG_VARI)
COMMAND(at, ARG_2STR)
COMMAND(listlen, ARG_1EST)

int
add(int a, int b)
{
	return a + b;
}
COMMANDN(+, add, ARG_2EXP)

int
mul(int a, int b)
{
	return a * b;
}
COMMANDN(*, mul, ARG_2EXP)

int
sub(int a, int b)
{
	return a - b;
}
COMMANDN(-, sub, ARG_2EXP)

int
divi(int a, int b)
{
	return b ? a / b : 0;
}
COMMANDN(div, divi, ARG_2EXP)

int
mod(int a, int b)
{
	return b ? a % b : 0;
}
COMMAND(mod, ARG_2EXP)

int
equal(int a, int b)
{
	return (int)(a == b);
}
COMMANDN(=, equal, ARG_2EXP)

int
lt(int a, int b)
{
	return (int)(a < b);
}
COMMANDN(<, lt, ARG_2EXP)

int
gt(int a, int b)
{
	return (int)(a > b);
}
COMMANDN(>, gt, ARG_2EXP)

int
strcmpa(char *a, char *b)
{
	return strcmp(a, b) == 0;
}
COMMANDN(strcmp, strcmpa, ARG_2EST)

int
rndn(int a)
{
	return a > 0 ? rnd(a) : 0;
}
COMMANDN(rnd, rndn, ARG_1EXP)

int
explastmillis()
{
	return lastmillis;
}
COMMANDN(millis, explastmillis, ARG_1EXP)
