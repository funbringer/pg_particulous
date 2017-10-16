MODULE_big = pg_particulous

OBJS = src/pg_particulous.o $(WIN32RES)

EXTENSION = pg_particulous

EXTVERSION = 1.0

PGFILEDESC = "pg_particulous - instant migration from pg_pathman to vanilla PostgreSQL and vice versa"

DATA = pg_particulous--1.0.sql

REGRESS = vanilla_to_pathman

ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
else
subdir = contrib/pg_particulous
top_builddir = ../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif
