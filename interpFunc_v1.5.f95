!!------------------------- MLPG_GET_ETA --------------------------!!
MODULE KERNEL
   IMPLICIT NONE
   INTEGER(KIND=4),MANAGED,ALLOCATABLE::NNN(:),NDD(:,:)
   REAL(KIND=8),MANAGED,ALLOCATABLE::WW(:,:),PHII(:,:),AA1(:,:,:),BB(:,:,:),PB22(:,:),PP22(:,:,:),PTT(:,:)
CONTAINS
   ATTRIBUTES(GLOBAL) SUBROUTINE GET_ETA_KERNEL(FSDOM, NFS, XFS, YFS, ZFS, NOT, XOT, YOT, ZOT, ERR, DDL, NLMAX, PRINTERRMSG)
      USE NODELINKMOD
      USE INTERPNEW
      IMPLICIT NONE

      TYPE(NODELINKTYP),INTENT(IN)::FSDOM
      INTEGER(KIND=4),VALUE,INTENT(IN)::NFS,NOT,NLMAX, PRINTERRMSG
      REAL(KIND=8),INTENT(IN)::XFS(NFS),YFS(NFS),ZFS(NFS)
      REAL(KIND=8),INTENT(IN)::XOT(NOT),YOT(NOT)
      REAL(KIND=8),VALUE,INTENT(IN)::DDL
      INTEGER(KIND=4),INTENT(OUT)::ERR(NOT)
      REAL(KIND=8),INTENT(OUT)::ZOT(NOT)

      INTEGER(KIND=4)::INOD,NN
      INTEGER(KIND=4)::I,J,K,I2,NI
      INTEGER(KIND=4)::IX,IY,IZ,IPOS,IX1,IY1,IZ1
      INTEGER(KIND=4)::PLANEID=1
      REAL(KIND=8)::XQ,YQ,ZQ,PINT
      REAL(KIND=8)::RIAV,DR,DR2,ETMP,WWI
      REAL(KIND=8)::PHI(NLMAX),W(NLMAX),B(4,NLMAX)
      REAL(KIND=8)::A(4,4),AINV(4,4),PT(4)
      REAL(KIND=8)::PB2(4),PP2(4,4)
      INTEGER(KIND=4)::ND(0:NLMAX)
      REAL(KIND=8)::AA(4,NLMAX)

      RIAV=2.1D0*DDL
      INOD = blockDim%x*(blockIdx%x-1) + threadIdx%x

      IF(INOD<=NOT)THEN

         XQ=XOT(INOD)
         YQ=YOT(INOD)
         ZQ=0

         CALL WEIGHTF3_XY_SHA(FSDOM,NLMAX,NFS,XFS,YFS,XQ,YQ,&
            NN,ND,W,1,I,I2,IX,IY,IZ,IPOS,IX1,IY1,IZ1,RIAV,&
            ETMP,DR,DR2,WWI)

         !NNN(INOD)=NN

         IF(NN.LE.0)THEN
            IF(PRINTERRMSG.NE.0)THEN
               !PRINT*,"     [ERR] NO NEGH IN MLPG_GET_ETA FOR POI"
               !PRINT*,"     [---] ",XQ,YQ
            ENDIF
            ZOT(INOD)=0D0
            ERR(INOD)=1
            GOTO 20
         ENDIF

         IF(NN.LE.3)THEN
            CALL SHEPARDSF_SHA(PHI,NN,W,NLMAX,I,WWI)
            GOTO 30
         ENDIF

         CALL SHAPPARA_R_2D_SHA(NFS,4,NLMAX,A,B,NN,ND,W,&
            XFS,YFS,PLANEID,I,NI,J,K,PB2,PP2,WWI,ETMP)

         CALL BASEFUN_SHA(4,PT,XQ,YQ,ZQ)

         A(4,4)=1D0

         CALL FINDINV4X4(A,AINV,WWI)

         IF(ABS(WWI).LT.1E-15)THEN
            IF(PRINTERRMSG.NE.0)THEN
               !PRINT*,"[ERR] SINGULAR MATRIX A, ADET ",WWI
               !PRINT*,"     [---] LOC ",XQ,YQ,ZQ
            ENDIF
            CALL SHEPARDSF_SHA(PHI,NN,W,NLMAX,I,WWI)
            GOTO 30
         ENDIF

         CALL SHAPEFUN_PHI_SHA(4,NLMAX,NN,AINV,B,PT,AA,PHI,I,J,K)

30       WWI=0D0
         DO I2=1,NN
            WWI=WWI+PHI(I2)*ZFS(ND(I2))
         ENDDO
         ZOT(INOD)=WWI
         !PHII(1:NN,INOD)=PHI(1:NN)
20    ENDIF
   END SUBROUTINE GET_ETA_KERNEL

!!------------------------- MLPG_GET_ETA --------------------------!!

!!----------------------- WEIGHTF3_XY_SHA -------------------------!!
   ATTRIBUTES(DEVICE) SUBROUTINE WEIGHTF3_XY_SHA(FSDOM,NLMAX,NIN,XIN,YIN,XQ,YQ,&
      NN,ND,W,IDWEI,I,I2,IX,IY,IZ,IPOS,IX1,IY1,IZ1,RIAV,&
      ETMP,DR,DR2,WWI)
      USE NODELINKMOD
      IMPLICIT NONE

      TYPE(NODELINKTYP),INTENT(IN)::FSDOM
      INTEGER(KIND=4),INTENT(IN)::NLMAX,NIN,IDWEI
      INTEGER(KIND=4),INTENT(OUT)::NN
      INTEGER(KIND=4),INTENT(OUT)::ND(0:NLMAX)
      REAL(KIND=8),INTENT(IN)::XIN(NIN),YIN(NIN)
      REAL(KIND=8),INTENT(IN)::XQ,YQ
      REAL(KIND=8),INTENT(OUT)::W(NLMAX)

      INTEGER(KIND=4),INTENT(INOUT)::I,I2,IX,IY,IZ,IPOS,IX1,IY1,IZ1
      REAL(KIND=8),INTENT(INOUT)::RIAV,ETMP,DR,DR2,WWI

      NN=0
      ETMP=DEXP(-(1D0**2))

      !! Z=0 FOR FREE-SURFACE DOMAIN
      DR=0
      CALL FINDCELL(FSDOM,XQ,YQ,DR,IX,IY,IZ,IPOS)

      DO IX1=IX-1,IX+1
         DO IY1=IY-1,IY+1
            DO IZ1=IZ-1,IZ+1
               IF((IX1.GE.0.AND.IX1.LT.FSDOM%CELLX).AND.&
                  (IY1.GE.0.AND.IY1.LT.FSDOM%CELLY).AND.&
                  (IZ1.GE.0.AND.IZ1.LT.FSDOM%CELLZ))THEN

                  IPOS=IX1+IY1*FSDOM%CELLX+IZ1*FSDOM%CELLY*FSDOM%CELLX

                  DO I2=1,FSDOM%CELL(IPOS,0)
                     I=FSDOM%CELL(IPOS,I2)

                     DR=DSQRT((XIN(I)-XQ)**2 + (YIN(I)-YQ)**2)
                     IF(DR.LT.RIAV)THEN
                        DR2=DR/RIAV

                        IF(IDWEI.EQ.1)THEN
                           WWI=(DEXP(-(DR2**2))-ETMP)/(1D0-ETMP)
                        ELSE
                           WWI=1D0-6D0*(DR2)**2+8D0*(DR2)**3-3D0*(DR2)**4
                        ENDIF

                        IF(WWI.GT.0D0)THEN
                           NN=NN+1
                           IF(NN.LE.NLMAX)THEN
                              ND(NN)=I
                              W(NN)=WWI
                           ELSE
                              PRINT*," [ERR] INCREASE NLMAX IN WEIGHTF3_SHA"
                           ENDIF
                        ENDIF
                     ENDIF
                  ENDDO
               ENDIF
            ENDDO
         ENDDO
      ENDDO
      ND(0)=NN
   END SUBROUTINE WEIGHTF3_XY_SHA

SUBROUTINE WEIGHTF3_XY_SHA2(FSDOM,NLMAX,NIN,XIN,YIN,XQ,YQ,&
      NN,ND,W,IDWEI,I,I2,IX,IY,IZ,IPOS,IX1,IY1,IZ1,RIAV,&
      ETMP,DR,DR2,WWI)
      !$acc routine seq
      USE NODELINKMOD
      IMPLICIT NONE

      TYPE(NODELINKTYP),INTENT(IN)::FSDOM
      INTEGER(KIND=4),INTENT(IN)::NLMAX,NIN,IDWEI
      INTEGER(KIND=4),INTENT(OUT)::NN
      INTEGER(KIND=4),INTENT(OUT)::ND(0:NLMAX)
      REAL(KIND=8),INTENT(IN)::XIN(NIN),YIN(NIN)
      REAL(KIND=8),INTENT(IN)::XQ,YQ
      REAL(KIND=8),INTENT(OUT)::W(NLMAX)

      INTEGER(KIND=4),INTENT(INOUT)::I,I2,IX,IY,IZ,IPOS,IX1,IY1,IZ1
      REAL(KIND=8),INTENT(INOUT)::RIAV,ETMP,DR,DR2,WWI

      NN=0
      ETMP=DEXP(-(1D0**2))

      !! Z=0 FOR FREE-SURFACE DOMAIN
      DR=0
      CALL FINDCELL2(FSDOM,XQ,YQ,DR,IX,IY,IZ,IPOS)
      DO IX1=IX-1,IX+1
         DO IY1=IY-1,IY+1
           DO IZ1=IZ-1,IZ+1
     
             IF((IX1.GE.0.AND.IX1.LT.FSDOM%CELLX).AND.&
               (IY1.GE.0.AND.IY1.LT.FSDOM%CELLY).AND.&
               (IZ1.GE.0.AND.IZ1.LT.FSDOM%CELLZ))THEN
     
               IPOS=IX1+IY1*FSDOM%CELLX+IZ1*FSDOM%CELLY*FSDOM%CELLX
               
               DO I2=1,FSDOM%CELL(IPOS,0)
                 I=FSDOM%CELL(IPOS,I2)
                 DR=DSQRT((XIN(I)-XQ)**2 + (YIN(I)-YQ)**2 )
                 IF(DR.LT.RIAV)THEN
                   DR2=DR/RIAV
     
                   IF(IDWEI.EQ.1)THEN
                     WWI=(DEXP(-(DR2**2))-ETMP)/(1D0-ETMP)
                   ELSE
                     WWI=1D0-6D0*(DR2)**2+8D0*(DR2)**3-3D0*(DR2)**4 
                   ENDIF
     
                   IF(WWI.LE.0D0)CYCLE
                   NN=NN+1
                   IF(NN.GT.NLMAX)THEN
                     PRINT*," [ERR] INCREASE NLMAX IN WEIGHTF3_SHA"
                     STOP
                   ENDIF
                   ND(NN)=I
                   W(NN)=WWI
                 ENDIF
               ENDDO
                 
             ENDIF
     
           ENDDO
         ENDDO
       ENDDO
       ND(0)=NN
   END SUBROUTINE WEIGHTF3_XY_SHA2
   !!--------------------- END WEIGHTF3_XY_SHA -----------------------!!

   ATTRIBUTES(GLOBAL) SUBROUTINE MLPG_GET_UP_KERNEL(DOMIN,NIN,XIN,YIN,ZIN,UIN,VIN,WIN,PIN,&
      NOT,XOT,YOT,ZOT,UOT,VOT,WOT,POT,DDL,NLMAX)
      USE NODELINKMOD
      USE INTERPNEW
      IMPLICIT NONE

      TYPE(NODELINKTYP),INTENT(IN)::DOMIN
      INTEGER(KIND=4),VALUE,INTENT(IN)::NIN,NOT,NLMAX
      REAL(KIND=8),INTENT(IN)::XIN(NIN),YIN(NIN),ZIN(NIN)
      REAL(KIND=8),INTENT(IN)::UIN(NIN),VIN(NIN),WIN(NIN),PIN(NIN)
      REAL(KIND=8),INTENT(IN)::XOT(NOT),YOT(NOT),ZOT(NOT)
      REAL(KIND=8),VALUE,INTENT(IN)::DDL
      REAL(KIND=8),INTENT(OUT)::UOT(NOT),VOT(NOT),WOT(NOT),POT(NOT)

      INTEGER(KIND=4)::INOD,NN
      INTEGER(KIND=4)::I,J,K,I2,NI
      INTEGER(KIND=4)::IX,IY,IZ,IPOS,IX1,IY1,IZ1
      REAL(KIND=8)::XQ,YQ,ZQ,PINT
      REAL(KIND=8)::RIAV,DR,DR2,ETMP,WWI
      REAL(KIND=8)::PTMP,UTMP,VTMP,WTMP
      INTEGER(KIND=4)::ND(0:NLMAX)
      REAL(KIND=8)::PHI(NLMAX),W(NLMAX),B(4,NLMAX)
      REAL(KIND=8)::A(4,4),AINV(4,4),PT(4)
      REAL(KIND=8)::PB2(4),PP2(4,4)
      REAL(KIND=8)::AA(4,NLMAX)

      RIAV=2.1D0*DDL

      INOD = blockDim%x*(blockIdx%x-1) + threadIdx%x

      IF(INOD<=NOT)THEN
         XQ=XOT(INOD)
         YQ=YOT(INOD)
         ZQ=ZOT(INOD)

         CALL WEIGHTF3_SHA(DOMIN,NLMAX,NIN,XIN,YIN,ZIN,XQ,YQ,ZQ,&
            NN,ND,W,1,I,I2,IX,IY,IZ,IPOS,IX1,IY1,IZ1,RIAV,&
            ETMP,DR,DR2,WWI)

         !NNN(INOD)=NN

         IF(NN.LE.0)THEN
            !PRINT*,"[ERR] NO NEGH IN MLPG_GET_UP FOR POI"
            !PRINT*,"     [---] ",XQ,YQ,ZQ
            UOT(INOD)=0D0
            VOT(INOD)=0D0
            WOT(INOD)=0D0
            POT(INOD)=0D0
            GOTO 29
         ENDIF

         IF(NN.LE.3)THEN
            CALL SHEPARDSF_SHA(PHI,NN,W,NLMAX,I,WWI)
            GOTO 30
         ENDIF

         CALL SHAPPARA_R_SHA(NIN,4,NLMAX,A,B,NN,ND,W,&
            XIN,YIN,ZIN,I,NI,J,K,PB2,PP2,WWI)

         CALL BASEFUN_SHA(4,PT,XQ,YQ,ZQ)

         CALL FINDINV4X4(A,AINV,WWI)

         IF(ABS(WWI).LT.1E-15)THEN
            !WRITE(8,'("     [ERR] SINGULAR MATRIX A, ADET ",F15.6)')WWI
            !WRITE(8,'("     [---] LOC ",3F15.6)')XQ,YQ,ZQ
            CALL SHEPARDSF_SHA(PHI,NN,W,NLMAX,I,WWI)
            GOTO 30
         ENDIF

         CALL SHAPEFUN_PHI_SHA(4,NLMAX,NN,AINV,B,PT,AA,PHI,I,J,K)

30       UTMP=0D0
         VTMP=0D0
         WTMP=0D0
         PTMP=0D0
         DO I2=1,NN
            UTMP=UTMP+PHI(I2)*UIN(ND(I2))
            VTMP=VTMP+PHI(I2)*VIN(ND(I2))
            WTMP=WTMP+PHI(I2)*WIN(ND(I2))
            PTMP=PTMP+PHI(I2)*PIN(ND(I2))
         ENDDO
         UOT(INOD)=UTMP
         VOT(INOD)=VTMP
         WOT(INOD)=WTMP
         POT(INOD)=PTMP

         !PHII(1:NN,INOD)=PHI(1:NN)
29    ENDIF
   END SUBROUTINE MLPG_GET_UP_KERNEL

!!------------------------- WEIGHTF3_SHA --------------------------!!
   ATTRIBUTES(DEVICE) SUBROUTINE WEIGHTF3_SHA(FSDOM,NLMAX,NIN,XIN,YIN,ZIN,XQ,YQ,ZQ,&
      NN,ND,W,IDWEI,I,I2,IX,IY,IZ,IPOS,IX1,IY1,IZ1,RIAV,&
      ETMP,DR,DR2,WWI)
      USE NODELINKMOD
      IMPLICIT NONE

      TYPE(NODELINKTYP),INTENT(IN)::FSDOM
      INTEGER(KIND=4),INTENT(IN)::NLMAX,NIN,IDWEI
      INTEGER(KIND=4),INTENT(OUT)::NN
      INTEGER(KIND=4),INTENT(OUT)::ND(0:NLMAX)
      REAL(KIND=8),INTENT(IN)::XIN(NIN),YIN(NIN),ZIN(NIN)
      REAL(KIND=8),INTENT(IN)::XQ,YQ,ZQ
      REAL(KIND=8),INTENT(OUT)::W(NLMAX)

      INTEGER(KIND=4),INTENT(INOUT)::I,I2,IX,IY,IZ,IPOS,IX1,IY1,IZ1
      REAL(KIND=8),INTENT(INOUT)::RIAV,ETMP,DR,DR2,WWI

      NN=0
      ETMP=DEXP(-(1D0**2))

      !! Z=0 FOR FREE-SURFACE DOMAIN
      DR=0
      CALL FINDCELL(FSDOM,XQ,YQ,ZQ,IX,IY,IZ,IPOS)

      DO IX1=IX-1,IX+1
         DO IY1=IY-1,IY+1
            DO IZ1=IZ-1,IZ+1
               IF((IX1.GE.0.AND.IX1.LT.FSDOM%CELLX).AND.&
                  (IY1.GE.0.AND.IY1.LT.FSDOM%CELLY).AND.&
                  (IZ1.GE.0.AND.IZ1.LT.FSDOM%CELLZ))THEN

                  IPOS=IX1+IY1*FSDOM%CELLX+IZ1*FSDOM%CELLY*FSDOM%CELLX

                  DO I2=1,FSDOM%CELL(IPOS,0)
                     I=FSDOM%CELL(IPOS,I2)

                     DR=DSQRT((XIN(I)-XQ)**2 + (YIN(I)-YQ)**2 + (ZIN(I)-ZQ)**2)
                     IF(DR.LT.RIAV)THEN
                        DR2=DR/RIAV

                        IF(IDWEI.EQ.1)THEN
                           WWI=(DEXP(-(DR2**2))-ETMP)/(1D0-ETMP)
                        ELSE
                           WWI=1D0-6D0*(DR2)**2+8D0*(DR2)**3-3D0*(DR2)**4
                        ENDIF

                        IF(WWI.GT.0D0)THEN
                           NN=NN+1
                           IF(NN.GT.NLMAX)THEN
                              PRINT*," [ERR] INCREASE NLMAX IN WEIGHTF3_SHA"
                           ENDIF
                           ND(NN)=I
                           W(NN)=WWI
                        ENDIF
                     ENDIF
                  ENDDO
               ENDIF
            ENDDO
         ENDDO
      ENDDO
      ND(0)=NN
   END SUBROUTINE WEIGHTF3_SHA
!!----------------------- END WEIGHTF3_SHA ------------------------!!

!!------------------------- WEIGHTF4_SHA --------------------------!!
ATTRIBUTES(DEVICE) SUBROUTINE WEIGHTF4_SHA(FSDOM, LNODE, NLMAX, NIN, NODEID, NWALLID, &
   XIN, YIN, ZIN, XQ, YQ, ZQ, NN, ND, W, IDWEI, I, I2, IX, IY, IZ, &
   IPOS, IX1, IY1, IZ1, RIAV, ETMP, DR, DR2, WWI)
   USE NODELINKMOD
   IMPLICIT NONE
   
   TYPE(NODELINKTYP),INTENT(IN)::FSDOM
   INTEGER(KIND=4),INTENT(IN)::NLMAX,NIN,IDWEI, LNODE
   INTEGER(KIND=4),INTENT(IN)::NODEID(-7:NIN), NWALLID(LNODE,4)
   INTEGER(KIND=4),INTENT(OUT)::NN,ND(0:NLMAX)
   REAL(KIND=8),INTENT(IN)::XIN(NIN),YIN(NIN),ZIN(NIN)
   REAL(KIND=8),INTENT(IN)::XQ,YQ,ZQ
   REAL(KIND=8),INTENT(OUT)::W(NLMAX)

   INTEGER(KIND=4),INTENT(INOUT)::I,I2,IX,IY,IZ,IPOS,IX1,IY1,IZ1
   REAL(KIND=8),INTENT(INOUT)::RIAV,ETMP,DR,DR2,WWI

   NN=0
   ETMP=DEXP(-(1D0**2))

   CALL FINDCELL(FSDOM,XQ,YQ,ZQ,IX,IY,IZ,IPOS)

   DO IX1=IX-1,IX+1
      DO IY1=IY-1,IY+1
         DO IZ1=IZ-1,IZ+1
            
            IF((IX1.GE.0.AND.IX1.LT.FSDOM%CELLX).AND.&
               (IY1.GE.0.AND.IY1.LT.FSDOM%CELLY).AND.&
               (IZ1.GE.0.AND.IZ1.LT.FSDOM%CELLZ))THEN

               IPOS=IX1+IY1*FSDOM%CELLX+IZ1*FSDOM%CELLY*FSDOM%CELLX
          
               DO I2=1,FSDOM%CELL(IPOS,0)
                  I=FSDOM%CELL(IPOS,I2)

                  !! NO GHOST PARTICLES
                  IF( (NODEID(I).LT.0) .OR. (NODEID(I).GT.10) ) CYCLE

                  !! NO DISABLED PARTICLES
                  IF( (NWALLID(I,2).EQ.-10) ) CYCLE

                  DR=DSQRT((XIN(I)-XQ)**2 + (YIN(I)-YQ)**2 + (ZIN(I)-ZQ)**2)
                  IF(DR.LT.RIAV)THEN
                     DR2=DR/RIAV

                     IF(IDWEI.EQ.1)THEN
                        WWI=(DEXP(-(DR2**2))-ETMP)/(1D0-ETMP)
                     ELSE
                        WWI=1D0-6D0*(DR2)**2+8D0*(DR2)**3-3D0*(DR2)**4 
                     ENDIF

                     IF(WWI.LE.0D0)CYCLE
                     NN=NN+1
                     IF(NN.GT.NLMAX)THEN
                        PRINT*," [ERR] INCREASE NLMAX IN WEIGHTF3_SHA"
                        STOP
                     ENDIF
                     ND(NN)=I
                     W(NN)=WWI
                  ENDIF
               ENDDO
            ENDIF
         ENDDO
      ENDDO
   ENDDO
  ND(0)=NN

END SUBROUTINE WEIGHTF4_SHA
!!------------------------- WEIGHTF4_SHA --------------------------!!

!!!!----------------------- MLPG_GET_UP_KERNEL ------------------------!!
   ATTRIBUTES(GLOBAL) SUBROUTINE MLPG_GET_UP2_KERNEL(DOMIN, LNODE, NODEID, NWALLID, NIN, &
   XIN, YIN, ZIN, UIN, VIN, WIN, PIN, NOT, XOT, YOT, ZOT, &
   UOT, VOT, WOT, POT, DDL, NLMAX)
   USE NODELINKMOD
   USE INTERPNEW
   IMPLICIT NONE
   
   TYPE(NODELINKTYP),INTENT(IN)::DOMIN
   INTEGER(KIND=4),VALUE,INTENT(IN)::NIN,NOT,NLMAX, LNODE
   INTEGER(KIND=4),INTENT(IN)::NODEID(-7:NIN), NWALLID(LNODE,4)
   REAL(KIND=8),INTENT(IN)::XIN(NIN),YIN(NIN),ZIN(NIN)
   REAL(KIND=8),INTENT(IN)::UIN(NIN),VIN(NIN),WIN(NIN),PIN(NIN)
   REAL(KIND=8),INTENT(IN)::XOT(NOT),YOT(NOT),ZOT(NOT)
   REAL(KIND=8),VALUE,INTENT(IN)::DDL
   REAL(KIND=8),INTENT(OUT)::UOT(NOT),VOT(NOT),WOT(NOT),POT(NOT)

   INTEGER(KIND=4)::INOD,ND(0:NLMAX),NN
   INTEGER(KIND=4)::I,J,K,I2,NI
   INTEGER(KIND=4)::IX,IY,IZ,IPOS,IX1,IY1,IZ1
   REAL(KIND=8)::PHI(NLMAX),W(NLMAX),B(4,NLMAX)
   REAL(KIND=8)::A(4,4),AINV(4,4),PT(4)
   REAL(KIND=8)::PB2(4),PP2(4,4)
   REAL(KIND=8)::XQ,YQ,ZQ,AA(4,NLMAX),PINT
   REAL(KIND=8)::RIAV,DR,DR2,ETMP,WWI
   REAL(KIND=8)::PTMP,UTMP,VTMP,WTMP

   RIAV=2.1D0*DDL

   INOD = blockDim%x*(blockIdx%x-1) + threadIdx%x

   IF(INOD<=NOT)THEN
      
      XQ=XOT(INOD)
      YQ=YOT(INOD)
      ZQ=ZOT(INOD)

      CALL WEIGHTF4_SHA(DOMIN, LNODE, NLMAX, NIN, NODEID(-7:NIN), &
         NWALLID, XIN, YIN, ZIN, &
         XQ, YQ, ZQ, NN, ND, W, 1, I, I2, IX, IY, IZ, IPOS, &
         IX1, IY1, IZ1, RIAV, ETMP, DR, DR2, WWI)

      IF(NN.LE.0)THEN
         PRINT*,"     [ERR] NO NEGH IN MLPG_GET_UP FOR POI"
         PRINT*,"     [---] ",XQ,YQ,ZQ
         UOT(INOD)=0D0
         VOT(INOD)=0D0
         WOT(INOD)=0D0
         POT(INOD)=0D0
         GOTO 10
      ENDIF

      IF(NN.LE.3)THEN
         CALL SHEPARDSF_SHA(PHI,NN,W,NLMAX,I,WWI)
         GOTO 30
      ENDIF

      CALL SHAPPARA_R_SHA(NIN,4,NLMAX,A,B,NN,ND,W,&
         XIN,YIN,ZIN,I,NI,J,K,PB2,PP2,WWI)

      CALL BASEFUN_SHA(4,PT,XQ,YQ,ZQ)


      CALL FINDINV4X4(A,AINV,WWI)
      IF(ABS(WWI).LT.1E-15)THEN
         PRINT*,"     [ERR] SINGULAR MATRIX A, ADET ",WWI
         PRINT*,"     [---] LOC ",XQ,YQ,ZQ
         CALL SHEPARDSF_SHA(PHI,NN,W,NLMAX,I,WWI)
         GOTO 30
      ENDIF

      CALL SHAPEFUN_PHI_SHA(4,NLMAX,NN,AINV,B,PT,AA,PHI,I,J,K)

30    UTMP=0D0
      VTMP=0D0
      WTMP=0D0
      PTMP=0D0
      DO I2=1,NN
         UTMP=UTMP+PHI(I2)*UIN(ND(I2))
         VTMP=VTMP+PHI(I2)*VIN(ND(I2))
         WTMP=WTMP+PHI(I2)*WIN(ND(I2))
         PTMP=PTMP+PHI(I2)*PIN(ND(I2))
      ENDDO
      UOT(INOD)=UTMP
      VOT(INOD)=VTMP
      WOT(INOD)=WTMP
      POT(INOD)=PTMP
10 CONTINUE
   ENDIF
   END SUBROUTINE MLPG_GET_UP2_KERNEL

END MODULE KERNEL


!!----------------------------MODULE KERNEL-------------------------------------------------------!!

SUBROUTINE MLPG_GET_ETA(FSDOM, NFS, XFS, YFS, ZFS, NOT, XOT, YOT, ZOT, ERR, DDL, NLMAX, PRINTERRMSG)
   USE CUDAFOR
   USE NODELINKMOD
   USE KERNEL
   USE INTERPNEW
   IMPLICIT NONE

   TYPE(NODELINKTYP),MANAGED,INTENT(IN)::FSDOM
   INTEGER(KIND=4),INTENT(IN)::NFS,NOT,NLMAX, PRINTERRMSG
   REAL(KIND=8),MANAGED,INTENT(IN)::XFS(NFS),YFS(NFS),ZFS(NFS)
   REAL(KIND=8),MANAGED,INTENT(IN)::XOT(NOT),YOT(NOT)
   REAL(KIND=8),INTENT(IN)::DDL
   INTEGER(KIND=4),MANAGED,INTENT(OUT)::ERR(NOT)
   REAL(KIND=8),MANAGED,INTENT(OUT)::ZOT(NOT)

   INTEGER(KIND=4)::INOD,ND(0:NLMAX),NN
   INTEGER(KIND=4)::I,J,K,I2,NI
   INTEGER(KIND=4)::IX,IY,IZ,IPOS,IX1,IY1,IZ1
   INTEGER(KIND=4)::PLANEID=1
   REAL(KIND=8)::PHI(NLMAX),W(NLMAX),B(4,NLMAX)
   REAL(KIND=8)::A(4,4),AINV(4,4),PT(4)
   REAL(KIND=8)::PB2(4),PP2(4,4)
   REAL(KIND=8)::XQ,YQ,ZQ,AA(4,NLMAX),PINT
   REAL(KIND=8)::RIAV,DR,DR2,ETMP,WWI

   WRITE(8,'(" [MSG] ENTERING MLPG_GET_ETA")')
   ALLOCATE(NNN(NOT),PHII(NLMAX,NOT))
   NNN=0
   PHII=0
   !MAX(NNN)=13
   
   RIAV=2.1D0*DDL
  
   ZOT=0D0
   ERR=0

   !$acc data copyin(NOT,XOT,YOT,ZOT,FSDOM,&
   !$acc& NFS,XFS,YFS,NLMAX,RIAV,PLANEID,ERR,PRINTERRMSG,NNN,PHII)
   !$acc parallel loop private(ND,W,PHI,A,B,PB2,PP2,PT)
   DO INOD=1,NOT

      XQ=XOT(INOD)
      YQ=YOT(INOD)
      ZQ=0D0

      CALL WEIGHTF3_XY_SHA2(FSDOM,NLMAX,NFS,XFS,YFS,XQ,YQ,&
         NN,ND,W,1,I,I2,IX,IY,IZ,IPOS,IX1,IY1,IZ1,RIAV,&
         ETMP,DR,DR2,WWI)
      
      NNN(INOD)=NN
      PHII(1:NN,INOD)=W(1:NN)

      IF(NN.LE.0)THEN
         IF(PRINTERRMSG.NE.0)THEN
            PRINT*,"     [ERR] NO NEGH IN MLPG_GET_ETA FOR POI"
            PRINT*,"     [---] ",XQ,YQ
         ENDIF
         ZOT(INOD)=0D0
         ERR(INOD)=1
         CYCLE
      ENDIF

      IF(NN.LE.3)THEN
         CALL SHEPARDSF_SHA2(PHI,NN,W,NLMAX,I,WWI)
         GOTO 30
      ENDIF

      CALL SHAPPARA_R_2D_SHA2(NFS,4,NLMAX,A,B,NN,ND,W,&
         XFS,YFS,PLANEID,I,NI,J,K,PB2,PP2,WWI,ETMP)

      CALL BASEFUN_SHA2(4,PT,XQ,YQ,ZQ)

      30 WWI=0D0
      !$acc loop seq
      DO I2=1,NN
         WWI=WWI+PHI(I2)*ZFS(ND(I2))
      ENDDO
      ZOT(INOD)=WWI
   
   ENDDO
   !$acc end data

   DO I=1,NOT
   !WRITE(9,*),ZOT(I)
      WRITE(9,*),PHII(1:NNN(I),I)
   ENDDO
   !WRITE(9,*),NOT
   WRITE(8,'(" [MSG] EXITING MLPG_GET_ETA")')
   WRITE(8,*)
END SUBROUTINE MLPG_GET_ETA
!!----------------------- END MLPG_GET_ETA ------------------------!!

!!-------------------------- MLPG_GET_UP --------------------------!!
SUBROUTINE MLPG_GET_UP(DOMIN,NIN,XIN,YIN,ZIN,UIN,VIN,WIN,PIN,&
   NOT,XOT,YOT,ZOT,UOT,VOT,WOT,POT,DDL,NLMAX)
   USE NODELINKMOD
   USE CUDAFOR
   USE KERNEL
   IMPLICIT NONE

   TYPE(NODELINKTYP),MANAGED,INTENT(IN)::DOMIN
   INTEGER(KIND=4),INTENT(IN)::NIN,NOT,NLMAX
   REAL(KIND=8),MANAGED,INTENT(IN)::XIN(NIN),YIN(NIN),ZIN(NIN)
   REAL(KIND=8),MANAGED,INTENT(IN)::UIN(NIN),VIN(NIN),WIN(NIN),PIN(NIN)
   REAL(KIND=8),MANAGED,INTENT(IN)::XOT(NOT),YOT(NOT),ZOT(NOT)
   REAL(KIND=8),INTENT(IN)::DDL
   REAL(KIND=8),MANAGED,INTENT(OUT)::UOT(NOT),VOT(NOT),WOT(NOT),POT(NOT)

   INTEGER(KIND=4)::I

   !ALLOCATE(NNN(NOT),PHII(NLMAX,NOT))
   !NNN=0
   !PHII=0

   WRITE(8,'(" [MSG] ENTERING MLPG_GET_UP")')
   CALL MLPG_GET_UP_KERNEL<<<CEILING(REAL(NOT)/16),16>>>(DOMIN,NIN,XIN,YIN,ZIN,UIN,VIN,WIN,PIN,&
      NOT,XOT,YOT,ZOT,UOT,VOT,WOT,POT,DDL,NLMAX)

   WRITE(8,'(" [MSG] EXITING MLPG_GET_UP")')

   I=cudaDeviceSynchronize()

   !WRITE(9,*),NNN(:)
   !DO I=1,NOT
      !WRITE(9,*),PHII(1:NNN(I),I)
   !ENDDO
END SUBROUTINE MLPG_GET_UP
!!------------------------ END MLPG_GET_UP ------------------------!!

!!------------------------- MLPG_GET_UP2 --------------------------!!
SUBROUTINE MLPG_GET_UP2(DOMIN, LNODE, NODEID, NWALLID, NIN, &
   XIN, YIN, ZIN, UIN, VIN, WIN, PIN, NOT, XOT, YOT, ZOT, &
   UOT, VOT, WOT, POT, DDL, NLMAX)
   USE CUDAFOR
   USE NODELINKMOD
   USE KERNEL
   IMPLICIT NONE
   
   TYPE(NODELINKTYP),MANAGED,INTENT(IN)::DOMIN
   INTEGER(KIND=4),INTENT(IN)::NIN,NOT,NLMAX, LNODE
   INTEGER(KIND=4),MANAGED,INTENT(IN)::NODEID(-7:NIN), NWALLID(LNODE,4)
   REAL(KIND=8),MANAGED,INTENT(IN)::XIN(NIN),YIN(NIN),ZIN(NIN)
   REAL(KIND=8),MANAGED,INTENT(IN)::UIN(NIN),VIN(NIN),WIN(NIN),PIN(NIN)
   REAL(KIND=8),MANAGED,INTENT(IN)::XOT(NOT),YOT(NOT),ZOT(NOT)
   REAL(KIND=8),INTENT(IN)::DDL
   REAL(KIND=8),MANAGED,INTENT(OUT)::UOT(NOT),VOT(NOT),WOT(NOT),POT(NOT)

   INTEGER(KIND=4)::I,J

   WRITE(8,'(" [MSG] ENTERING MLPG_GET_UP")')

   CALL MLPG_GET_UP2_KERNEL<<<CEILING(REAL(NOT)/16),16>>>(DOMIN, LNODE, NODEID, NWALLID, NIN, &
      XIN, YIN, ZIN, UIN, VIN, WIN, PIN, NOT, XOT, YOT, ZOT, &
      UOT, VOT, WOT, POT, DDL, NLMAX)

   I=cudaDeviceSynchronize()

   WRITE(8,'(" [MSG] EXITING MLPG_GET_UP")')
   WRITE(8,*)
   
END SUBROUTINE MLPG_GET_UP2