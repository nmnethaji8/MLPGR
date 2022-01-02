MODULE INTERPNEW
  CONTAINS
  SUBROUTINE WEIGHTF1_SHA(LNODE,NLMAX,NODN,KW,R,R0,CC,NODEID,NWALLID,&
  COORX,COORY,COORZ,INOD,XQ,YQ,ZQ,ILINK,NN,ND,W,IDWEI,IDSHAPE,&
  I,I2,KW2,RIAV,CCIAV,RCI,ETMP,DEW,DR,DR2,WWI)
  USE NEIGHNODES
  IMPLICIT NONE
  
  INTEGER(KIND=4),INTENT(IN)::KW,LNODE,NLMAX,NODN,IDWEI,INOD,IDSHAPE
  INTEGER(KIND=4),INTENT(IN)::NODEID(-2:NODN),NWALLID(LNODE,4)
  INTEGER(KIND=4),INTENT(OUT)::NN,ND(0:NLMAX)
  REAL(KIND=8),INTENT(IN)::R(NODN),R0(NODN),CC(NODN)
  REAL(KIND=8),INTENT(IN)::COORX(LNODE),COORY(LNODE),COORZ(LNODE)
  REAL(KIND=8),INTENT(IN)::XQ,YQ,ZQ
  REAL(KIND=8),INTENT(OUT)::W(NLMAX)
  TYPE(MLPGCONN),INTENT(IN)::ILINK

  INTEGER(KIND=4),INTENT(INOUT)::I,I2,KW2
  REAL(KIND=8),INTENT(INOUT)::RIAV,CCIAV,RCI,ETMP,DEW,DR,DR2,WWI
  
  
  !! INCLUDING SELF AS NEIGH
  NN=0
  ND=0
  W=0D0

  IF(IDWEI.EQ.1)THEN
    !! EXPONENT WEIGHT FUNCTION
    KW2=2*KW
    DO I2=0,ILINK%I(0)
      I=ILINK%I(I2)
      IF(I2.EQ.0)I=INOD

      CCIAV=CC(INOD)/1.0D0 !! CC(INOD)/ALPHACOEFF
      RIAV =R(INOD)+R0(INOD)
      RCI=RIAV/CCIAV
      ETMP=DEXP(-(RCI)**KW2)
      DEW=1D0-ETMP
      DR=DSQRT((COORX(I)-XQ)**2 + (COORY(I)-YQ)**2 &
        + (COORZ(I)-ZQ)**2)
      DR2=DR/CCIAV
      IF(DR2.GT.2.5D0)CYCLE !! THE WEIGHT BEYONG DR=2.5 IS CLOSE TO ZERO
      WWI=(DEXP(-(DR2)**KW2)-ETMP)/DEW

      !! EXCLUDE GHOST PARTICLES NOT REQUIRED IN THIS OPERATION
      IF(NWALLID(I,2).EQ.-10) WWI=-1D0 
      
      !! TYPE(-9) GHOST INCLUDED
      IF((NODEID(I).LE.10).AND.(WWI.GT.0))THEN
        NN=NN+1
        W(NN)=WWI
        ND(NN)=I
      ENDIF
    ENDDO
    ND(0)=NN

  ELSEIF(IDWEI.EQ.2)THEN
    !! BIQUADRATIC WEIGHT FUNCTION
    DO I2=0,ILINK%I(0)
      I=ILINK%I(I2)
      IF(I2.EQ.0)I=INOD

      RIAV =R(INOD)+R0(INOD)

      IF(IDSHAPE.EQ.1)THEN
        IF(INOD.GT.NODEID(-2))THEN
          RIAV=R(INOD)*1.8D0
        ELSE
          RIAV=R(INOD)*1.2D0
        ENDIF

        IF(NODEID(I).LT.0) CYCLE
      ENDIF

      !! GHOST PARTICLE DONT INCLUDE -9 IN INTERPOLATION
      IF(IDSHAPE.EQ.2)THEN
        IF(NODEID(I).LT.0) CYCLE
      ENDIF

      DR=DSQRT((COORX(I)-XQ)**2 + (COORY(I)-YQ)**2 &
        + (COORZ(I)-ZQ)**2)
      DR2=DR/RIAV
      WWI=1D0-6D0*(DR2)**2+8D0*(DR2)**3-3D0*(DR2)**4 

      !! EXCLUDE GHOST PARTICLES NOT REQUIRED IN THIS OPERATION
      IF(NWALLID(I,2).EQ.-10) WWI=-1D0 
      
      !! TYPE(-9) GHOST INCLUDED IF IDSHAPE==0
      IF((NODEID(I).LE.10).AND.(WWI.GT.0))THEN
        NN=NN+1
        W(NN)=WWI
        ND(NN)=I
      ENDIF
    ENDDO
    ND(0)=NN
  ENDIF

  END SUBROUTINE WEIGHTF1_SHA
!!----------------------- END WEIGHTF1_SHA ------------------------!!


!!------------------------- WEIGHTF2_SHA --------------------------!!
ATTRIBUTES(HOST,DEVICE) SUBROUTINE WEIGHTF2_SHA(LNODE,NODN,NLMAX,KW,R,R0,CC,&
NODEID,NWALLID,COORX,COORY,COORZ,INOD,XQ,YQ,ZQ,ILINK,NN,ND,W,IDWEI,&
I,I2,KW2,RIAV,DR,DR2,WWI)
IMPLICIT NONE

INTEGER(KIND=4),INTENT(IN)::KW,NLMAX,NODN,IDWEI,INOD,LNODE
INTEGER(KIND=4),INTENT(IN)::NODEID(-2:NODN),NWALLID(LNODE,4)
INTEGER(KIND=4),INTENT(OUT)::NN,ND(0:NLMAX)
REAL(KIND=8),INTENT(IN)::R(NODN),R0(NODN),CC(NODN)
REAL(KIND=8),INTENT(IN)::COORX(LNODE),COORY(LNODE),COORZ(LNODE)
REAL(KIND=8),INTENT(IN)::XQ,YQ,ZQ
REAL(KIND=8),INTENT(OUT)::W(NLMAX)
INTEGER(KIND=4),INTENT(INOUT)::I,I2,KW2
REAL(KIND=8),INTENT(INOUT)::RIAV,DR,DR2,WWI
INTEGER(KIND=4),INTENT(IN)::ILINK(0:KW2)

!! Note that XQ, YQ, ZQ are not X(INOD),Y(INOD), Z(INOD)

!! INCLUDING SELF AS NEIGH
NN=0
ND=0
W=0D0

IF(IDWEI.EQ.2)THEN
  !! BIQUADRATIC WEIGHT FUNCTION
  DO I2=0,ILINK(0)
    I=ILINK(I2)
    IF(I2.EQ.0)I=INOD

      RIAV =1.05D0*(R(INOD)+R0(INOD))
      DR=DSQRT((COORX(I)-XQ)**2 + (COORY(I)-YQ)**2 + (COORZ(I)-ZQ)**2)
      DR2=DR/RIAV
      WWI=1D0-6D0*(DR2)**2+8D0*(DR2)**3-3D0*(DR2)**4 

      !EXCLUDE GHOST PARTICLES NOT REQUIRED IN THIS OPERATION
      IF(NWALLID(I,2).EQ.-10) WWI=-1D0 
      
      !! TYPE(-9) GHOST NOT INCLUDED
      IF((NODEID(I).GE.0).AND.(NODEID(I).LE.10) .AND.(WWI.GT.0))THEN
        
        NN=NN+1
        W(NN)=WWI
        ND(NN)=I
      ENDIF
  ENDDO
  ND(0)=NN
  ELSE
    PRINT*," [ERR] WEIGHT FUNCTION NOT CODED"
  STOP
ENDIF
IF (NN.LT.3)THEN
  PRINT*," [ERR] NUM OF NEIGH IN WEIGHTF2_SHA MAY BE TOO FEW" 
  PRINT*," [---] INOD NODEID NUMNEIGH" 
  PRINT*," [---] ",INOD,NODEID(INOD),NN
ENDIF

END SUBROUTINE WEIGHTF2_SHA
!!----------------------- END WEIGHTF2_SHA ------------------------!!

  !!----------------------- WEIGHTGRADF1_SHA ------------------------!!
  ATTRIBUTES(HOST,DEVICE) SUBROUTINE WEIGHTGRADF1_SHA(LNODE,NODN,NLMAX,R,R0,&
  NODEID,NWALLID,COORX,COORY,COORZ,INOD,&
  ILINK,NN,ND,RNIX,RNIY,RNIZ,RNXY,RNXZ,RNYZ,BJX,BJY,BJZ,IGHST)    
USE NEIGHNODES
IMPLICIT NONE
  
  INTEGER(KIND=4),INTENT(IN)::NLMAX,NODN,INOD,LNODE,IGHST
  INTEGER(KIND=4),INTENT(IN)::NODEID(-2:NODN),NWALLID(LNODE,4)
  INTEGER(KIND=4),INTENT(OUT)::NN,ND(0:NLMAX)
  REAL(KIND=8),INTENT(IN)::R(NODN),R0(NODN)
  REAL(KIND=8),INTENT(IN)::COORX(LNODE),COORY(LNODE),COORZ(LNODE)
  REAL(KIND=8),INTENT(OUT)::BJX(NLMAX),BJY(NLMAX),BJZ(NLMAX)
  REAL(KIND=8),INTENT(OUT)::RNIX,RNIY,RNIZ,RNXY,RNXZ,RNYZ
  TYPE(MLPGCONN),INTENT(IN)::ILINK

  INTEGER(KIND=4)::I,I2,KW2
  REAL(KIND=8)::DX,DY,DZ
  REAL(KIND=8)::RIAV,DR,DR2,WWI,XQ,YQ,ZQ  


  RNIX=0.D0   !SUM OF WEIGHT FUNCTION*(XJ-XI)**2/R(J,I)**2
  RNIY=0.D0   !SUM OF WEIGHT FUNCTION*(YJ-YI)**2/R(J,I)**2
  RNIZ=0.D0   !SUM OF WEIGHT FUNCTION*(ZJ-ZI)**2/R(J,I)**2
  RNXY=0.D0   !SUM OF WEIGHT FUNCTION*(YJ-YI)*(XJ-XI)/R(J,I)**2
  RNXZ=0.D0   !SUM OF WEIGHT FUNCTION*(XJ-XI)*(ZJ-ZI)/R(J,I)**2
  RNYZ=0.D0   !SUM OF WEIGHT FUNCTION*(YJ-YI)*(ZJ-ZI)/R(J,I)**2

  ND=0
  NN=0
  BJX=0D0
  BJY=0D0
  BJZ=0D0

  IF(ILINK%I(0).LT.2)THEN
    RETURN
  ENDIF 

  XQ=COORX(INOD)
  YQ=COORY(INOD)
  ZQ=COORZ(INOD)

  DO I2=1,ILINK%I(0)
    I=ILINK%I(I2)
    DX=XQ-COORX(I)
    DY=YQ-COORY(I)
    DZ=ZQ-COORZ(I)
    DR=DSQRT(DX**2 + DY**2 + DZ**2)

    RIAV =R(INOD)+R0(INOD)
    RIAV=2D0*RIAV

    DR2=DR/RIAV
    IF(DR2.LT.1D-10) CYCLE
    WWI=1D0-6D0*(DR2)**2+8D0*(DR2)**3-3D0*(DR2)**4 

    IF(NWALLID(I,2).EQ.-10)THEN
      WWI=-1D0
    ENDIF

    !! TYPE(-9) GHOST NOT INCLUDED
    IF((NODEID(I).GE.0).AND.(NODEID(I).LT.10))THEN
      IF(WWI.GT.1D-15)THEN
        NN=NN+1
        ND(NN)=I

        BJX(NN)=-WWI*DX/DR/DR
        BJY(NN)=-WWI*DY/DR/DR
        BJZ(NN)=-WWI*DZ/DR/DR
         
        RNIX=RNIX+(DX**2)*WWI/DR/DR
        RNIY=RNIY+(DY**2)*WWI/DR/DR
        RNIZ=RNIZ+(DZ**2)*WWI/DR/DR

        RNXY=RNXY+(DX*DY)*WWI/DR/DR
        RNXZ=RNXZ+(DX*DZ)*WWI/DR/DR
        RNYZ=RNYZ+(DY*DZ)*WWI/DR/DR
      ENDIF
    ENDIF

    !! TYPE(-9) GHOST INCLUDED IF IGHST==1
    IF((IGHST.EQ.1).AND.(NODEID(I).EQ.-9))THEN
      IF(WWI.GT.1D-15)THEN
        NN=NN+1
        ND(NN)=I

        BJX(NN)=-WWI*DX/DR/DR
        BJY(NN)=-WWI*DY/DR/DR
        BJZ(NN)=-WWI*DZ/DR/DR
         
        RNIX=RNIX+(DX**2)*WWI/DR/DR
        RNIY=RNIY+(DY**2)*WWI/DR/DR
        RNIZ=RNIZ+(DZ**2)*WWI/DR/DR

        RNXY=RNXY+(DX*DY)*WWI/DR/DR
        RNXZ=RNXZ+(DX*DZ)*WWI/DR/DR
        RNYZ=RNYZ+(DY*DZ)*WWI/DR/DR
      ENDIF
    ENDIF

  ENDDO
  ND(0)=NN
  

END SUBROUTINE WEIGHTGRADF1_SHA
!!--------------------- END WEIGHTGRADF1_SHA ----------------------!!

  ATTRIBUTES(HOST,DEVICE) SUBROUTINE SHEPARDSF_SHA(PHI,NN,W,NLMAX,I,WSUM)
  IMPLICIT NONE
      
      INTEGER(KIND=4),INTENT(IN)::NLMAX,NN  
      REAL(KIND=8),INTENT(IN)::W(NLMAX)
      REAL(KIND=8),INTENT(OUT)::PHI(NLMAX)
    
      INTEGER(KIND=4),INTENT(INOUT)::I
      REAL(KIND=8),INTENT(INOUT)::WSUM
  
      !! FIND THE SUM OF THE WEIGHT FUNDTION
      WSUM=0.D0
      DO I=1,NN
          WSUM=WSUM+W(I)
      ENDDO
  
      !! FIND THE SHAPE FUNCTION
      DO I=1,NN
          PHI(I)=W(I)/WSUM
      ENDDO
    
  END SUBROUTINE SHEPARDSF_SHA
  !!----------------------- END SHEPARDSF_SHA -----------------------!!

  !!------------------------ SHAPPARA_R_SHA -------------------------!!
  ATTRIBUTES(HOST,DEVICE) SUBROUTINE SHAPPARA_R_SHA(LNODE,MBA,NLMAX,A,B,NN,ND,W,&
  COORX,COORY,COORZ,I,NI,J,K,PB2,PP2,WEI)
  IMPLICIT NONE
  
  INTEGER(KIND=4),INTENT(IN)::MBA,NLMAX,NN,ND(0:NLMAX),LNODE
  REAL(KIND=8),INTENT(IN)::W(NLMAX)
  REAL(KIND=8),INTENT(IN)::COORX(LNODE),COORY(LNODE),COORZ(LNODE)
  REAL(KIND=8),INTENT(OUT)::A(MBA,MBA),B(MBA,NLMAX)
  
  INTEGER(KIND=4),INTENT(INOUT)::I,NI,J,K
  REAL(KIND=8),INTENT(INOUT)::PB2(MBA),PP2(MBA,MBA)
  REAL(KIND=8),INTENT(INOUT)::WEI  

  PB2=0D0
  PP2=0D0
  A=0D0
  B=0D0

  DO I=1,NN
    NI=ND(I)
    WEI=W(I)


    !! BASE FUNCTION
    CALL BASEFUN_SHA(MBA,PB2,COORX(NI),COORY(NI),COORZ(NI))
    DO J=1,MBA
      DO K=1,MBA
        PP2(J,K)=PB2(J)*PB2(K)
      ENDDO
    ENDDO


    DO J=1,MBA
      DO K=1,MBA
        A(J,K)=A(J,K)+PP2(J,K)*WEI
      ENDDO
      B(J,I)=PB2(J)*WEI
    ENDDO

  ENDDO

  A(2,1)=A(1,2)
  A(3,1)=A(1,3)
  A(3,2)=A(2,3)
  A(4,1)=A(1,4)
  A(4,2)=A(2,4)
  A(4,3)=A(3,4)
END SUBROUTINE SHAPPARA_R_SHA
!!---------------------- END SHAPPARA_R_SHA -----------------------!!

  !!----------------------- SHAPPARA_R_2D_SHA -----------------------!!
  ATTRIBUTES(DEVICE) SUBROUTINE SHAPPARA_R_2D_SHA(LNODE,MBA,NLMAX,A,B,NN,ND,W,&
      COOR1,COOR2,PLANEID,I,NI,J,K,PB2,PP2,WEI,TMPR)
  IMPLICIT NONE
  
      INTEGER(KIND=4),INTENT(IN)::MBA,NLMAX,NN,ND(0:NLMAX),LNODE,PLANEID
      REAL(KIND=8),INTENT(IN)::W(NLMAX)
      REAL(KIND=8),INTENT(IN)::COOR1(LNODE),COOR2(LNODE)
      REAL(KIND=8),INTENT(OUT)::A(MBA,MBA),B(MBA,NLMAX)
  
      INTEGER(KIND=4),INTENT(INOUT)::I,NI,J,K
      REAL(KIND=8),INTENT(INOUT)::PB2(MBA),PP2(MBA,MBA)
      REAL(KIND=8),INTENT(INOUT)::WEI,TMPR

      !! PLANEID - SELECT THE 2D PLANE
      !! 1 - XY PLANE. Z=0.   COOR1=X. COOR2=Y
      !! 2 - YZ PLANE. X=0.   COOR1=Y. COOR2=Z
      !! 3 - XZ PLANE. Y=0.   COOR1=X. COOR2=Z

      PB2=0D0
      PP2=0D0
      A=0D0
      B=0D0
      TMPR=0D0

      DO I=1,NN
        NI=ND(I)
        WEI=W(I)
        
        !! BASE FUNCTION
        SELECT CASE(PLANEID)
          CASE(1)
            CALL BASEFUN_SHA(MBA,PB2,COOR1(NI),COOR2(NI),TMPR)
          CASE(2)
            CALL BASEFUN_SHA(MBA,PB2,TMPR,COOR1(NI),COOR2(NI))
          CASE(3)
            CALL BASEFUN_SHA(MBA,PB2,COOR1(NI),TMPR,COOR2(NI))
          CASE DEFAULT !Changed Default case
            CALL BASEFUN_SHA(MBA,PB2,COOR1(NI),COOR2(NI),TMPR)
          END SELECT

      DO J=1,MBA
        DO K=1,MBA
          PP2(J,K)=PB2(J)*PB2(K)
        ENDDO
      ENDDO

      DO J=1,MBA
        DO K=1,MBA
          A(J,K)=A(J,K)+PP2(J,K)*WEI
        ENDDO
        B(J,I)=PB2(J)*WEI
      ENDDO
    ENDDO
    A(2,1)=A(1,2)
    A(3,1)=A(1,3)
    A(3,2)=A(2,3)
    A(4,1)=A(1,4)
    A(4,2)=A(2,4)
    A(4,3)=A(3,4)
  END SUBROUTINE SHAPPARA_R_2D_SHA
  !!--------------------- END SHAPPARA_R_2D_SHA ---------------------!!

  !!-------------------------- BASEFUN_SHA --------------------------!!
  ATTRIBUTES(HOST,DEVICE) SUBROUTINE BASEFUN_SHA(MBA,PT,XQ,YQ,ZQ)
  IMPLICIT NONE
  
    INTEGER(KIND=4),INTENT(IN)::MBA
    REAL(KIND=8),INTENT(IN)::XQ,YQ,ZQ
    REAL(KIND=8),INTENT(OUT)::PT(MBA)

    IF(MBA.EQ.4)THEN
      PT(1)=1.0
      PT(2)=XQ
      PT(3)=YQ
      PT(4)=ZQ
    ENDIF
  
  END SUBROUTINE BASEFUN_SHA
  !!------------------------ END BASEFUN_SHA ------------------------!!

  !!------------------------ SHAPEFUN_PHI_SHA -----------------------!!
  ATTRIBUTES(HOST,DEVICE) SUBROUTINE SHAPEFUN_PHI_SHA(MBA,NLMAX,NN,AINV,B,PT,AA,PHI,I,J,K)
  IMPLICIT NONE
    
    INTEGER(KIND=4),INTENT(IN)::MBA,NLMAX,NN
    REAL(KIND=8),INTENT(IN)::AINV(MBA,MBA),B(MBA,NLMAX),PT(MBA)
    REAL(KIND=8),INTENT(OUT)::PHI(NLMAX),AA(MBA,NLMAX)
    
    INTEGER(KIND=4),INTENT(INOUT)::I,J,K
  
    DO I=1,MBA
      DO J=1,NN
        AA(I,J)=0D0
        DO K=1,MBA
          AA(I,J)=AA(I,J)+AINV(I,K)*B(K,J)
        ENDDO
      ENDDO
    ENDDO
    
    DO I=1,NN
      PHI(I)=0D0
      DO J=1,MBA
        PHI(I)=PHI(I)+PT(J)*AA(J,I)
      ENDDO
    ENDDO
  
  END SUBROUTINE SHAPEFUN_PHI_SHA
  !!---------------------- END SHAPEFUN_PHI_SHA ---------------------!!

  !!--------------------------- FINDINV4X4 --------------------------!!
  ATTRIBUTES(HOST,DEVICE) SUBROUTINE FINDINV4X4(A,AINV,ADET)
  IMPLICIT NONE
  
    REAL(KIND=8),INTENT(IN)::A(4,4)
    REAL(KIND=8),INTENT(OUT)::AINV(4,4)
    
    REAL(KIND=8),INTENT(INOUT)::ADET
  
    AINV=0D0
  
    ADET=(-A(1,1))*(A(2,4)**2)*A(3,3) + (A(1,4)**2)*(A(2,3)**2 &
        - A(2,2)*A(3,3)) + 2d0*A(1,1)*A(2,3)*A(2,4)*A(3,4) &
      + (A(1,2)**2)*(A(3,4)**2) - A(1,1)*A(2,2)*(A(3,4)**2) &
      - 2d0*A(1,4)*(A(1,3)*A(2,3)*A(2,4) - A(1,2)*A(2,4)*A(3,3) &
        - A(1,3)*A(2,2)*A(3,4) + A(1,2)*A(2,3)*A(3,4)) &
      - A(1,1)*(A(2,3)**2)*A(4,4) - (A(1,2)**2)*A(3,3)*A(4,4) &
      + A(1,1)*A(2,2)*A(3,3)*A(4,4) + (A(1,3)**2)*(A(2,4)**2 &
        - A(2,2)*A(4,4)) + A(1,2)*A(1,3)*(-2d0*A(2,4)*A(3,4) &
        + 2d0*A(2,3)*A(4,4))
  
  
    AINV(1,1)=(-A(2,4)**2)*A(3,3) + 2D0*A(2,3)*A(2,4)*A(3,4) &
      - A(2,2)*A(3,4)**2 - A(2,3)**2*A(4,4) + A(2,2)*A(3,3)*A(4,4)
  
    AINV(1,2)=A(1,4)*A(2,4)*A(3,3) - A(1,4)*A(2,3)*A(3,4) &
      - A(1,3)*A(2,4)*A(3,4) + A(1,2)*A(3,4)**2 &
      + A(1,3)*A(2,3)*A(4,4) - A(1,2)*A(3,3)*A(4,4)
  
    AINV(1,3)=(-A(1,4))*A(2,3)*A(2,4) + A(1,3)*A(2,4)**2 &
      + A(1,4)*A(2,2)*A(3,4) - A(1,2)*A(2,4)*A(3,4) &
      - A(1,3)*A(2,2)*A(4,4) + A(1,2)*A(2,3)*A(4,4)
  
    AINV(1,4)=(-A(1,3))*A(2,3)*A(2,4) + A(1,2)*A(2,4)*A(3,3) &
      + A(1,4)*(A(2,3)**2 - A(2,2)*A(3,3)) &
      + A(1,3)*A(2,2)*A(3,4) - A(1,2)*A(2,3)*A(3,4)
  
    AINV(2,1)=AINV(1,2)
  
    AINV(2,2)=(-A(1,4)**2)*A(3,3) + 2D0*A(1,3)*A(1,4)*A(3,4) &
      - A(1,1)*A(3,4)**2 - A(1,3)**2*A(4,4) + A(1,1)*A(3,3)*A(4,4)
  
    AINV(2,3)=A(1,4)**2*A(2,3) + A(1,1)*A(2,4)*A(3,4) &
      - A(1,4)*(A(1,3)*A(2,4) + A(1,2)*A(3,4)) &
      + A(1,2)*A(1,3)*A(4,4) - A(1,1)*A(2,3)*A(4,4)
  
    AINV(2,4)=A(1,3)**2*A(2,4) + A(1,2)*A(1,4)*A(3,3) &
      - A(1,1)*A(2,4)*A(3,3) + A(1,1)*A(2,3)*A(3,4) &
      - A(1,3)*(A(1,4)*A(2,3) + A(1,2)*A(3,4))
  
    AINV(3,1)=AINV(1,3)
  
    AINV(3,2)=AINV(2,3)
  
    AINV(3,3)=(-A(1,4)**2)*A(2,2) + 2D0*A(1,2)*A(1,4)*A(2,4) &
      - A(1,1)*A(2,4)**2 - A(1,2)**2*A(4,4) + A(1,1)*A(2,2)*A(4,4)
  
    AINV(3,4)=A(1,3)*A(1,4)*A(2,2) - A(1,2)*A(1,4)*A(2,3) &
      - A(1,2)*A(1,3)*A(2,4) + A(1,1)*A(2,3)*A(2,4) &
      + A(1,2)**2*A(3,4) - A(1,1)*A(2,2)*A(3,4)
  
    AINV(4,1)=AINV(1,4)
  
    AINV(4,2)=AINV(2,4)
  
    AINV(4,3)=AINV(3,4)
  
    AINV(4,4)=(-A(1,3)**2)*A(2,2) + 2D0*A(1,2)*A(1,3)*A(2,3) &
      - A(1,1)*A(2,3)**2 - A(1,2)**2*A(3,3) + A(1,1)*A(2,2)*A(3,3)
  
  
    IF(ABS(ADET).LT.1E-15)THEN
      AINV=0D0
      AINV(1,1)=1D0
      AINV(2,2)=1D0
      AINV(3,3)=1D0
      AINV(4,4)=1D0
    ELSE
      AINV=AINV/ADET
    ENDIF
  
  END SUBROUTINE FINDINV4X4
  !!------------------------- END FINDINV4X4 ------------------------!!

  ATTRIBUTES(HOST,DEVICE) SUBROUTINE SEARCH(I,J,ND,NN)
  IMPLICIT NONE
        
  INTEGER(KIND=4),INTENT(IN)::NN,ND(1:NN),I
  INTEGER(KIND=4),INTENT(OUT)::J
  
  INTEGER(KIND=4)::K
  J=0
  DO K=1,NN
    IF(I.EQ.ND(K))J=K
  ENDDO
  END SUBROUTINE SEARCH

!!----------------------- STIFFNESS_T1_SHA ------------------------!!
ATTRIBUTES(HOST,DEVICE) SUBROUTINE STIFFNESS_T1_SHA(NLMAX,NLMAX2,WORK,NN,ND,NN2,ND2,PHI,COEF)
IMPLICIT NONE
  
  INTEGER(KIND=4),INTENT(IN)::NLMAX,NLMAX2,NN,ND(0:NLMAX)
  REAL(KIND=8),INTENT(IN)::PHI(NLMAX),COEF
  REAL(KIND=8),INTENT(INOUT)::WORK(NLMAX2)
  INTEGER(KIND=4),INTENT(INOUT)::NN2,ND2(0:NLMAX2)

  INTEGER(KIND=4)::I,I2,J

  IF(NN2.EQ.0)THEN 
    ND2(0:NN)=ND(0:NN)
    NN2=NN
  ENDIF

  DO I2=1,NN 
    I=ND(I2)
    CALL SEARCH(I,J,ND2(1:NN2),NN2)
    IF(J.NE.0)THEN
      WORK(J)=WORK(J)+COEF*PHI(I2)
    ELSE 
      NN2=NN2+1
      ND2(NN2)=I 
      WORK(NN2)=WORK(NN2)+COEF*PHI(I2)
      ND2(0)=NN2
    ENDIF
  ENDDO

END SUBROUTINE STIFFNESS_T1_SHA
!!--------------------- END STIFFNESS_T1_SHA ----------------------!!

END MODULE INTERPNEW

!!---------------------- ASSEMATRIX_MLPG_SHA ----------------------!!
SUBROUTINE ASSEMATRIX_MLPG_SHA(LNODE,NODN,NODEID,NWALLID,FB,PRESS_DR,&
  GRA,H0,KW,COORX,COORY,COORZ,SNX,SNY,SNZ,NLMAX,MBA,I_WM)
USE MLPGKINE
USE MLPGSTORAGE
USE NEIGHNODES
USE INTERPNEW
IMPLICIT NONE
  
  INTEGER(KIND=4),INTENT(IN)::LNODE,NODN
  INTEGER(KIND=4),INTENT(IN)::KW,NODEID(-2:NODN),I_WM
  INTEGER(KIND=4),INTENT(IN)::NWALLID(LNODE,4),NLMAX,MBA
  REAL(KIND=8),INTENT(OUT)::FB(LNODE)
  REAL(KIND=8),INTENT(IN)::GRA,H0
  REAL(KIND=8),INTENT(IN)::PRESS_DR(NODEID(-1)-NODEID(-2))
  REAL(KIND=8),INTENT(IN)::COORX(LNODE),COORY(LNODE),COORZ(LNODE)
  REAL(KIND=8),INTENT(IN)::SNX(LNODE),SNY(LNODE),SNZ(LNODE)
  
  INTEGER(KIND=4)::NREAL,NWATER,I,J,K,I2,NI
  INTEGER(KIND=4)::INOD,IID,IWID2
  INTEGER(KIND=4)::ND(0:NLMAX),NN,KW2
  REAL(KIND=8)::BJX(NLMAX),BJY(NLMAX),BJZ(NLMAX)
  REAL(KIND=8)::RNIX,RNIY,RNIZ,RNXY,RNXZ,RNYZ
  REAL(KIND=8)::SHUX,SHUY,SHUZ,SHU,WSUM
  REAL(KIND=8)::W(NLMAX),PHI(NLMAX)
  REAL(KIND=8)::A(3,3),AINV(3,3),ADET,AA2(MBA,NLMAX)
  REAL(KIND=8)::RIAV,CCIAV,RCI,ETMP,DEW,DR,DR2,WWI
  REAL(KIND=8)::XQ,YQ,ZQ,B2(MBA,NLMAX)
  REAL(KIND=8)::A2(MBA,MBA),A2INV(MBA,MBA),PT(MBA)
  REAL(KIND=8)::PB2(MBA),PP2(MBA,MBA)
  TYPE(MLPGCONN)::ILINK

  NREAL=NODEID(-1)
  NWATER=NODEID(-2)
  FB(1:NREAL)=0D0
  LINKTAB=0
  SKK=0D0
  IVV(1:NREAL)=0

  !! WALL ONLY
  DO INOD=NWATER+1,NREAL
    IID=NODEID(INOD)
    IWID2=NWALLID(INOD,2)

    IF((IWID2.EQ.-11).OR.(IWID2.EQ.-10))THEN
      LINKTAB((INOD-1)*IVV(0)+1)=INOD
      SKK((INOD-1)*IVV(0)+1)=1D0
      IVV(INOD)=1
      FB(INOD)=(COORZ(INOD)-H0)*ROU(INOD)*GRA
      CYCLE
    ENDIF

    IF(NWALLID(INOD,4).EQ.3)THEN
      WRITE(8,*)'[ERR] NOT CODED FOR NWALLID(INOD,4).EQ.3'
      STOP
    ENDIF

    IF(NWALLID(INOD,3).EQ.9)THEN
      ! WRITE(8,*)'[ERR] NOT CODED FOR NWALLID(INOD,3).EQ.9'
      ! STOP
      XQ=COORX(INOD)
      YQ=COORY(INOD)
      ZQ=COORZ(INOD)
      ILINK=NLINK(INOD)

      CALL WEIGHTF1_SHA(LNODE,NLMAX,NODN,KW,R,R0,CC,NODEID,NWALLID,&
      COORX,COORY,COORZ,INOD,XQ,YQ,ZQ,ILINK,&
      NN,ND,W,2,1,I,I2,KW2,RIAV,CCIAV,RCI,ETMP,DEW,DR,DR2,WWI)

      IF (NN.LE.0) THEN
        !WRITE(8,*)'WARNING: NO NODE NEAR THE POINT'
        !WRITE(8,*)'SHAPE FUNCTION ASSIGNED 1'
        NN=1
        ND(0)=1
        W(1)=1.0D0
        ND(1)=INOD
        PHI(1)=1.0D0
        GOTO 30
      ENDIF

      IF(NN.LE.3)THEN
        CALL SHEPARDSF_SHA(PHI,NN,W,NLMAX,I,WWI)
        GOTO 30
      ENDIF

      CALL SHAPPARA_R_SHA(LNODE,MBA,NLMAX,A2,B2,NN,ND,W,&
        COORX,COORY,COORZ,I,NI,J,K,PB2,PP2,WWI)

      CALL BASEFUN_SHA(MBA,PT,XQ,YQ,ZQ)

      IF(MBA.EQ.4)THEN
        CALL FINDINV4X4(A2,A2INV,WWI)
        IF(ABS(WWI).LT.1E-15)THEN
          WRITE(8,'("     [ERR] SINGULAR MATRIX A, ADET ",F15.6)')WWI
          WRITE(8,'("     [---] LOC ",3F15.6)')XQ,YQ,ZQ
          CALL SHEPARDSF_SHA(PHI,NN,W,NLMAX,I,WWI)
          GOTO 30
        ENDIF
      ELSE
        WRITE(8,'(" [ERR] FINDINV NOT CODED FOR MBA =",I10)')MBA
        STOP
      ENDIF

      CALL SHAPEFUN_PHI_SHA(MBA,NLMAX,NN,A2INV,B2,PT,AA2,PHI,I,J,K)

      30  CONTINUE
      DO I2=2,NN
        I=ND(I2)
        LINKTAB((INOD-1)*IVV(0)+I2-1)=I
        SKK((INOD-1)*IVV(0)+I2-1)=-PHI(I2)
      ENDDO
      IVV(INOD)=NN
      LINKTAB((INOD-1)*IVV(0)+NN)=INOD
      SKK((INOD-1)*IVV(0)+NN)=1-PHI(1)
      FB(INOD)=0D0
      CYCLE
    ENDIF

    ILINK=NLINK(INOD)

    CALL WEIGHTGRADF1_SHA(LNODE,NODN,NLMAX,R,R0,&
    NODEID,NWALLID,COORX,COORY,COORZ,INOD,&
    ILINK,NN,ND,RNIX,RNIY,RNIZ,RNXY,RNXZ,RNYZ,BJX,BJY,BJZ,0)

    IF(NN.LT.3)THEN
      RNXY=0D0
      RNXZ=0D0
      RNYZ=0D0
    ENDIF

    A(1,1)=1.D0
    A(1,2)=RNXY/RNIX
    A(1,3)=RNXZ/RNIX

    A(2,1)=RNXY/RNIY
    A(2,2)=1.D0
    A(2,3)=RNYZ/RNIY
    
    A(3,1)=RNXZ/RNIZ
    A(3,2)=RNYZ/RNIZ
    A(3,3)=1.D0

    ADET=1D0 - A(1,2)*A(2,1) - A(1,3)*A(3,1) + A(1,2)*A(2,3)*A(3,1) + A(1,3)*A(2,1)*A(3,2) - A(2,3)*A(3,2)

    AINV(1,1)=1D0 - A(2,3)*A(3,2)
    AINV(1,2)=-A(1,2) + A(1,3)*A(3,2)
    AINV(1,3)=-A(1,3) + A(1,2)*A(2,3)

    AINV(2,1)=-A(2,1) + A(2,3)*A(3,1)
    AINV(2,2)=1D0 - A(1,3)*A(3,1)
    AINV(2,3)=-A(2,3) + A(2,1)*A(1,3)

    AINV(3,1)=-A(3,1) + A(3,2)*A(2,1)    
    AINV(3,2)=-A(3,2) + A(3,1)*A(1,2)
    AINV(3,3)=1D0 - A(1,2)*A(2,1)    

    AINV=AINV/ADET

    WSUM=0D0
    DO I2=1,NN
      I=ND(I2)
      SHUX=(AINV(1,1)*BJX(I2)/RNIX + AINV(1,2)*BJY(I2)/RNIY + AINV(1,3)*BJZ(I2)/RNIZ)
      SHUY=(AINV(2,1)*BJX(I2)/RNIX + AINV(2,2)*BJY(I2)/RNIY + AINV(2,3)*BJZ(I2)/RNIZ)
      SHUZ=(AINV(3,1)*BJX(I2)/RNIX + AINV(3,2)*BJY(I2)/RNIY + AINV(3,3)*BJZ(I2)/RNIZ)

      SHU = SHUX*SNX(INOD) + SHUY*SNY(INOD) + SHUZ*SNZ(INOD)
      LINKTAB((INOD-1)*IVV(0)+I2)=I
      SKK((INOD-1)*IVV(0)+I2)=SHU
      WSUM=WSUM-SHU
    ENDDO

    IVV(INOD)=NN+1
    LINKTAB((INOD-1)*IVV(0)+NN+1)=INOD
    SKK((INOD-1)*IVV(0)+NN+1)=WSUM
    FB(INOD)=0D0
  ENDDO

  !! FREE SURFACE PARTICLES
  DO INOD=1,NWATER
    IF((NODEID(INOD).EQ.4).OR.(NWALLID(INOD,1).EQ.4).OR.&
      (NWALLID(INOD,2).EQ.-10))THEN

      IVV(INOD)=1
      SKK((INOD-1)*IVV(0)+1)=1
      LINKTAB((INOD-1)*IVV(0)+1)=INOD
      FB(INOD)=(COORZ(INOD)-H0)*ROU(INOD)*GRA
    ENDIF
  ENDDO

  !! WAVEMAKER PARTICLES
  K=0
  IF(I_WM.EQ.15)THEN
    DO INOD=NWATER+1,NREAL
      I2=INOD-NODEID(-2)
      IF(NODEID(INOD).NE.8)THEN
        WRITE(8,'(" [INF] WAVEMAKER PARTICLES ASSEMATRIX ",I10)')K
        EXIT
      ENDIF
      K=K+1
      IVV(INOD)=1
      SKK((INOD-1)*IVV(0)+1)=1
      LINKTAB((INOD-1)*IVV(0)+1)=INOD
      FB(INOD)=-PRESS_DR(I2)
    ENDDO
  ENDIF

END SUBROUTINE ASSEMATRIX_MLPG_SHA

MODULE FILL_MAT
  IMPLICIT NONE 
  INTEGER(KIND=4),MANAGED,ALLOCATABLE::NNN(:),NDD(:,:)
  REAL(KIND=8),MANAGED,ALLOCATABLE::WORKK(:,:)
  CONTAINS
  ATTRIBUTES(GLOBAL) SUBROUTINE FILL_MAT_KER(LNODE,NODN,NODEID,NWALLID,&
  COORX,COORY,COORZ,NLMAX,MBA,KW,R1,DDR,DT,FB)
  USE MLPGKINE
  USE MLPGSTORAGE
  USE NEIGHNODES
  USE INTERPNEW
  IMPLICIT NONE
  INTEGER(KIND=4),VALUE,INTENT(IN)::KW,LNODE,NODN
  INTEGER(KIND=4),MANAGED,INTENT(IN)::NODEID(-2:NODN)
  INTEGER(KIND=4),MANAGED,INTENT(IN)::NWALLID(LNODE,4)
  INTEGER(KIND=4),VALUE,INTENT(IN)::NLMAX,MBA
  REAL(KIND=8),MANAGED,INTENT(IN)::COORX(LNODE),COORY(LNODE),COORZ(LNODE)
  REAL(KIND=8),MANAGED,INTENT(IN)::DDR(NODN)
  REAL(KIND=8),VALUE,INTENT(IN)::R1,DT
  REAL(KIND=8),MANAGED,INTENT(INOUT)::FB(LNODE)

  INTEGER(KIND=4)::INOD,ND(0:NLMAX),NN,ND2(0:4*NLMAX),NN2,KW2
  INTEGER(KIND=4)::I,J,K,I2,INTI,NI
  REAL(KIND=8)::PHI(NLMAX),W(NLMAX),B(MBA,NLMAX)
  REAL(KIND=8)::A(MBA,MBA),AINV(MBA,MBA),PT(MBA)
  REAL(KIND=8)::PB2(MBA),PP2(MBA,MBA)
  REAL(KIND=8)::XQ,YQ,ZQ,AA(MBA,NLMAX)
  REAL(KIND=8)::RIAV,DR,DR2,R0I,TMPR,ROUI,WWI
  REAL(KIND=8)::PI,XINT,YINT,ZINT,WSUM
  REAL(KIND=8)::UINT(6),VINT(6),WINT(6)
  REAL(KIND=8)::DRINT(6,3),WORK(4*NLMAX)
  INTEGER(KIND=4),ALLOCATABLE::ILINK(:)

  PI=ATAN(1D0)*4D0
  ND2=0
  NN2=0
  WORK=0D0

  DRINT(1,:)=(/1D0, 0D0, 0D0/)
  DRINT(2,:)=(/0D0, 1D0, 0D0/)
  DRINT(3,:)=(/-1D0, 0D0, 0D0/)
  DRINT(4,:)=(/0D0, -1D0, 0D0/)
  DRINT(5,:)=(/0D0, 0D0, 1D0/)
  DRINT(6,:)=(/0D0, 0D0, -1D0/)

  INOD = blockDim%x*(blockIdx%x-1) + threadIdx%x

  IF(INOD.LE.NODEID(-2))THEN

    IF(NWALLID(INOD,3).EQ.9)GOTO 100
    IF((NODEID(INOD).NE.0).OR.(NWALLID(INOD,1).EQ.4).OR.(NWALLID(INOD,2).EQ.-10))GOTO 100

    R0I=R0(INOD)
    XQ=COORX(INOD)
    YQ=COORY(INOD)
    ZQ=COORZ(INOD)
    KW2=NLINK(INOD)%I(0)
    ALLOCATE(ILINK(0:KW2))
    ILINK=NLINK(INOD)%I
    ROUI=ROU(INOD)
    UINT=0D0
    VINT=0D0
    WINT=0D0

    DO INTI=1,6
      XINT=XQ+R0I*DRINT(INTI,1)
      YINT=YQ+R0I*DRINT(INTI,2)
      ZINT=ZQ+R0I*DRINT(INTI,3)

      CALL WEIGHTF2_SHA(LNODE,NODN,NLMAX,KW,R,R0,CC,&
      NODEID,NWALLID,COORX,COORY,COORZ,INOD,&
      XINT,YINT,ZINT,ILINK,NN,ND,W,2,&
      I,I2,KW2,RIAV,DR,DR2,WWI)

      IF (NN.LE.0) THEN
        !WRITE(8,*)'WARNING: NO NODE NEAR THE POINT'
        !WRITE(8,*)'SHAPE FUNCTION ASSIGNED 1'
        NN=1
        ND(0)=1
        W(1)=1.0D0
        ND(1)=INOD
        PHI(1)=1.0D0
        GOTO 30
      ENDIF

      IF(NN.LE.3)THEN
        CALL SHEPARDSF_SHA(PHI,NN,W,NLMAX,I,WWI)        
        GOTO 30
      ENDIF

      CALL SHAPPARA_R_SHA(LNODE,MBA,NLMAX,A,B,NN,ND,W,&
        COORX,COORY,COORZ,I,NI,J,K,PB2,PP2,WWI)

      CALL BASEFUN_SHA(MBA,PT,XINT,YINT,ZINT)


      IF(MBA.EQ.4)THEN
        CALL FINDINV4X4(A,AINV,WWI)
        IF(ABS(WWI).LT.1E-15)THEN
          PRINT*,"     [ERR] SINGULAR MATRIX A, ADET ",WWI
          PRINT*,"     [---] LOC ",XQ,YQ,ZQ
          CALL SHEPARDSF_SHA(PHI,NN,W,NLMAX,I,WWI)
          GOTO 30
        ENDIF
      ELSE
        PRINT*," [ERR] FINDINV NOT CODED FOR MBA =",MBA
        STOP
      ENDIF

      CALL SHAPEFUN_PHI_SHA(MBA,NLMAX,NN,AINV,B,PT,AA,PHI,I,J,K)

      30  CALL STIFFNESS_T1_SHA(NLMAX,4*NLMAX,WORK,NN,ND,NN2,ND2,PHI,1/6D0)
      
      !! VELOCITY AT INTEGRATION POINTS
      DO I2=1,NN
        I=ND(I2)
        UINT(INTI)=UINT(INTI)+PHI(I2)*UX(I,2)
        VINT(INTI)=VINT(INTI)+PHI(I2)*UY(I,2)
        WINT(INTI)=WINT(INTI)+PHI(I2)*UZ(I,2)
      ENDDO

    ENDDO
    
    !! LHS -P TERM
    CALL WEIGHTF2_SHA(LNODE,NODN,NLMAX,KW,R,R0,CC,&
    NODEID,NWALLID,COORX,COORY,COORZ,INOD,&
    XQ,YQ,ZQ,ILINK,NN,ND,W,2,&
    I,I2,KW2,RIAV,DR,DR2,WWI)

    IF (NN.LE.0) THEN
      !WRITE(8,*)'WARNING: NO NODE NEAR THE POINT'
      !WRITE(8,*)'SHAPE FUNCTION ASSIGNED 1'
      NN=1
      ND(0)=1
      W(1)=1.0D0
      ND(1)=INOD
      PHI(1)=1.0D0
      GOTO 31
    ENDIF    

    IF(NN.LE.3)THEN
      CALL SHEPARDSF_SHA(PHI,NN,W,NLMAX,I,WWI)      
      GOTO 31
    ENDIF

    CALL SHAPPARA_R_SHA(LNODE,MBA,NLMAX,A,B,NN,ND,W,&
      COORX,COORY,COORZ,I,NI,J,K,PB2,PP2,WWI)

    CALL BASEFUN_SHA(MBA,PT,XQ,YQ,ZQ)

    IF(MBA.EQ.4)THEN
      CALL FINDINV4X4(A,AINV,WWI)
      IF(ABS(WWI).LT.1E-15)THEN
        PRINT*,"     [ERR] SINGULAR MATRIX A, ADET ",WWI
        PRINT*,"     [---] LOC ",XQ,YQ,ZQ
        CALL SHEPARDSF_SHA(PHI,NN,W(1:NN),NN,I,WWI)
        GOTO 31
      ENDIF
    ELSE
      PRINT*," [ERR] FINDINV NOT CODED FOR MBA =",MBA
      STOP
    ENDIF

    CALL SHAPEFUN_PHI_SHA(MBA,NLMAX,NN,AINV,B,PT,AA,PHI,I,J,K)
    31  CALL STIFFNESS_T1_SHA(NLMAX,4*NLMAX,WORK,NN,ND,NN2,ND2,PHI,-1D0)

    K=0
    DO I2=1,ILINK(0)
      I=ILINK(I2)
      CALL SEARCH(I,J,ND2(1:NN2),NN2)
      IF((NODEID(I).LE.10).AND.(NWALLID(I,2).NE.-10).AND.(J.NE.0))THEN

        K=K+1
        LINKTAB((INOD-1)*IVV(0)+K)=I
        SKK((INOD-1)*IVV(0)+K)=WORK(J)
        WORK(J)=0D0
      ENDIF
    ENDDO

    IF(K+1.GE.IVV(0))THEN
      PRINT*," [ERR] ERROR IN STORAGE, INCREASE IVV(0)"
      STOP
    ENDIF
    IF (K.GT.NLMAX)THEN
      PRINT*," [ERR] ERROR IN STORAGE, INCREASE NLMAXN"
      STOP
    ENDIF

    IVV(INOD)=K+1
    CALL SEARCH(INOD,J,ND2(1:NN2),NN2)
    IF(J.NE.0)THEN
      LINKTAB((INOD-1)*IVV(0)+K+1)=INOD
      SKK((INOD-1)*IVV(0)+K+1)=WORK(J)
      WORK(J)=0D0
    ENDIF

    !! RHS
    TMPR=R0I*PI/3D0*(UINT(1)+VINT(2)-UINT(3)-VINT(4)+WINT(5)-WINT(6))
    FB(INOD)=-ROUI*TMPR/(4D0*PI*DT)

    !NNN(INOD)=NN
    !NDD(1:NN2,INOD)=ND2(1:NN2)
    !WORKK(1:NN,INOD)=WORK(1:NN)
    DEALLOCATE(ILINK)
  100 ENDIF
  END SUBROUTINE FILL_MAT_KER
END MODULE FILL_MAT

!!------------------------ FILL_MATRIX_SHA ------------------------!!
SUBROUTINE FILL_MATRIX_SHA(NTHR,LNODE,NODN,NODEID,NWALLID,&
  COORX,COORY,COORZ,NLMAX,MBA,KW,R1,DDR,DT,FB)
  USE MLPGKINE
USE MLPGSTORAGE
USE NEIGHNODES
USE INTERPNEW
USE CUDAFOR
USE FILL_MAT
IMPLICIT NONE
  
  INTEGER(KIND=4)::OMP_GET_THREAD_NUM,THID
  INTEGER(KIND=4),INTENT(IN)::KW,LNODE,NODN,NTHR
  INTEGER(KIND=4),MANAGED,INTENT(IN)::NODEID(-2:NODN)
  INTEGER(KIND=4),MANAGED,INTENT(IN)::NWALLID(LNODE,4)
  INTEGER(KIND=4),INTENT(IN)::NLMAX,MBA
  REAL(KIND=8),MANAGED,INTENT(IN)::COORX(LNODE),COORY(LNODE),COORZ(LNODE)
  REAL(KIND=8),MANAGED,INTENT(IN)::DDR(NODN)
  REAL(KIND=8),INTENT(IN)::R1,DT
  REAL(KIND=8),MANAGED,INTENT(INOUT)::FB(LNODE)

  INTEGER(KIND=4)::I,J,INOD

  !ALLOCATE(NNN(NODEID(-2)),NDD(NLMAX,NODEID(-2)),WORKK(4*NLMAX,NODEID(-2)))
  !NNN=0
  !NDD=0
  !WORKK=0D0
  CALL FILL_MAT_KER<<<CEILING(REAL(NODEID(-2))/16),16>>>(LNODE,NODN,NODEID,NWALLID,COORX,COORY,COORZ,NLMAX,MBA,KW,R1,DDR,DT,FB)
  I=cudaDeviceSynchronize()

  !DO INOD=1,NODEID(-2)

    !IF(NWALLID(INOD,3).EQ.9)CYCLE
    !IF((NODEID(INOD).NE.0).OR.(NWALLID(INOD,1).EQ.4).OR.(NWALLID(INOD,2).EQ.-10))CYCLE

    !J=NNN(INOD)
    !WRITE(9,"(300I7)"),LINKTAB((INOD-1)*IVV(0)+1:(INOD-1)*IVV(0)+IVV(INOD))
  !ENDDO
END SUBROUTINE FILL_MATRIX_SHA
!!---------------------- END FILL_MATRIX_SHA ----------------------!!

!!--------------------------- GHOSTPART ---------------------------!!
SUBROUTINE GHOSTPART(LNODE,NODN,NODEID,NWALLID,&
   COORX,COORY,COORZ,NLMAX,MBA,KW,R1,DDR,P,MIRRNP,MIRRXY)
USE NEIGHNODES
USE MLPGKINE
IMPLICIT NONE
   
   INTEGER(KIND=4),INTENT(IN)::KW,LNODE,NODN,NODEID(-7:NODN),MIRRNP
   INTEGER(KIND=4),INTENT(IN)::NLMAX,MBA
   INTEGER(KIND=4),INTENT(INOUT)::NWALLID(LNODE,4)
   REAL(KIND=8),INTENT(IN)::COORX(LNODE),COORY(LNODE),COORZ(LNODE)
   REAL(KIND=8),INTENT(IN)::R1,DDR(NODN),MIRRXY(MIRRNP,3)
   REAL(KIND=8),INTENT(INOUT)::P(LNODE)

   INTEGER(KIND=4)::INOD,ND(0:NLMAX),NN,IDWEI,KW2
   INTEGER(KIND=4)::I,J,K,I2,NI,IGH,IGH2
   REAL(KIND=8)::PHI(NLMAX),W(NLMAX),B(MBA,NLMAX)
   REAL(KIND=8)::A(MBA,MBA),AINV(MBA,MBA),PT(MBA)
   REAL(KIND=8)::PB2(MBA),PP2(MBA,MBA)
   REAL(KIND=8)::XQ,YQ,ZQ,AA(MBA,NLMAX),PINT
   REAL(KIND=8)::RIAV,DR,DR2,CCIAV,RCI,ETMP,DEW,WWI
   TYPE(MLPGCONN)::ILINK
 
   WRITE(8,'(" [MSG] ENTERING GHOSTPART")')
 
   IDWEI=2 !! BIQUADRATIC WEIGHT FUNCTION
   IGH=0

END SUBROUTINE GHOSTPART
!!------------------------- END GHOSTPART -------------------------!!
