// sound.cpp: uses fmod on windows and sdl_mixer on unix (both had problems on the other platform)

#include "cube.h"

//#ifndef WIN32    // NOTE: fmod not being supported for the moment as it does not allow stereo pan/vol updating during playback
#define USE_MIXER
//#endif

static int soundvol, musicvol;
bool nosound = false;

#define MAXCHAN 32
#define SOUNDFREQ 22050

struct soundloc {
	vec loc;
	bool inuse;
} soundlocs[MAXCHAN];

#ifdef USE_MIXER
# include "SDL_mixer.h"
# define MAXVOL MIX_MAX_VOLUME
Mix_Music *mod = NULL;
void *stream = NULL;
#else
# include "fmod.h"
# define MAXVOL 255
FMUSIC_MODULE *mod = NULL;
FSOUND_STREAM *stream = NULL;
#endif

void
stopsound()
{
	if (nosound)
		return;

	if (mod != NULL) {
#ifdef USE_MIXER
		Mix_HaltMusic();
		Mix_FreeMusic(mod);
#else
		FMUSIC_FreeSong(mod);
#endif
		mod = NULL;
	}

	if (stream != NULL) {
#ifndef USE_MIXER
		FSOUND_Stream_Close(stream);
#endif
		stream = NULL;
	}
}

static int soundbufferlen;

void
initsound()
{
	memset(soundlocs, 0, sizeof(soundloc) * MAXCHAN);

#ifdef USE_MIXER
	if (Mix_OpenAudio(SOUNDFREQ, MIX_DEFAULT_FORMAT, 2,
	    soundbufferlen) < 0) {
		conoutf("sound init failed (SDL_mixer): %s", Mix_GetError());
		nosound = true;
	}

	Mix_AllocateChannels(MAXCHAN);
#else
	if (FSOUND_GetVersion() < FMOD_VERSION)
		[Cube fatalError: @"old FMOD dll"];

	if (!FSOUND_Init(SOUNDFREQ, MAXCHAN, FSOUND_INIT_GLOBALFOCUS)) {
		conoutf("sound init failed (FMOD): %d", FSOUND_GetError());
		nosound = true;
	}
#endif
}

static OFMutableArray *snames;
static OFDataArray *samples;
static const void *null = NULL;

void
cleansound()
{
	if (nosound)
		return;

	stopsound();

#ifdef USE_MIXER
	Mix_CloseAudio();
#else
	FSOUND_Close();
#endif
}

static int stereo;

void
updatechanvol(int chan, vec *loc)
{
	int vol = soundvol, pan = 255 / 2;

	if (loc) {
		vdist(dist, v, *loc, player1->o);
		// simple mono distance attenuation
		vol -= (int)(dist * 3 * soundvol / 255);

		if (stereo && (v.x != 0 || v.y != 0)) {
			// relative angle of sound along X-Y axis
			float yaw = -atan2(v.x, v.y) - player1->yaw *
			    (PI / 180.0f);
			// range is from 0 (left) to 255 (right)
			pan = (int)(255.9f * (0.5 * sin(yaw) + 0.5f));
		}
	}

	vol = (vol * MAXVOL) / 255;
#ifdef USE_MIXER
	Mix_Volume(chan, vol);
	Mix_SetPanning(chan, 255 - pan, pan);
#else
	FSOUND_SetVolume(chan, vol);
	FSOUND_SetPan(chan, pan);
#endif
}

void
newsoundloc(int chan, vec *loc)
{
	assert(chan >= 0 && chan < MAXCHAN);

	soundlocs[chan].loc = *loc;
	soundlocs[chan].inuse = true;
}

void
updatevol()
{
	if (nosound)
		return;

	loopi(MAXCHAN) {
		if (soundlocs[i].inuse) {
#ifdef USE_MIXER
			if (Mix_Playing(i))
#else
			if (FSOUND_IsPlaying(i))
#endif
				updatechanvol(i, &soundlocs[i].loc);
			else
				soundlocs[i].inuse = false;
		}
	}
}

void
playsoundc(int n)
{
	addmsg(0, 2, SV_SOUND, n);
	playsound(n);
}

int soundsatonce = 0, lastsoundmillis = 0;

void
playsound(int n, vec *loc)
{
	if (nosound)
		return;

	if (soundvol == 0)
		return;

	if (lastmillis == lastsoundmillis)
		soundsatonce++;
	else
		soundsatonce = 1;

	lastsoundmillis = lastmillis;

	if (soundsatonce > 5)
		// avoid bursts of sounds with heavy packetloss and in sp
		return;

	if (n < 0 || n >= samples.count) {
		conoutf("unregistered sound: %d", n);
		return;
	}

#ifdef USE_MIXER
	Mix_Chunk **sample = (Mix_Chunk**)[samples itemAtIndex: n];
#else
	FSOUND_SAMPLE **sample = (FSOUND_SAMPLE**)[samples itemAtIndex: n];
#endif
	if (*sample == NULL) {
		sprintf_sd(buf)("packages/sounds/%s.wav",
		    [snames[n] UTF8String]);

#ifdef USE_MIXER
		*sample = Mix_LoadWAV(path(buf));
#else
		*sample = FSOUND_Sample_Load(n, path(buf), FSOUND_LOOP_OFF,
		    0, 0);
#endif

		if (*sample == NULL) {
			conoutf("failed to load sample: %s", buf);
			return;
		}
	}

#ifdef USE_MIXER
	int chan = Mix_PlayChannel(-1, *sample, 0);
#else
	int chan = FSOUND_PlaySoundEx(FSOUND_FREE, *sample, NULL, true);
#endif
	if (chan < 0)
		return;

	if (loc)
		newsoundloc(chan, loc);

	updatechanvol(chan, loc);
#ifndef USE_MIXER
	FSOUND_SetPaused(chan, false);
#endif
}

void
init_sound()
{
	addcommand(@"music", ARG_1STR, ^ (char *name) {
		if (nosound)
			return;

		stopsound();

		if (soundvol > 0 && musicvol > 0) {
			string sn;
			strcpy_s(sn, "packages/");
			strcat_s(sn, name);

#ifdef USE_MIXER
			if ((mod = Mix_LoadMUS(path(sn))) != NULL) {
				Mix_PlayMusic(mod, -1);
				Mix_VolumeMusic((musicvol * MAXVOL) / 255);
			}
#else
			if ((mod = FMUSIC_LoadSong(path(sn))) != NULL) {
				FMUSIC_PlaySong(mod);
				FMUSIC_SetMasterVolume(mod, musicvol);
			} else if ((stream = FSOUND_Stream_Open(path(sn),
			    FSOUND_LOOP_NORMAL, 0, 0)) != NULL) {
				int chan = FSOUND_Stream_Play(FSOUND_FREE,
				    stream);

				if (chan >= 0) {
					FSOUND_SetVolume(chan,
					    (musicvol * MAXVOL) / 255);
					FSOUND_SetPaused(chan, false);
				}
			} else
				conoutf("could not play music: %s", sn);
#endif
		}
	});

	addcommand(@"registersound", ARG_1EST, ^ int (char *name_) {
		@autoreleasepool {
			OFString *name = @(name_);
			size_t i = 0;

			if (snames == nil)
				snames = [OFMutableArray new];
			if (samples == nil)
				samples = [[OFDataArray alloc]
				    initWithItemSize: sizeof(void*)];

			for (OFString *soundName in snames) {
				if ([soundName isEqual: name])
					return i;

				i++;
			}

			[snames addObject: name];
			[samples addItem: &null];

			return i;
		}
	});

	addcommand(@"sound", ARG_1INT, ^ (int n) {
		playsound(n, NULL);
	});

	VARP(soundvol, 0, 255, 255);
	VARP(musicvol, 0, 128, 255);
	VAR(soundbufferlen, 128, 1024, 4096);
	VAR(stereo, 0, 1, 1);
}
