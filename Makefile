# Makefile for the mapreduce project.

.PHONY: all clean

# The files the project starts with.  Add your code files here!
CCFILES = mapreduce.cc

#Add your includes here.
INCLUDES =
# These libraries are necessary for PPAPI (Pepper 2) and NaCl.
LDFLAGS = -lppruntime \
          -lppapi_cpp \
          -lplatform \
          -lgio \
          -lpthread \
          -lsrpc \
          $(ARCH_FLAGS)

# Add your .nmf files for each nexe you build here.
all: check_variables mapreduce.nmf mapreduce_dbg.nmf

# common.mk has rules to build .o files from .cc files.
-include common.mk

# Targets to create the manifests.
mapreduce.nmf: mapreduce_x86_32.nexe mapreduce_x86_64.nexe
	@echo "Creating mapreduce.nmf..."
	$(PYTHON) generate_nmf.py --nmf $@ \
	 --x86-64 mapreduce_x86_64.nexe \
         --x86-32 mapreduce_x86_32.nexe

mapreduce_dbg.nmf: mapreduce_x86_32_dbg.nexe \
        mapreduce_x86_64_dbg.nexe
	@echo "Creating mapreduce_dbg.nmf..."
	$(PYTHON) generate_nmf.py --nmf $@ \
	--x86-64 mapreduce_x86_64_dbg.nexe \
        --x86-32 mapreduce_x86_32_dbg.nexe

# Targets to create the nexes.
mapreduce_x86_32.nexe: $(OBJECTS_X86_32)
	$(CPP) $^ $(LDFLAGS) -m32 -o $@
	$(NACL_STRIP) $@ -o $@

mapreduce_x86_64.nexe: $(OBJECTS_X86_64)
	$(CPP) $^ $(LDFLAGS) -m64 -o $@
	$(NACL_STRIP) $@ -o $@

mapreduce_x86_32_dbg.nexe: $(OBJECTS_X86_32_DBG)
	$(CPP) $^ $(LDFLAGS) -m32 -o $@

mapreduce_x86_64_dbg.nexe: $(OBJECTS_X86_64_DBG)
	$(CPP) $^ $(LDFLAGS) -m64 -o $@

# Target to clean up
clean:
	-$(RM) *.nmf *.o *.obj *.nexe

