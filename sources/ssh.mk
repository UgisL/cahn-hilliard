###########################
#  Run on remote machine  #
###########################
cx1 = uv113@login.cx1.hpc.imperial.ac.uk
macomp = uv113@macomp001.ma.ic.ac.uk
balbec = urbain@155.198.193.89

remoteHost ?= $(balbec)
remoteRoot ?= ~/phd/code/cahn-hilliard

ifeq ($(remoteHost), $(cx1))
	initCommand = module load intel-suite/2016.3 mpi/intel-5.1 gcc/6.2.0 hdf5/1.8.14-parallel gmsh/2.7.0 freefem++/3.49
else
	initCommand = true # Command that does nothing in bash
endif

script-% :
	echo "#!/bin/bash"                       >  $@
	echo "#PBS -m a"                         >> $@
	echo "#PBS -q standard"                  >> $@
	echo "#PBS -N $(problem)-$*"             >> $@
	echo "$(initCommand)"                    >> $@
	echo "cd $(remoteRoot)/tests/$(problem)" >> $@
	echo "make $(subst _, ,$*)"              >> $@
	chmod +x $@

pbs-% : script-%
	ssh $(remoteHost) "cd $(remoteRoot)/tests/$(problem); qsub $^"

live-% :
	ssh $(remoteHost) "$(initCommand); cd $(remoteRoot)/tests/$(problem); make $(subst _, ,$*)"
