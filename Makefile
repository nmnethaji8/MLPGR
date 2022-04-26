#Makefile for MLPG

FC = /opt/nvidia/hpc_sdk/Linux_x86_64/22.3/compilers/bin/nvfortran
nv = /opt/nvidia/hpc_sdk/Linux_x86_64/22.3/compilers/bin/nvcc
v = -Mcuda -acc #ptxinfo

mlpgrCuda:mlpgrMain.o collision_v1.o remesh_v1.o resume.o mlpgMainSubs.o SbyK.o test6.o interpFunc_v1.5.o interpNew_v1.5.o modules_v3.1.o fnptCoupling.o nodelinkNew_v2.3.o modCommon.o
	mkdir -p Export Output
	$(FC) $(v)  -c++libs -o mlpgrCuda mlpgrMain.o collision_v1.o remesh_v1.o resume.o mlpgMainSubs.o SbyK.o test6.o interpFunc_v1.5.o interpNew_v1.5.o modules_v3.1.o fnptCoupling.o nodelinkNew_v2.3.o modCommon.o -Mcudalib=cublas,cusolver,cusparse

mlpgrMain.o:mlpgrMain.f95 collision_v1.o resume.o mlpgMainSubs.o interpFunc_v1.5.o modules_v3.1.o fnptCoupling.o nodelinkNew_v2.3.o modCommon.o 
	$(FC) $(v)  -c mlpgrMain.f95 -Mcudalib=cublas,cusolver,cusparse

nodelinkNew_v2.3.o:nodelinkNew_v2.3.f95 modules_v3.1.o mlpgMainSubs.o SbyK.o
	$(FC) $(v)  -c nodelinkNew_v2.3.f95

mlpgMainSubs.o:mlpgMainSubs.f95 modCommon.o modules_v3.1.o test6.o
	$(FC) $(v)  -c mlpgMainSubs.f95 -Mcudalib=cublas,cusolver,cusparse

interpFunc_v1.5.o:interpFunc_v1.5.f95 nodelinkNew_v2.3.o interpNew_v1.5.o
	$(FC) $(v)  -c interpFunc_v1.5.f95

test6.o:test6.cu
	$(nv) -Xcompiler -fopenmp -c -I ../ test6.cu

interpNew_v1.5.o:interpNew_v1.5.f95 modules_v3.1.o
	$(FC) $(v)  -c interpNew_v1.5.f95

resume.o:resume.f95 modCommon.o modules_v3.1.o
	$(FC) $(v)  -c resume.f95

remesh_v1.o:remesh_v1.f95 modules_v3.1.o
	$(FC) $(v)  -c remesh_v1.f95

collision_v1.o:collision_v1.f95 modules_v3.1.o
	$(FC) $(v)  -c collision_v1.f95

SbyK.o:SbyK.cu
	$(nv) -dc SbyK.cu

modules_v3.1.o:modules_v3.1.f95
	$(FC) $(v)  -c modules_v3.1.f95

fnptCoupling.o:fnptCoupling.f95
	$(FC) $(v)  -c fnptCoupling.f95

modCommon.o:modCommon.f95
	$(FC) $(v) -c modCommon.f95

clean:
	rm -rf Export Output
	mkdir -p Export Output

cleanAll:
	rm -rf mlpgrCuda Export Output *.o *.mod

run:clean default