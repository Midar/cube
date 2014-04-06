CPPFLAGS = -O3 -g -I../enet/include `sdl-config --cflags`
LIBS = -L../enet -lenet `sdl-config --libs` -lSDL_image -lSDL_mixer -lz -framework OpenGL #-lGL -lGLU #-lX11

CLIENT_SRCS = Alias.mm			\
	      Command.mm		\
	      Cube.mm			\
	      Identifier.mm		\
	      MD2.mm			\
	      Variable.mm		\
	      client.mm			\
	      clientextras.mm		\
	      clientgame.mm		\
	      clients2c.mm		\
	      console.mm		\
	      editing.mm		\
	      entities.mm		\
	      menus.mm			\
	      monster.mm		\
	      physics.mm		\
	      rendercubes.mm		\
	      renderextras.mm		\
	      rendergl.mm		\
	      renderparticles.mm	\
	      rendertext.mm 		\
	      rndmap.mm 		\
	      savegamedemo.mm 		\
	      scripting.mm 		\
	      server.mm 		\
	      serverbrowser.mm 		\
	      serverms.mm 		\
	      serverutil.mm 		\
	      sound.mm 			\
	      tools.mm 			\
	      weapon.mm 		\
	      world.mm 			\
	      worldio.mm 		\
	      worldlight.mm 		\
	      worldocull.mm 		\
	      worldrender.mm

SERVER_SRCS = server.mm		\
	      serverms.mm	\
	      serverutil.mm	\
	      tools.mm

all: ../bin/client ../bin/server

enet:
	make -C ../enet all

clean:
	rm -fr ../build ../bin
	make -C ../enet clean

../bin/client: enet
	@mkdir -p ../bin
	@objfw-compile --builddir ../build/client --arc -o $@	\
		${CLIENT_SRCS} ${CPPFLAGS} ${LIBS}

../bin/server: enet
	@mkdir -p ../bin
	@objfw-compile --builddir ../build/server --arc -o $@   \
		${SERVER_SRCS} ${CPPFLAGS} ${LIBS}	\
		-DSTANDALONE
