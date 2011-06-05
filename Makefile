BASEDIR = $(shell pwd)
THIRDPARTYLIBS = $(BASEDIR)/THIRDPARTY-LIBS

UNAME := $(shell uname)
ifeq ($(UNAME), Linux)
  # do something Linux-y
  STATIC ?= 2
endif
ifeq ($(UNAME), Darwin)
  # do something OSX-y
  STATIC = 0
  MAC_OS = 1
endif
STATIC ?= 2

FLAGS_CHUNKER += LOCAL_FFMPEG=$(THIRDPARTYLIBS)/ffmpeg-install
ifneq ($(HOSTARCH),mingw32)
FLAGS_CHUNKER += LOCAL_X264=$(THIRDPARTYLIBS)/x264-install 
FLAGS_CHUNKER += LOCAL_LIBOGG=$(THIRDPARTYLIBS)/libogg-install
FLAGS_CHUNKER += LOCAL_LIBVORBIS=$(THIRDPARTYLIBS)/libvorbis-install
FLAGS_CHUNKER += LOCAL_MP3LAME=$(THIRDPARTYLIBS)/mp3lame-install
else
EXE =.exe
endif

.PHONY: $(THIRDPARTYLIBS) update

all: pack

simple: Streamers/streamer-grapes$(EXE)
ml: Streamers/streamer-ml-monl-grapes-static$(EXE)
chunkstream: Streamers/streamer-chunkstream$(EXE) ChunkerPlayer/chunker_player/chunker_player$(EXE)
ml-chunkstream: Streamers/streamer-ml-monl-chunkstream-static$(EXE) ChunkerPlayer/chunker_player/chunker_player$(EXE)

$(THIRDPARTYLIBS):
	$(MAKE) -C $(THIRDPARTYLIBS) || { echo "Error preparing third party libs" && exit 1; }

update:
	git pull
	git submodule update

Streamers/.git:
	git submodule update --init -- $(shell dirname $@)

Streamers/streamer-grapes: Streamers/.git $(THIRDPARTYLIBS)
	GRAPES=$(THIRDPARTYLIBS)/GRAPES FFMPEG_DIR=$(THIRDPARTYLIBS)/ffmpeg X264_DIR=$(THIRDPARTYLIBS)/x264 $(MAKE) -C Streamers  || { echo "Error compiling the Streamer" && exit 1; }

#version with NAPA-libs
Streamers/streamer-ml-monl-grapes-static$(EXE): Streamers/.git $(THIRDPARTYLIBS)
	GRAPES=$(THIRDPARTYLIBS)/GRAPES FFMPEG_DIR=$(THIRDPARTYLIBS)/ffmpeg X264_DIR=$(THIRDPARTYLIBS)/x264 STATIC=$(STATIC) NAPA=$(THIRDPARTYLIBS)/NAPA-BASELIBS/ LIBEVENT_DIR=$(THIRDPARTYLIBS)/NAPA-BASELIBS/3RDPARTY-LIBS/libevent ML=1 MONL=1 $(MAKE) -C Streamers || { echo "Error compiling the ML+MONL version of the Streamer" && exit 1; }

Streamers/streamer-chunkstream$(EXE): Streamers/.git $(THIRDPARTYLIBS)
	IO=chunkstream GRAPES=$(THIRDPARTYLIBS)/GRAPES FFMPEG_DIR=$(THIRDPARTYLIBS)/ffmpeg X264_DIR=$(THIRDPARTYLIBS)/x264 $(MAKE) -C Streamers  || { echo "Error compiling the Streamer" && exit 1; }

Streamers/streamer-ml-monl-chunkstream-static$(EXE): Streamers/.git $(THIRDPARTYLIBS)
	IO=chunkstream GRAPES=$(THIRDPARTYLIBS)/GRAPES FFMPEG_DIR=$(THIRDPARTYLIBS)/ffmpeg X264_DIR=$(THIRDPARTYLIBS)/x264 STATIC=$(STATIC) NAPA=$(THIRDPARTYLIBS)/NAPA-BASELIBS/ LIBEVENT_DIR=$(THIRDPARTYLIBS)/NAPA-BASELIBS/3RDPARTY-LIBS/libevent ML=1 MONL=1 $(MAKE) -C Streamers || { echo "Error compiling the ML+MONL version of the Streamer" && exit 1; }

ChunkerPlayer/.git:
	git submodule update --init -- $(shell dirname $@)

ChunkerPlayer/chunker_player/chunker_player$(EXE): ChunkerPlayer/.git $(THIRDPARTYLIBS)
	cd ChunkerPlayer && $(FLAGS_CHUNKER) ./build_ul.sh

prepare:
	git submodule update --init

clean:
	$(MAKE) -C $(THIRDPARTYLIBS) clean
	$(MAKE) -C Streamers clean

pack: DIR = PeerStreamer-$(shell git describe --always --dirty || git describe --always)
pack: ml-chunkstream
	rm -rf $(DIR) $(DIR).tgz $(DIR)-stripped.tgz
	mkdir $(DIR)
	cp Streamers/streamer-ml-monl-chunkstream-static$(EXE) $(DIR)
	cp -r ChunkerPlayer/chunker_player/chunker_player$(EXE) ChunkerPlayer/chunker_player/icons $(DIR)
	cp ChunkerPlayer/chunker_player/stats_font.ttf ChunkerPlayer/chunker_player/mainfont.ttf ChunkerPlayer/chunker_player/napalogo_small.bmp $(DIR)
	echo streamer-ml-monl-chunkstream-static$(EXE) > $(DIR)/peer_exec_name.conf
ifneq ($(HOSTARCH),mingw32)
	ln -s streamer-ml-monl-chunkstream-static$(EXE) $(DIR)/streamer
	cp ChunkerPlayer/chunker_streamer/chunker_streamer ChunkerPlayer/chunker_streamer/chunker.conf $(DIR)
	cp scripts/source.sh $(DIR)
	cp scripts/player.sh $(DIR)
endif
	cp channels.conf $(DIR)
	cp README $(DIR)
	tar czf $(DIR).tgz $(DIR)
	cd $(DIR) && strip streamer-ml-monl-chunkstream-static$(EXE) chunker_player$(EXE)
ifneq ($(HOSTARCH),mingw32)
	cd $(DIR) && strip chunker_streamer$(EXE)
endif
	tar czf $(DIR)-stripped.tgz $(DIR)
