!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Copyright 2010.  Los Alamos National Security, LLC. This material was    !
! produced under U.S. Government contract DE-AC52-06NA25396 for Los Alamos !
! National Laboratory (LANL), which is operated by Los Alamos National     !
! Security, LLC for the U.S. Department of Energy. The U.S. Government has !
! rights to use, reproduce, and distribute this software.  NEITHER THE     !
! GOVERNMENT NOR LOS ALAMOS NATIONAL SECURITY, LLC MAKES ANY WARRANTY,     !
! EXPRESS OR IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS         !
! SOFTWARE.  If software is modified to produce derivative works, such     !
! modified software should be clearly marked, so as not to confuse it      !
! with the version available from LANL.                                    !
!                                                                          !
! Additionally, this program is free software; you can redistribute it     !
! and/or modify it under the terms of the GNU General Public License as    !
! published by the Free Software Foundation; version 2.0 of the License.   !
! Accordingly, this program is distributed in the hope that it will be     !
! useful, but WITHOUT ANY WARRANTY; without even the implied warranty of   !
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General !
! Public License for more details.                                         !
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

!!>
!! Returns the center of mass
!!
subroutine getCenterOfMass( centerOfMass )
  USE CONSTANTS_MOD
  USE SETUPARRAY
  USE MDARRAY

  implicit none

  real(8) :: centerOfMass(3)
  
  centerOfMass(1) = sum(MASS(ELEMPOINTER(:))*CR(1,:))
  centerOfMass(2) = sum(MASS(ELEMPOINTER(:))*CR(2,:))
  centerOfMass(3) = sum(MASS(ELEMPOINTER(:))*CR(3,:))
  centerOfMass = centerOfMass / sum(MASS(ELEMPOINTER(:)))
  
  centerOfMass = centerOfMass*1.88972612456506_8 ! angs to a.u.
  
end subroutine getCenterOfMass

!!>
!! Gets the inertia tensor and its eigen vectors and eigen values
!!
subroutine getInertiaTensor( inertiaTensor )
  USE CONSTANTS_MOD
  USE SETUPARRAY
  USE MDARRAY

  implicit none
  
  real(8) :: inertiaTensor(3,3)
  
  real(8) :: eValsInertiaTensor(3)
  real(8) :: eVecsInertiaTensor(3,3)
  
  integer :: i, j, atom1, atom2
  real(8), allocatable :: geometryInCM(:,:)
  real(8) :: centerOfMass(3)
  real(8) :: massi
  
  integer :: ssign
  
  real(8), allocatable :: workSpace(:)
  integer :: ssize, info
  
  ALLOCATE( geometryInCM(3,NATS) )
  
  call getCenterOfMass( centerOfMass )
  
  do i=1,NATS
    geometryInCM(:,i) = CR(:,i)*1.88972612456506_8 - centerOfMass(:)   ! angs to a.u.
  end do
  
  inertiaTensor = 0.0_8
  do i=1,NATS
    massi = real(MASS(ELEMPOINTER(i)),8)!*1822.88853_8 ! amu to a.u.
    inertiaTensor(1,1) = inertiaTensor(1,1) + massi * ( geometryInCM(2,i)**2 + geometryInCM(3,i)**2)
    inertiaTensor(1,2) = inertiaTensor(1,2) - massi * ( geometryInCM(1,i) * geometryInCM(2,i) )
    inertiaTensor(1,3) = inertiaTensor(1,3) - massi * ( geometryInCM(1,i) * geometryInCM(3,i) )
    inertiaTensor(2,2) = inertiaTensor(2,2) + massi * ( geometryInCM(1,i)**2 + geometryInCM(3,i)**2)
    inertiaTensor(2,3) = inertiaTensor(2,3) - massi * ( geometryInCM(2,i) * geometryInCM(3,i) )
    inertiaTensor(3,3) = inertiaTensor(3,3) + massi * ( geometryInCM(1,i)**2 + geometryInCM(2,i)**2)
  end do
  
  inertiaTensor(2,1) =inertiaTensor(1,2)
  inertiaTensor(3,1) =inertiaTensor(1,3)
  inertiaTensor(3,2) =inertiaTensor(2,3)
  
  eVecsInertiaTensor = inertiaTensor
  allocate( workSpace( 3*3*3-1 ) )
  
  ! Compute the eigen values and eigen vectors using the upper elements of the symmetric matrix
  call dsyev( 'V', 'L', 3, eVecsInertiaTensor, 3, eValsInertiaTensor, workSpace, 3*3*3-1, info )
  
  if( info /= 0 ) then
    write(*,*) "### ERROR ### Diagonalizing the inertia tensor"
    stop
  end if
  
  deallocate( workSpace )
  
  !! Checks the determinant's sign
  ssign = eVecsInertiaTensor(1,1)*( &
          eVecsInertiaTensor(2,2)*eVecsInertiaTensor(3,3) &
          -eVecsInertiaTensor(3,2)*eVecsInertiaTensor(2,3)) &
          -eVecsInertiaTensor(1,2)*( &
          eVecsInertiaTensor(2,1)*eVecsInertiaTensor(3,3) &
          -eVecsInertiaTensor(3,1)*eVecsInertiaTensor(2,3)) &
          +eVecsInertiaTensor(1,3)*( &
          eVecsInertiaTensor(2,1)*eVecsInertiaTensor(3,2) &
          -eVecsInertiaTensor(3,1)*eVecsInertiaTensor(2,2))
  
  !! Presers the handedness of the inertia tensor
  if ( ssign < 0.0 ) then
    eVecsInertiaTensor(1,2) = -eVecsInertiaTensor(1,2)
    eVecsInertiaTensor(2,2) = -eVecsInertiaTensor(2,2)
    eVecsInertiaTensor(3,2) = -eVecsInertiaTensor(3,2)
  endif
  
  !! Verifies if the inertia tensor is correct
  if ( 	abs( eVecsInertiaTensor(1,1) ) < 1d-10 .and. &
        abs( eVecsInertiaTensor(2,2) ) < 1d-10 .and. &
        abs( eVecsInertiaTensor(3,3) ) < 1d-10 ) then
    write(*,*) "### ERROR ### Invalid inertia tensor."
    stop
  end if
  
  write(*,"(A,3F20.5)") "Inertia moments: ", eValsInertiaTensor
  stop
  write(*,*) ""
  write(*,*) "Inertia tensor: "
  do i=1,3
    write(*,"(3F15.2)") inertiaTensor(:,i)
  end do
  write(*,*) ""
  
  inertiaTensor = eVecsInertiaTensor !<<< @todo OJO esto no es verdad
  
  write(*,*) ""
  write(*,*) "Centered geometry:"
  do atom1=1,NATS
    write(*,"(3F8.2)") geometryInCM(:,atom1)
  end do
  write(*,*) ""
  
  write(*,*) ""
  write(*,*) "Original geometry:"
  do atom1=1,NATS
    write(*,"(F8.2,4X,3F8.2)") MASS(ELEMPOINTER(atom1)), CR(:,atom1)
  end do
  write(*,*) ""
  
  deallocate( geometryInCM )

end subroutine getInertiaTensor

!> 
!! @brief Proyecta un numero dado de elementos sobre el resto de los elementos del espacio vectorial 
!!		y ortogonaliza el espacio resultante mediante un proceso Gram-Schmidt
!!
!! @param this Espacio vectorial
!<
subroutine projectLastElements( vectorialSpace, output )
  implicit none
  real(8) :: vectorialSpace(:,:)
  real(8), allocatable :: output(:,:)
  
  integer :: i
  integer :: last
  real(8) :: squareNorm
  real(8) :: projectionOverOrthogonalizedBasis
  
  last = size(vectorialSpace,dim=2)
  allocate( output( size(vectorialSpace,dim=1), last ) )
  output = vectorialSpace
  
  !!***********************************************************************************
  !! Realiza de ortogonalizacion sobre los last-1 vectores, previamente ortogonalizados.
  !!
  do i=1,last-1
  squareNorm = dot_product( output(:,i), output(:,i) )	
  
  projectionOverOrthogonalizedBasis=dot_product( output(:,i),vectorialSpace(:,last) )
  
  if ( squareNorm>1.0D-12 ) then
    
    output( :, last ) = output( :, last ) - projectionOverOrthogonalizedBasis/sqrt(squareNorm)*output(:,i)
  
  end if
  end do
  squareNorm = dot_product( output(:,last), output(:,last) )	
  output( :, last )=output( :, last )/sqrt(squareNorm)
  
  !!
  !!******************************************************************

end subroutine projectLastElements

!!
!! @brief Orthogonalize the components of a vectorial space
!!
subroutine orthogonalizeLinearVectorialSpace( matrix )
  implicit none
  real(8), allocatable :: matrix(:,:)
  
  interface
    subroutine projectLastElements( vectorialSpace, output )
      implicit none
      real(8) :: vectorialSpace(:,:)
      real(8), allocatable :: output(:,:)
    end subroutine projectLastElements
  end interface

  integer :: i
  integer :: last
  real(8) :: norm
  real(8), allocatable :: output(:,:)
  
  last = size(matrix,dim=2)
  norm=sqrt(dot_product(matrix(:,1),matrix(:,1)))
  
  matrix(:,1)=matrix(:,1)/norm
    
  !!
  !! Realiza de ortogonalizacion consecutiva de cada uno de los vectores
  !! presentes en la matriz
  !!
  do i=2,last
    call projectLastElements( matrix(:,1:i), output )
    matrix(:,1:i) = output
    if( allocated(output) ) deallocate(output)
  end do
  
  !! Reortonormaliza para asegurar la ortonormalizacion
  do i=2,last
    call projectLastElements( matrix(:,1:i), output )
    matrix(:,1:i) = output
    if( allocated(output) ) deallocate(output)
  end do
  
end subroutine orthogonalizeLinearVectorialSpace

!>
!! @brief  Intercambia dos bloques de columnas especificados por los rangos A y B
!!
!! @warning Coloca el bloque de columnas especificado al inicio de la matriz 
!!		el resto de columnas al final de la misma
!! @warning Actualmente no se soportan rangos intermedios, solamente rangos contains
!!			abiertos que incluyan el elemento terminal
!! @todo Dar soporte a rangos no consecutivos
!<
subroutine swapBlockOfColumns( matrix, rangeSpecification )
  implicit none
  real(8), allocatable :: matrix(:,:)
  integer, intent(in) :: rangeSpecification(2)

  real(8), allocatable :: auxMatrix(:,:)

  allocate( auxMatrix(size(matrix,dim=1), size(matrix,dim=2) ) )
  auxMatrix = matrix

  matrix(:, 1: rangeSpecification(2)-rangeSpecification(1)+1) = auxMatrix(:, rangeSpecification(1):rangeSpecification(2) )
  matrix(:, rangeSpecification(2)-rangeSpecification(1)+2:size(matrix,dim=2) ) = auxMatrix(:,1:rangeSpecification(1)-1)

  deallocate(auxMatrix)
end subroutine swapBlockOfColumns


!>
!! Returns the projector of constants of force to make infinitesimal
!! translations and rotations.
!!
subroutine getForceConstantsProjector( projector, nVib, nRotAndTrans )
  USE CONSTANTS_MOD
  USE SETUPARRAY
  USE MDARRAY

  implicit none
  real(8), allocatable :: projector(:,:)
  integer :: nVib
  integer :: nRotAndTrans

  interface
    subroutine orthogonalizeLinearVectorialSpace( matrix )
      implicit none
      real(8), allocatable :: matrix(:,:)
    end subroutine orthogonalizeLinearVectorialSpace
    
    subroutine swapBlockOfColumns( matrix, rangeSpecification )
      implicit none
      real(8), allocatable :: matrix(:,:)
      integer, intent(in) :: rangeSpecification(2)
    end subroutine swapBlockOfColumns
  end interface
  
  integer :: i
  integer :: j
  integer :: index_x
  integer :: index_y
  integer :: index_z
  integer :: aux
  logical :: isNull
  real(8) :: sqrtMass
  real(8) :: coordinatesProyected(3)
  real(8) :: geometryInCM(3)
  real(8) :: centerOfMass(3)
  real(8) :: squareNorm
!   type(LinearVectorialSpace) :: spaceOfForceConstants
  real(8) :: inertiaTensor(3,3)

  allocate( projector(3*NATS,3*NATS) )
  
  call getCenterOfMass( centerOfMass )
  call getInertiaTensor( inertiaTensor )

  do i=1,NATS

    index_x = 3*i - 2
    index_y = 3*i - 1
    index_z = 3*i

    sqrtMass = sqrt( MASS(ELEMPOINTER(i))*1822.88853_8 ) ! amu to a.u.
    geometryInCM = CR(:,i)*1.88972612456506_8-centerOfMass(:)  ! angs to a.u.

    !!
    !! Projects the cartesian coordinates on the inertia tensor
    !!
    coordinatesProyected(1)=dot_product( geometryInCM, inertiaTensor(1,:) )
    coordinatesProyected(2)=dot_product( geometryInCM, inertiaTensor(2,:) )
    coordinatesProyected(3)=dot_product( geometryInCM, inertiaTensor(3,:) )
    
    projector(index_x,1) = sqrtMass
    projector(index_y,2) = sqrtMass
    projector(index_z,3) = sqrtMass

    projector(index_x,4) = 	(coordinatesProyected(2)*inertiaTensor(1,3) &
                - coordinatesProyected(3)*inertiaTensor(1,2) )/sqrtMass
    projector(index_y,4) = 	(coordinatesProyected(2)*inertiaTensor(2,3) &
                - coordinatesProyected(3)*inertiaTensor(2,2) )/sqrtMass
    projector(index_z,4) = 	(coordinatesProyected(2)*inertiaTensor(3,3) &
                - coordinatesProyected(3)*inertiaTensor(3,2) )/sqrtMass

    projector(index_x,5) = 	(coordinatesProyected(3)*inertiaTensor(1,1) &
                - coordinatesProyected(1)*inertiaTensor(1,3) )/sqrtMass
    projector(index_y,5) = 	(coordinatesProyected(3)*inertiaTensor(2,1) &
                - coordinatesProyected(1)*inertiaTensor(2,3) )/sqrtMass
    projector(index_z,5) = 	(coordinatesProyected(3)*inertiaTensor(3,1) &
                - coordinatesProyected(1)*inertiaTensor(3,3) )/sqrtMass

    projector(index_x,6) =	(coordinatesProyected(1)*inertiaTensor(1,2) &
                - coordinatesProyected(2)*inertiaTensor(1,1) )/sqrtMass
    projector(index_y,6) = 	(coordinatesProyected(1)*inertiaTensor(2,2) &
                - coordinatesProyected(2)*inertiaTensor(2,1) )/sqrtMass
    projector(index_z,6) =	(coordinatesProyected(1)*inertiaTensor(3,2) &
                - coordinatesProyected(2)*inertiaTensor(3,1) )/sqrtMass
  end do

  !! Verfies if the six vectors are actually rotational
  !! and translational normal modes
  nRotAndTrans = 0
  isNull=.false.
  aux = 0

  do i=1,6

    squareNorm = dot_product( projector(:,i),projector(:,i) )
    write(*,*) i, squareNorm

    if ( squareNorm > 1.0D-6 ) then

      projector(:,i) = projector(:,i) / sqrt( squareNorm )
      nRotAndTrans = nRotAndTrans + 1
      
      if ( isNull ) then
        projector(:,i-aux) = projector(:,i)
        projector(:,i) = 0.0_8
      end if
    else
      
      isNull = .true.
      aux = aux+1

    end if

  end do
  
  !!
  !!***********************************************************************
  nVib = 3*NATS - nRotAndTrans
  !!Adiciona una serie de vectores asociados a vibraciones con el fin
  !! de completar la matriz de transformacion
  j=1
  do i=nRotAndTrans+1,3*NATS
    projector(j,i)=1.0_8
    j=j+1
  end do
  
  write(*,*) ""
  write(*,*) "Initial projector: "
  do i=1,size(projector,dim=2)
    write(*,"(6F8.2)") projector(i,:)
  end do
  write(*,*) ""

  !! Construye un espacio vectorial lineal con los vectores previemente generados
  !!**********
  !! 	Proyecta los vectores asociados a grados de libertad vibracionales sobre los 
  !! 	asociados a grados de libertad rotacionales y traslacionales. - Los primeros 
  !!	N vectores (nRotAndTrans ),  se asocian a los grados 
  !!	de libertad rotacionales y translacionales el resto se asocian a los grados de libertad
  !!	vibracionales -
  !!**
  call orthogonalizeLinearVectorialSpace( projector )
  
  write(*,*) ""
  write(*,*) "Orthogonalized projector: "
  do i=1,size(projector,dim=2)
    write(*,"(6F8.2)") projector(i,:)
  end do
  write(*,*) ""

  !!
  !! Reordena el proyector colocando los vectores asociados al vibraciones al principio y los
  !! asociados a rotaciones y traslaciones al final
  !!
  call swapBlockOfColumns( projector, [nRotAndTrans+1, 3*NATS] )
  
  write(*,*) ""
  write(*,*) "Orthogonalized & sorted projector: "
  do i=1,size(projector,dim=2)
    write(*,"(6F8.2)") projector(i,:)
  end do
  write(*,*) ""
  write(*,*) "nRotAndTrans = ", nRotAndTrans
  write(*,*) "nVib = ", nVib
  write(*,*) ""

end subroutine getForceConstantsProjector

!>
!!  @brief Calculates the core of the transformation matrix to remove the external
!!         degrees of freedom from the gradient and the hessian
!<
subroutine getTransformationMatrix( output )
  USE CONSTANTS_MOD
  USE SETUPARRAY
  USE MYPRECISION
  USE MDARRAY

  implicit none
  
  interface
    subroutine getForceConstantsProjector( projector, nVib, nRotAndTrans )
      implicit none
      real(8), allocatable :: projector(:,:)
      integer :: nVib, nRotAndTrans
    end subroutine getForceConstantsProjector
  end interface 
  
  real(8), allocatable :: output(:,:)
  real(8), allocatable :: forceConstansProjector(:,:)
  integer :: nVib, nRotAndTrans
  
  allocate( output(NATS*3,NATS*3) )
  output = 0.0_8
  call getForceConstantsProjector( forceConstansProjector, nVib, nRotAndTrans )

  output = -1.0_8 * matmul( forceConstansProjector(:,1:nVib+1), &
            transpose(forceConstansProjector(:,1:nVib+1) ) )

end subroutine getTransformationMatrix


!!>
!! Calculates the IR spectrum
!!
SUBROUTINE GETIR

  USE CONSTANTS_MOD
  USE SETUPARRAY
  USE MYPRECISION
  USE MDARRAY

  implicit none
  
  interface
    subroutine getTransformationMatrix( output )
      implicit none
      real(8), allocatable :: output(:,:)
    end subroutine getTransformationMatrix
  end interface 
  
  integer :: i, j, p1, p2, atom1, atom2
  real(8) :: m1, m2
  REAL(8) :: d2Vdp1dp2, HB
  real(8), allocatable :: geom0(:,:)
  
  real(8) :: inertiaTensor(3,3)
  
  real(8), allocatable :: hessian(:,:)
  real(8), allocatable :: eVecsHessian(:,:)
  real(8), allocatable :: eValsHessian(:)
  
  real(8), allocatable :: transformationMatrix(:,:)
  
  real(8), allocatable :: workSpace(:)
  integer :: ssize, info
  
  IF (EXISTERROR) RETURN
  
  call getTransformationMatrix( transformationMatrix )
  
  write(*,*) " transformationMatrix : "
  do i=1,size(transformationMatrix,dim=2)
    write(*,"(6F8.2)") transformationMatrix(i,:)
  end do
  
  do i=1,size(transformationMatrix,dim=1)
    transformationMatrix(i,i) = 1.0_8 + transformationMatrix(i,i)
  end do

  CALL GETFORCE
  
  write(*,*) " Norm. grad = ", sqrt(sum(FTOT**2))
  
  allocate( geom0(3,NATS) )
  allocate( hessian(3*NATS,3*NATS) )
  
  geom0 = CR
  
  hb = 0.001d0

  p1 = 1
  do atom1=1,NATS; do i=1,3
    m1 = MASS(ELEMPOINTER(atom1))*1822.88853_8 ! amu to a.u.
    
!     write(*,*) MASS(ELEMPOINTER(atom1)), CR(I,atom1)
    
    p2 = 1
    do atom2=1,NATS; do j=1,3
      m2 = MASS(ELEMPOINTER(atom2))*1822.88853_8 ! amu to a.u.
      
      FTOT = 0.0d0
      CR = geom0
      
      !! Second derivatives are calculated as follows
      !! a,b = atom1, atom2
      !! i,j = x, y, or z
      !!
      !! dV(ai,bj)/dai = -F(ai,bj)
      !!
      !! d2V(ai,bj)/daidbj = d( dV(ai,bj)/dai )/dbj = d( -F(ai,bj) )/dbj
      !!
      !! d2V(ai,bj)/daidbj ~ ( -F(ai,bj+hb) + F(ai,bj-hb) )/(2*hb)
      
      CR(J,atom2) = CR(J,atom2) + hb
      CALL GETFORCE
      
      d2Vdp1dp2 = -FTOT(I,atom1)
      
      CR(J,atom2) = CR(J,atom2) - 2*hb
      CALL GETFORCE
      
      d2Vdp1dp2 = ( d2Vdp1dp2 + FTOT(I,atom1) )/2.0d0/hb ! Derivative
      d2Vdp1dp2 = d2Vdp1dp2*0.0102908545816127_8  ! eV/angs^2 to a.u.
      
      d2Vdp1dp2 = d2Vdp1dp2/sqrt(m1*m2) ! Mass weighted derivative
      
      hessian( p1, p2 ) = d2Vdp1dp2
        
      p2 = p2 + 1
    end do; end do
    
    p1 = p1 + 1
  end do; end do
  
  hessian = matmul( transpose(transformationMatrix), matmul( hessian, transformationMatrix ) )
  
  CR = geom0 ! Restore original geometry
  
!   write(*,*) hessian
  allocate( eValsHessian(3*NATS) )
  allocate( eVecsHessian(3*NATS,3*NATS) )
  
  write(*,*) "Hessian:"
  do i=1,3*NATS
    do j=1,3*NATS
      write(*,"(E20.2)",advance="no") hessian(i,j)
    end do
    write(*,*) ""
  end do
  
  allocate( workSpace( 3*3*NATS-1 ) )
  eVecsHessian = hessian

  ! Compute the eigen values and eigen vectors using the upper elements of the symmetric matrix
  call dsyev( 'V', 'L', 3*NATS, eVecsHessian, 3*NATS, eValsHessian, workSpace, 3*3*NATS-1, info )
  
  deallocate( workSpace )
  
  if ( info /= 0 ) then
    write(*,*) "### ERROR ### GETIR.dsyev: matrix diagonalization failed"
    stop
  end if
  
  write(*,*) ""
  write(*,*) " Vib. Freqs (cm-1) "
  write(*,*) "-------------------"
  do i=1,3*NATS
    if( eValsHessian(i) < 0.0_8 ) then
      write(*,"(I10,F15.2)") i, -sqrt(abs(eValsHessian(i)))*219474.63068_8  ! a.u. to cm-1  
    else
      write(*,"(I10,F15.2)") i, sqrt(eValsHessian(i))*219474.63068_8  ! a.u. to cm-1  
    end if
  end do
  write(*,*) ""

!   WRITE(*,*)"==========================="
!   WRITE(*,*)"Im stoping in subroutine getir"
!   WRITE(*,*)"Grep for GETIR"
!   WRITE(*,*)"==========================="
  
  deallocate( geom0 )
  deallocate( hessian )
  deallocate( eValsHessian )
  deallocate( eVecsHessian )
  
  STOP

  RETURN

END SUBROUTINE GETIR