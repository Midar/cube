// sound.cpp: uses fmod on windows and sdl_mixer on unix (both had problems on
// the other platform)

#include "cube.h"

#import "DynamicEntity.h"

// #ifndef _WIN32    // NOTE: fmod not being supported for the moment as it does
// not allow stereo pan/vol updating during playback
#define USE_MIXER
// #endif

VARP(soundvol, 0, 255, 255);
VARP(musicvol, 0, 128, 255);
bool nosound = false;

#define MAXCHAN 32
#define SOUNDFREQ 22050

struct soundloc {
	OFVector3D loc;
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
	if (mod) {
#ifdef USE_MIXER
		Mix_HaltMusic();
		Mix_FreeMusic(mod);
#else
		FMUSIC_FreeSong(mod);
#endif
		mod = NULL;
	}
	if (stream) {
#ifndef USE_MIXER
		FSOUND_Stream_Close(stream);
#endif
		stream = NULL;
	}
}

VAR(soundbufferlen, 128, 1024, 4096);

void
initsound()
{
	memset(soundlocs, 0, sizeof(soundloc) * MAXCHAN);
#ifdef USE_MIXER
	if (Mix_OpenAudio(SOUNDFREQ, MIX_DEFAULT_FORMAT, 2, soundbufferlen) <
	    0) {
		conoutf(@"sound init failed (SDL_mixer): %s",
		    (size_t)Mix_GetError());
		nosound = true;
	}
	Mix_AllocateChannels(MAXCHAN);
#else
	if (FSOUND_GetVersion() < FMOD_VERSION)
		fatal(@"old FMOD dll");
	if (!FSOUND_Init(SOUNDFREQ, MAXCHAN, FSOUND_INIT_GLOBALFOCUS)) {
		conoutf(@"sound init failed (FMOD): %d", FSOUND_GetError());
		nosound = true;
	}
#endif
}

void
music(OFString *name)
{
	if (nosound)
		return;
	stopsound();
	if (soundvol && musicvol) {
		@autoreleasepool {
			name = [name stringByReplacingOccurrencesOfString:@"\\"
			                                       withString:@"/"];
			OFString *path =
			    [OFString stringWithFormat:@"packages/%@", name];
			OFIRI *IRI = [Cube.sharedInstance.gameDataIRI
			    IRIByAppendingPathComponent:path];

#ifdef USE_MIXER
			if ((mod = Mix_LoadMUS(
			         IRI.fileSystemRepresentation.UTF8String)) !=
			    NULL) {
				Mix_PlayMusic(mod, -1);
				Mix_VolumeMusic((musicvol * MAXVOL) / 255);
			}
#else
			if ((mod = FMUSIC_LoadSong(
			         IRI.fileSystemRepresentation.UTF8String)) !=
			    NULL) {
				FMUSIC_PlaySong(mod);
				FMUSIC_SetMasterVolume(mod, musicvol);
			} else if (stream = FSOUND_Stream_Open(
			               IRI.fileSystemRepresentation.UTF8String,
			               FSOUND_LOOP_NORMAL, 0, 0)) {
				int chan =
				    FSOUND_Stream_Play(FSOUND_FREE, stream);
				if (chan >= 0) {
					FSOUND_SetVolume(
					    chan, (musicvol * MAXVOL) / 255);
					FSOUND_SetPaused(chan, false);
				}
			} else {
				conoutf(
				    @"could not play music: %@", IRI.string);
			}
#endif
		}
	}
}
COMMAND(music, ARG_1STR)

#ifdef USE_MIXER
vector<Mix_Chunk *> samples;
#else
vector<FSOUND_SAMPLE *> samples;
#endif

static OFMutableArray<OFString *> *snames;

int
registersound(OFString *name)
{
	int i = 0;
	for (OFString *iter in snames) {
		if ([iter isEqual:name])
			return i;

		i++;
	}

	if (snames == nil)
		snames = [[OFMutableArray alloc] init];

	[snames addObject:[name stringByReplacingOccurrencesOfString:@"\\"
	                                                  withString:@"/"]];
	samples.add(NULL);

	return samples.length() - 1;
}
COMMAND(registersound, ARG_1EST)

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

VAR(stereo, 0, 1, 1);

static void
updatechanvol(int chan, const OFVector3D *loc)
{
	int vol = soundvol, pan = 255 / 2;
	if (loc) {
		vdist(dist, v, *loc, player1.o);
		vol -= (int)(dist * 3 * soundvol /
		    255); // simple mono distance attenuation
		if (stereo && (v.x != 0 || v.y != 0)) {
			// relative angle of sound along X-Y axis
			float yaw =
			    -atan2(v.x, v.y) - player1.yaw * (PI / 180.0f);
			// range is from 0 (left) to 255 (right)
			pan = int(255.9f * (0.5 * sin(yaw) + 0.5f));
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

static void
newsoundloc(int chan, const OFVector3D *loc)
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
	loopi(MAXCHAN) if (soundlocs[i].inuse)
	{
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

void
playsoundc(int n)
{
	addmsg(0, 2, SV_SOUND, n);
	playsound(n);
}

int soundsatonce = 0, lastsoundmillis = 0;

void
playsound(int n, const OFVector3D *loc)
{
	if (nosound)
		return;
	if (!soundvol)
		return;
	if (lastmillis == lastsoundmillis)
		soundsatonce++;
	else
		soundsatonce = 1;
	lastsoundmillis = lastmillis;
	if (soundsatonce > 5)
		return; // avoid bursts of sounds with heavy packetloss
		        // and in sp
	if (n < 0 || n >= samples.length()) {
		conoutf(@"unregistered sound: %d", n);
		return;
	}

	if (!samples[n]) {
		OFString *path = [OFString
		    stringWithFormat:@"packages/sounds/%@.wav", snames[n]];
		OFIRI *IRI = [Cube.sharedInstance.gameDataIRI
		    IRIByAppendingPathComponent:path];

#ifdef USE_MIXER
		samples[n] =
		    Mix_LoadWAV(IRI.fileSystemRepresentation.UTF8String);
#else
		samples[n] = FSOUND_Sample_Load(n,
		    IRI.fileSystemRepresentation.UTF8String, FSOUND_LOOP_OFF, 0,
		    0);
#endif

		if (!samples[n]) {
			conoutf(@"failed to load sample: %@", IRI.string);
			return;
		}
	}

#ifdef USE_MIXER
	int chan = Mix_PlayChannel(-1, samples[n], 0);
#else
	int chan = FSOUND_PlaySoundEx(FSOUND_FREE, samples[n], NULL, true);
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
sound(int n)
{
	playsound(n, NULL);
}
COMMAND(sound, ARG_1INT)
