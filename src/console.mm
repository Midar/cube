// console.cpp: the console buffer, its display, and command line control

#include "cube.h"

#include <ctype.h>
#include <memory>

struct cline {
	char *cref;
	int outtime;
};
vector<cline> conlines;

const int ndraw = 5;
const int WORDWRAP = 80;
int conskip = 0;

bool saycommandon = false;
string commandbuf;

void
setconskip(int n)
{
	conskip += n;
	if (conskip < 0)
		conskip = 0;
}
COMMANDN(conskip, setconskip, ARG_1INT)

static void
conline(OFString *sf, bool highlight) // add a line to the console buffer
{
	cline cl;
	cl.cref = conlines.length() > 100
	              ? conlines.pop().cref
	              : newstringbuf(""); // constrain the buffer size
	cl.outtime = lastmillis;          // for how long to keep line on screen
	conlines.insert(0, cl);
	if (highlight) // show line in a different colour, for chat etc.
	{
		cl.cref[0] = '\f';
		cl.cref[1] = 0;
		strcat_s(cl.cref, sf.UTF8String);
	} else {
		strcpy_s(cl.cref, sf.UTF8String);
	}
	puts(cl.cref);
#ifndef OF_WINDOWS
	fflush(stdout);
#endif
}

void
conoutf(OFConstantString *format, ...)
{
	@autoreleasepool {
		va_list arguments;
		va_start(arguments, format);

		OFString *string = [[OFString alloc] initWithFormat:format
		                                          arguments:arguments];

		va_end(arguments);

		int n = 0;
		while (string.length > WORDWRAP) {
			conline([string substringToIndex:WORDWRAP], n++ != 0);
			string = [string substringFromIndex:WORDWRAP];
		}
		conline(string, n != 0);
	}
}

void
renderconsole() // render buffer taking into account time & scrolling
{
	int nd = 0;
	char *refs[ndraw];
	loopv(conlines) if (conskip ? i >= conskip - 1 ||
	                                  i >= conlines.length() - ndraw
	                            : lastmillis - conlines[i].outtime < 20000)
	{
		refs[nd++] = conlines[i].cref;
		if (nd == ndraw)
			break;
	};
	loopj(nd)
	{
		draw_text(refs[j], FONTH / 3,
		    (FONTH / 4 * 5) * (nd - j - 1) + FONTH / 3, 2);
	};
};

// keymap is defined externally in keymap.cfg

struct keym {
	int code;
	char *name;
	char *action;
} keyms[256];
int numkm = 0;

void
keymap(OFString *code, OFString *key, OFString *action)
{
	@autoreleasepool {
		keyms[numkm].code = (int)code.longLongValue;
		keyms[numkm].name = newstring(key.UTF8String);
		keyms[numkm++].action = newstringbuf(action.UTF8String);
	}
}
COMMAND(keymap, ARG_3STR)

void
bindkey(OFString *key_, OFString *action)
{
	@autoreleasepool {
		std::unique_ptr<char> key(strdup(key_.UTF8String));
		for (char *x = key.get(); *x; x++)
			*x = toupper(*x);
		loopi(numkm) if (strcmp(keyms[i].name, key.get()) == 0)
		{
			strcpy_s(keyms[i].action, action.UTF8String);
			return;
		}
		conoutf(@"unknown key \"%s\"", key.get());
	}
}
COMMANDN(bind, bindkey, ARG_2STR)

void
saycommand(char *init) // turns input to the command line on or off
{
	saycommandon = (init != NULL);
	if (saycommandon)
		SDL_StartTextInput();
	else
		SDL_StopTextInput();
	if (!editmode)
		Cube.sharedInstance.repeatsKeys = saycommandon;
	if (!init)
		init = "";
	strcpy_s(commandbuf, init);
}
COMMAND(saycommand, ARG_VARI)

void
mapmsg(OFString *s)
{
	@autoreleasepool {
		strn0cpy(hdr.maptitle, s.UTF8String, 128);
	}
}
COMMAND(mapmsg, ARG_1STR)

void
pasteconsole()
{
	char *cb = SDL_GetClipboardText();
	strcat_s(commandbuf, cb);
}

cvector vhistory;
int histpos = 0;

void
history(int n)
{
	static bool rec = false;
	if (!rec && n >= 0 && n < vhistory.length()) {
		rec = true;
		execute(vhistory[vhistory.length() - n - 1]);
		rec = false;
	};
}
COMMAND(history, ARG_1INT)

void
keypress(int code, bool isdown, int cooked)
{
	if (saycommandon) // keystrokes go to commandline
	{
		if (isdown) {
			switch (code) {
			case SDLK_RETURN:
				break;

			case SDLK_BACKSPACE:
			case SDLK_LEFT: {
				for (int i = 0; commandbuf[i]; i++)
					if (!commandbuf[i + 1])
						commandbuf[i] = 0;
				resetcomplete();
				break;
			};

			case SDLK_UP:
				if (histpos)
					strcpy_s(
					    commandbuf, vhistory[--histpos]);
				break;

			case SDLK_DOWN:
				if (histpos < vhistory.length())
					strcpy_s(
					    commandbuf, vhistory[histpos++]);
				break;

			case SDLK_TAB:
				complete(commandbuf);
				break;

			case SDLK_v:
				if (SDL_GetModState() &
				    (KMOD_LCTRL | KMOD_RCTRL)) {
					pasteconsole();
					return;
				};

			default:
				resetcomplete();
				if (cooked) {
					char add[] = {(char)cooked, 0};
					strcat_s(commandbuf, add);
				};
			};
		} else {
			if (code == SDLK_RETURN) {
				if (commandbuf[0]) {
					if (vhistory.empty() ||
					    strcmp(
					        vhistory.last(), commandbuf)) {
						vhistory.add(newstring(
						    commandbuf)); // cap this?
					};
					histpos = vhistory.length();
					if (commandbuf[0] == '/')
						execute(commandbuf, true);
					else
						toserver(commandbuf);
				};
				saycommand(NULL);
			} else if (code == SDLK_ESCAPE) {
				saycommand(NULL);
			};
		};
	} else if (!menukey(code, isdown)) // keystrokes go to menu
	{
		loopi(numkm) if (keyms[i].code ==
		                 code) // keystrokes go to game, lookup in
		                       // keymap and execute
		{
			string temp;
			strcpy_s(temp, keyms[i].action);
			execute(temp, isdown);
			return;
		};
	};
};

char *
getcurcommand()
{
	return saycommandon ? commandbuf : NULL;
};

void
writebinds(FILE *f)
{
	loopi(numkm)
	{
		if (*keyms[i].action)
			fprintf(f, "bind \"%s\" [%s]\n", keyms[i].name,
			    keyms[i].action);
	};
};
