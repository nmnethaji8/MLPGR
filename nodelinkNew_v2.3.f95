MODULE NODELINKMOD
   IMPLICIT NONE

   TYPE :: NODELINKTYP
      INTEGER(KIND=4)::CS1
      INTEGER(KIND=4),MANAGED,ALLOCATABLE::CELL(:,:)
      INTEGER(KIND=4)::CELLX,CELLY,CELLZ,CELLN
      REAL(KIND=8),MANAGED::REFBL(3),REFTR(3)
      REAL(KIND=8)::CELLR
   CONTAINS
      PROCEDURE :: INITCELL
      PROCEDURE :: FILLCELL
      !PROCEDURE :: FINDCELL
   END TYPE NODELINKTYP

CONTAINS

   SUBROUTINE INITCELL(THIS,CELX,CELY,CELZ,I)
      IMPLICIT NONE

      CLASS(NODELINKTYP),INTENT(INOUT)::THIS
      INTEGER(KIND=4),INTENT(IN)::CELX,CELY,CELZ,I

      THIS%CELLX=CELX+2
      THIS%CELLY=CELY+2
      THIS%CELLZ=CELZ+2
      THIS%CELLN=THIS%CELLX*THIS%CELLY*THIS%CELLZ
      THIS%CS1=I
      ALLOCATE(THIS%CELL(0:THIS%CELLN-1,0:THIS%CS1))

   END SUBROUTINE INITCELL

   SUBROUTINE FILLCELL(THIS,NP,CX,CY,CZ,INCELLR,CP1,CP2)
      IMPLICIT NONE

      CLASS(NODELINKTYP),INTENT(INOUT)::THIS
      INTEGER(KIND=4),INTENT(IN)::NP
      REAL(KIND=8),INTENT(IN)::CX(NP),CY(NP),CZ(NP),INCELLR
      REAL(KIND=8),INTENT(IN)::CP1(3),CP2(3) !! BOTTOMLEFT AND TOPRIGHT CORNER

      INTEGER(KIND=4)::IX,IY,IZ,I,J,K,L,IPOS,INUM

      THIS%REFBL=CP1
      THIS%REFTR=CP2
      THIS%CELLR=INCELLR

      IX = FLOOR( (THIS%REFTR(1)-THIS%REFBL(1)) / THIS%CELLR )
      IY = FLOOR( (THIS%REFTR(2)-THIS%REFBL(2)) / THIS%CELLR )
      IZ = FLOOR( (THIS%REFTR(3)-THIS%REFBL(3)) / THIS%CELLR )
      IF((IX.GT.THIS%CELLX).OR.(IY.GT.THIS%CELLY).OR.(IZ.GT.THIS%CELLZ))THEN
         WRITE(8,'(" [ERR] INCREASE CELLX OR CELLY OR CELLZ")')
         WRITE(8,'(" [---] LIMITS ",3I10)')THIS%CELLX,THIS%CELLY,THIS%CELLZ
         WRITE(8,'(" [---] ACTUAL ",3I10)')IX,IY,IZ
         STOP
      ENDIF

      THIS%CELL(:,0)=0
      DO I=1,NP
         IX=FLOOR( (CX(I)-THIS%REFBL(1)) / THIS%CELLR )
         IY=FLOOR( (CY(I)-THIS%REFBL(2)) / THIS%CELLR )
         IZ=FLOOR( (CZ(I)-THIS%REFBL(3)) / THIS%CELLR )

         IF(IX.LT.0)IX=0
         IF(IY.LT.0)IY=0
         IF(IZ.LT.0)IZ=0
         IF(IX.GE.THIS%CELLX)IX=THIS%CELLX-1
         IF(IY.GE.THIS%CELLY)IY=THIS%CELLY-1
         IF(IZ.GE.THIS%CELLZ)IZ=THIS%CELLZ-1
         IPOS=IX+IY*THIS%CELLX+IZ*THIS%CELLY*THIS%CELLX

         INUM=THIS%CELL(IPOS,0)+1
         IF(INUM.GT.THIS%CS1)THEN
            WRITE(8,'(" [ERR] INCREASE CS1 FOR CELL")')
            WRITE(8,'(" [---] LIMITS ",I10)')THIS%CS1
            WRITE(8,'(" [---] CELL ",3I10)')IX,IY,IZ
            STOP
         ENDIF
         THIS%CELL(IPOS,0)=INUM
         THIS%CELL(IPOS,INUM)=I
      ENDDO
   END SUBROUTINE FILLCELL

   ATTRIBUTES(DEVICE) SUBROUTINE FINDCELL(THIS,CX,CY,CZ,IX,IY,IZ,IPOS)
   !USE NODELINKMOD
   IMPLICIT NONE

   TYPE(NODELINKTYP),INTENT(IN)::THIS
   REAL(KIND=8),INTENT(IN)::CX,CY,CZ
   INTEGER(KIND=4),INTENT(OUT)::IX,IY,IZ,IPOS

   IX=FLOOR((CX-THIS%REFBL(1))/THIS%CELLR)
   IY=FLOOR((CY-THIS%REFBL(2))/THIS%CELLR)
   IZ=FLOOR((CZ-THIS%REFBL(3))/THIS%CELLR)

   IF(IX.LT.0)IX=0
   IF(IY.LT.0)IY=0
   IF(IZ.LT.0)IZ=0
   IF(IX.GE.THIS%CELLX)IX=THIS%CELLX-1
   IF(IY.GE.THIS%CELLY)IY=THIS%CELLY-1
   IF(IZ.GE.THIS%CELLZ)IZ=THIS%CELLZ-1
   IPOS=IX+IY*THIS%CELLX+IZ*THIS%CELLY*THIS%CELLX

END SUBROUTINE FINDCELL

SUBROUTINE FINDCELL2(THIS,CX,CY,CZ,IX,IY,IZ,IPOS)
   !$acc routine seq
   IMPLICIT NONE

   TYPE(NODELINKTYP),INTENT(IN)::THIS
   REAL(KIND=8),INTENT(IN)::CX,CY,CZ
   INTEGER(KIND=4),INTENT(OUT)::IX,IY,IZ,IPOS

   IX=FLOOR((CX-THIS%REFBL(1))/THIS%CELLR)
   IY=FLOOR((CY-THIS%REFBL(2))/THIS%CELLR)
   IZ=FLOOR((CZ-THIS%REFBL(3))/THIS%CELLR)

   IF(IX.LT.0)IX=0
   IF(IY.LT.0)IY=0
   IF(IZ.LT.0)IZ=0
   IF(IX.GE.THIS%CELLX)IX=THIS%CELLX-1
   IF(IY.GE.THIS%CELLY)IY=THIS%CELLY-1
   IF(IZ.GE.THIS%CELLZ)IZ=THIS%CELLZ-1
   IPOS=IX+IY*THIS%CELLX+IZ*THIS%CELLY*THIS%CELLX

END SUBROUTINE FINDCELL2

END MODULE NODELINKMOD

MODULE NODELINK_3_SHA_MOD
   USE NEIGHNODES
   USE MLPGKINE
   USE NODELINKMOD
   IMPLICIT NONE
   INTEGER(KIND=4),MANAGED,ALLOCATABLE::KK(:)
CONTAINS
   ATTRIBUTES(GLOBAL) SUBROUTINE FINDDDR(MLDOM,IDSZ,LNODE,NODN,SCALE,DDL,DDR,NODEID,NWALLID,COORX,COORY,COORZ)
   IMPLICIT NONE
   INTERFACE
      ATTRIBUTES(DEVICE) SUBROUTINE SORTBYKEY(C,D,M) BIND(c, name='SORTBYKEY_')
         USE, INTRINSIC :: iso_c_binding
         INTEGER(KIND=4),VALUE::M
         INTEGER(KIND=4)::C(M)
         REAL(KIND=8)::D(M)
      END SUBROUTINE SORTBYKEY
   END INTERFACE
   TYPE(NODELINKTYP),INTENT(IN)::MLDOM
   INTEGER(KIND=4),VALUE,INTENT(IN)::NODN,LNODE,IDSZ
   REAL(KIND=8),VALUE,INTENT(IN)::DDL,SCALE
   INTEGER(KIND=4),INTENT(IN)::NWALLID(LNODE,4),NODEID(-2:NODN)
   REAL(KIND=8),INTENT(IN)::COORX(LNODE),COORY(LNODE),COORZ(LNODE)
   REAL(KIND=8),INTENT(OUT)::DDR(NODN)

   REAL(KIND=8)::DIS(IDSZ)
   INTEGER(KIND=4)::IN12(IDSZ)
   REAL(KIND=8)::CIRCLE_WATER,CIRCLE_WALL,CIRCLE_S_WALL,RIAV,DR,COFF,DS
   INTEGER(KIND=4)::I,IX,IY,IZ,IPOS,K,IX1,IY1,IZ1,IK,IN

   CIRCLE_WATER=3.D0*DDL  !DOMAIN OF WATER PARTICLES
   CIRCLE_WALL= 4.2D0*DDL !4.2D0*DDL   !DOMAIN OF WALL PARTICLES
   CIRCLE_S_WALL= 4.5D0*DDL !4.5D0*DDL   !DOMAIN OF WALL PARTICLES

   I = blockDim%x*(blockIdx%x-1) + threadIdx%x

   IF(I.LE.NODN)THEN
      IF(I.LE.NODEID(-2))RIAV=CIRCLE_WATER
      IF(I.GT.NODEID(-2))RIAV=CIRCLE_WALL
      IF(I.GT.NODEID(-2).AND.NWALLID(I,3).EQ.9)THEN
         RIAV=CIRCLE_S_WALL
      ENDIF

      CALL FINDCELL(MLDOM,COORX(I),COORY(I),COORZ(I),IX,IY,IZ,IPOS)
      K=0
      DIS=0
      IN12=0
      DO IX1=IX-1,IX+1
         DO IY1=IY-1,IY+1
            DO IZ1=IZ-1,IZ+1
               IF((IX1.GE.0.AND.IX1.LT.MLDOM%CELLX).AND.&
                  (IY1.GE.0.AND.IY1.LT.MLDOM%CELLY).AND.&
                  (IZ1.GE.0.AND.IZ1.LT.MLDOM%CELLZ))THEN

                  IPOS=IX1+IY1*MLDOM%CELLX+IZ1*MLDOM%CELLY*MLDOM%CELLX
                  DO IK=1,MLDOM%CELL(IPOS,0)
                     IN=MLDOM%CELL(IPOS,IK)
                     IF(IN.NE.I)THEN
                        DR=DSQRT((COORX(IN)-COORX(I))**2 +(COORY(IN)-COORY(I))**2 +(COORZ(IN)-COORZ(I))**2)
                        IF(DR.GT.RIAV) CYCLE
                        K=K+1
                        IF(K.GT.IDSZ)PRINT*," [ERR] INCREASE IDSZ"
                        IN12(K)=IN
                        DIS(K)=DR
                     ENDIF
                  ENDDO
               ENDIF
            ENDDO
         ENDDO
      ENDDO
      CALL SORTBYKEY(IN12(1:K),DIS(1:K),K)

      DO IX=1,K
         NLINK(I)%I(IX) = IN12(IX)
      ENDDO

      NLINK(I)%I(0) = K

      IF (K.LT.6) THEN
         PRINT*,'ERROR IN SORTD',I,K,NODEID(I)
      ENDIF

      COFF= 0.25D0 !0.1d0  !0.25D0
      DS=0D0

      IF(K.LE.3)THEN
         DS=DDL
      ELSEIF(K.LT.6)THEN
         DO IX=1,K
            DS=DS+DIS(IX)
         ENDDO
         DS=1D0*DS/K
      ELSE
         DO IX=1,6
            DS=DS+DIS(IX)
         ENDDO
         DS=1D0*DS/6D0
      ENDIF

      DDR(I)=DS*(COFF+SCALE)

      R0(I)=DS*COFF
      R(I)=DS*SCALE

      CC(I)=DDR(I)
   ENDIF
END SUBROUTINE FINDDDR
END MODULE NODELINK_3_SHA_MOD

SUBROUTINE NODELINK_3_SHA(MLDOM,LNODE,NODN,SCALE,DDL,DDR,&
   NODEID,NWALLID,COORX,COORY,COORZ)
   USE NODELINK_3_SHA_MOD
   USE CUDAFOR
   !INCLUDE 'COMMON.F'
   IMPLICIT NONE

   TYPE(NODELINKTYP),MANAGED,INTENT(IN)::MLDOM
   INTEGER(KIND=4),INTENT(IN)::NODN,LNODE
   INTEGER(KIND=4),MANAGED,INTENT(IN)::NWALLID(LNODE,4),NODEID(-2:NODN)
   REAL(KIND=8),MANAGED,INTENT(OUT)::DDR(NODN)
   REAL(KIND=8),INTENT(IN)::SCALE,DDL
   REAL(KIND=8),MANAGED,INTENT(IN)::COORX(LNODE),COORY(LNODE),COORZ(LNODE)

   INTEGER(KIND=4)::I,J,IDSZ=300

   WRITE(8,'(" [MSG] ENTERING NODELINK_3_SHA")')

   CALL FINDDDR<<<CEILING(REAL(NODN)/16),16>>>(MLDOM,IDSZ,LNODE,NODN,SCALE,DDL,DDR,NODEID,NWALLID,COORX,COORY,COORZ)
   I=cudaDeviceSynchronize()

   WRITE(8,'(" [MSG] EXITING NODELINK_3_SHA")')

   !DO I=1,NODN 
      !J=NLINK(I)%I(0)
      !WRITE(9,"(300I7)"),NLINK(I)%I(1:J)
   !ENDDO
END SUBROUTINE NODELINK_3_SHA
