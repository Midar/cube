// main.cpp: initialisation & main loop

#include "cube.h"
#import "DataDownloader.h"

OF_APPLICATION_DELEGATE(Cube)

// for some big chunks... most other allocs use the memory pool
void*
alloc(int s)
{
	void *b = calloc(1, s);

	if (b == NULL)
		[Cube fatalError: @"out of memory!"];

	return b;
}

static int scr_w = 640;
static int scr_h = 480;

void
keyrepeat(bool on)
{
	/* FIXME */
//	SDL_EnableKeyRepeat(on
//	    ? SDL_DEFAULT_REPEAT_DELAY : 0, SDL_DEFAULT_REPEAT_INTERVAL);
}

static int gamespeed;
static int minmillis;

int framesinmap = 0;

@implementation Cube
/* single program exit point */
+ (void)cleanUpAndShowMessage: (OFString*)message
{
	SDL_ShowCursor(1);

	if (message != nil) {
#ifdef _WIN32
		MessageBoxW(NULL, [message UTF16String], L"cube fatal error",
		    MB_OK | MB_SYSTEMMODAL);
#else
		[of_stdout writeString: message];
#endif
	}

	SDL_Quit();
}

/* normal exit */
+ (void)quit
{
	writeservercfg();

	[self cleanUpAndShowMessage: nil];

	[OFApplication terminate];
}

/* failure exit */
+ (void)fatalError: (OFString*)message
{
	[self cleanUpAndShowMessage:
	    [OFString stringWithFormat: @"%@ (%s)\n", message, SDL_GetError()]];

	[OFApplication terminateWithStatus: 1];
}

- (void)applicationDidFinishLaunching
{
	bool dedicated;
	int fs = SDL_WINDOW_FULLSCREEN, par = 0, uprate = 0, maxcl = 4;
	OFString *sdesc = @"", *ip = @"", *master = nil, *passwd = @"";
	SDL_Window *window;

	@autoreleasepool {
		const of_options_parser_option_t options[] = {
			{ 'd', nil, 0, &dedicated, NULL },
			{ 't', nil, 0, NULL, NULL },
			{ 'w', nil, 1, NULL, NULL },
			{ 'h', nil, 1, NULL, NULL },
			{ 'u', nil, 1, NULL, NULL },
			{ 'n', nil, 1, NULL, NULL },
			{ 'i', nil, 1, NULL, NULL },
			{ 'm', nil, 1, NULL, NULL },
			{ 'p', nil, 1, NULL, NULL },
			{ 'c', nil, 1, NULL, NULL },
			{ '\0', nil, NULL, NULL }
		};
		OFOptionsParser *optparser = [OFOptionsParser
		    parserWithOptions: options];
		of_unichar_t opt;

		while ((opt = [optparser nextOption]) != '\0') {
			switch (opt) {
			case 't':
				fs = 0;
				break;
			case 'w':
				scr_w = [optparser.argument decimalValue];
				break;
			case 'h':
				scr_h = [optparser.argument decimalValue];
				break;
			case 'u':
				uprate = [optparser.argument decimalValue];
				break;
			case 'n':
				sdesc = optparser.argument;
				break;
			case 'i':
				ip = optparser.argument;
				break;
			case 'm':
				master = optparser.argument;
				break;
			case 'p':
				passwd = optparser.argument;
				break;
			case 'c':
				maxcl = [optparser.argument decimalValue];
				break;
			case ':':
				conoutf("missing argument");
				break;
			case '?':
				conoutf("unknown command line option");
				break;
			}
		}
	}

	OFFileManager *fileManager = [OFFileManager defaultManager];
	if (![fileManager directoryExistsAtPath: @"data"] ||
	    ![fileManager directoryExistsAtPath: @"packages"]) {
		DataDownloader *downloader = [DataDownloader new];

		if (![downloader download]) {
			conoutf("failed to download data files");
			[Cube quit];
		}
	}

	init_Cube();
	init_MD2();
	init_client();
	init_clientextras();
	init_clientgame();
	init_console();
	init_editing();
	init_menus();
	init_monster();
	init_physics();
	init_rendercubes();
	init_renderextras();
	init_rendergl();
	init_renderparticles();
	init_savegamedemo();
	init_scripting();
	init_serverbrowser();
	init_sound();
	init_weapon();
	init_world();
	init_worldio();
	init_worldlight();
	init_worldocull();

#define log(s) conoutf("init: %s", s)
	log("sdl");

#ifdef _DEBUG
	par = SDL_INIT_NOPARACHUTE;
	fs = 0;
#endif

	if (SDL_Init(SDL_INIT_TIMER | SDL_INIT_VIDEO | par) < 0)
		[Cube fatalError: @"Unable to initialize SDL"];

	log("net");
	if (enet_initialize() < 0)
		[Cube fatalError: @"Unable to initialise network module"];

	initclient();
	// never returns if dedicated
	initserver(dedicated, uprate, sdesc, ip, master, passwd, maxcl);

	log("world");
	empty_world(7, true);

	log("video: sdl");
	if (SDL_InitSubSystem(SDL_INIT_VIDEO) < 0)
		[Cube fatalError: @"Unable to initialize SDL Video"];

	log("video: mode");
	SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
	if ((window = SDL_CreateWindow("cube engine", SDL_WINDOWPOS_UNDEFINED,
	    SDL_WINDOWPOS_UNDEFINED, scr_w, scr_h,
	    SDL_WINDOW_OPENGL | fs)) == NULL)
		[Cube fatalError: @"Unable to create OpenGL screen"];
	SDL_GL_CreateContext(window);

	log("video: misc");
	keyrepeat(false);
	SDL_SetRelativeMouseMode(SDL_TRUE);

	log("gl");
	gl_init(scr_w, scr_h);

	log("basetex");
	int xs, ys;
	if (!installtex(2,  path(newstring("data/newchars.png")), xs, ys) ||
	    !installtex(3,  path(newstring("data/martin/base.png")), xs, ys) ||
	    !installtex(6,  path(newstring("data/martin/ball1.png")), xs, ys) ||
	    !installtex(7,  path(newstring("data/martin/smoke.png")), xs, ys) ||
	    !installtex(8,  path(newstring("data/martin/ball2.png")), xs, ys) ||
	    !installtex(9,  path(newstring("data/martin/ball3.png")), xs, ys) ||
	    !installtex(4,  path(newstring("data/explosion.jpg")), xs, ys) ||
	    !installtex(5,  path(newstring("data/items.png")), xs, ys) ||
	    !installtex(1,  path(newstring("data/crosshair.png")), xs, ys))
		[Cube fatalError: @"could not find core textures (hint: run "
				  @"cube from the parent of the bin "
				  @"directory)"];

	log("sound");
	initsound();

	log("cfg");
	newmenu("frags\tpj\tping\tteam\tname");
	newmenu("ping\tplr\tserver");
	exec(@"data/keymap.cfg");
	exec(@"data/menus.cfg");
	exec(@"data/prefabs.cfg");
	exec(@"data/sounds.cfg");
	exec(@"servers.cfg");
	if (!execfile(@"config.cfg"))
		execfile(@"data/defaults.cfg");
	exec(@"autoexec.cfg");

	log("localconnect");
	localconnect();
	// if this map is changed, also change depthcorrect()
	changemap(@"metl3");

	log("mainloop");
	int ignore = 5;
	for(;;) {
		int millis = SDL_GetTicks() * gamespeed / 100;

		if (millis - lastmillis > 200)
			lastmillis = millis - 200;
		else if (millis - lastmillis < 1)
			lastmillis = millis - 1;

		if (millis - lastmillis < minmillis)
			SDL_Delay(minmillis - (millis - lastmillis));

		cleardlights();
		updateworld(millis);

		if (!demoplayback)
			serverslice((int)time(NULL), 0);

		static float fps = 30.0f;
		fps = (1000.0f/curtime+fps*50)/51;
		computeraytable(player1->o.x, player1->o.y);
		readdepth(scr_w, scr_h);
		SDL_GL_SwapWindow(window);

		extern void updatevol();
		updatevol();

		// cheap hack to get rid of initial sparklies, even when triple
		// buffering etc.
		if (framesinmap++ < 5) {
			player1->yaw += 5;
			gl_drawframe(scr_w, scr_h, fps);
			player1->yaw -= 5;
		}

		gl_drawframe(scr_w, scr_h, fps);

		SDL_Event event;
		int lasttype = 0, lastbut = 0;
		while (SDL_PollEvent(&event)) {
			switch(event.type) {
			case SDL_QUIT:
				[Cube quit];
				break;

			case SDL_KEYDOWN:
			case SDL_KEYUP:
				keypress(event.key.keysym.sym,
				    (event.key.state == SDL_PRESSED),
				    event.key.keysym.sym);
				break;

			case SDL_MOUSEMOTION:
				if (ignore) {
					ignore--;
					break;
				}

				mousemove(event.motion.xrel, event.motion.yrel);

				break;

			case SDL_MOUSEBUTTONDOWN:
			case SDL_MOUSEBUTTONUP:
				// why?? get event twice without it
				if (lasttype == event.type &&
				    lastbut == event.button.button)
					break;

				keypress(-event.button.button,
				    (event.button.state != 0), 0);
				lasttype = event.type;
				lastbut = event.button.button;

				break;
			}
		}
	}

	[Cube quit];
}

- (void)applicationWillTerminate
{
	stop();
	disconnect(true);
	writecfg();
	cleangl();
	cleansound();
	cleanupserver();
	SDL_ShowCursor(1);
}
@end

void init_Cube()
{
	addcommand(@"screenshot", ARG_NONE, ^ {
		SDL_Surface *image;
		SDL_Surface *temp;
		int idx;

		image = SDL_CreateRGBSurface(SDL_SWSURFACE, scr_w, scr_h,
		    24, 0x0000FF, 0x00FF00, 0xFF0000, 0);
		if (image == NULL)
			return;

		temp = SDL_CreateRGBSurface(SDL_SWSURFACE, scr_w, scr_h,
		    24, 0x0000FF, 0x00FF00, 0xFF0000, 0);
		if (temp == NULL) {
			SDL_FreeSurface(image);
			return;
		}

		glReadPixels(0, 0, scr_w, scr_h, GL_RGB, GL_UNSIGNED_BYTE,
		    image->pixels);

		for (idx = 0; idx<scr_h; idx++) {
			char *dest = (char*)temp->pixels + 3 * scr_w * idx;
			memcpy(dest, (char*)image->pixels + 3 * scr_w *
			    (scr_h - 1 - idx), 3 * scr_w);
			endianswap(dest, 3, scr_w);
		}

		sprintf_sd(buf)("screenshots/screenshot_%d.bmp", lastmillis);

		SDL_SaveBMP(temp, path(buf));
		SDL_FreeSurface(temp);
		SDL_FreeSurface(image);
	});

	addcommand(@"quit", ARG_NONE, ^ {
		[Cube quit];
	});

	VARF(gamespeed, 10, 100, 1000, ^ {
		if (multiplayer())
			gamespeed = 100;
	});

	VARP(minmillis, 0, 5, 1000);
}
