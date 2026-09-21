!./\\\\\\\\\\\...../\\\......./\\\..../\\\\\\\\\..../\\\\\\\\\\\\\.
!.\/\\\///////\\\..\/\\\......\/\\\../\\\///////\\\.\//////\\\////..
!..\/\\\.....\//\\\.\/\\\......\/\\\.\//\\\....\///.......\/\\\......
!...\/\\\......\/\\\.\/\\\......\/\\\..\////\\.............\/\\\......
!....\/\\\......\/\\\.\/\\\......\/\\\.....\///\\...........\/\\\......
!.....\/\\\......\/\\\.\/\\\......\/\\\.......\///\\\........\/\\\......
!......\/\\\....../\\\..\//\\\...../\\\../\\\....\//\\\.......\/\\\......
!.......\/\\\\\\\\\\\/....\///\\\\\\\\/..\///\\\\\\\\\/........\/\\\......
!........\///////////........\////////......\/////////..........\///.......
!!=========================================================================
!!
!! Copyright (C) 2018-2023 Politecnico di Milano,
!!                           with support from A^3 from Airbus
!!                    and  Davide   Montagnani,
!!                         Matteo   Tugnoli,
!!                         Federico Fonte
!!
!! This file is part of DUST, an aerodynamic solver for complex
!! configurations.
!!
!! Permission is hereby granted, free of charge, to any person
!! obtaining a copy of this software and associated documentation
!! files (the "Software"), to deal in the Software without
!! restriction, including without limitation the rights to use,
!! copy, modify, merge, publish, distribute, sublicense, and/or sell
!! copies of the Software, and to permit persons to whom the
!! Software is furnished to do so, subject to the following
!! conditions:
!!
!! The above copyright notice and this permission notice shall be
!! included in all copies or substantial portions of the Software.
!!
!! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
!! EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
!! OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
!! NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
!! HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
!! WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
!! FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
!! OTHER DEALINGS IN THE SOFTWARE.
!!
!! Author:
!!          Georgios Loukas
!!
!!=========================================================================

!> Module to treat a "sea" free surface.
!!
!! A sea is a flat doublet (surface panel) mesh lying at z = 0. Its points are
!! relaxed by the local induced velocity (like the wake), with a linear spring
!! that pulls them back to their undisturbed position. Only the vertical
!! coordinate is relaxed.
module mod_sea

  use mod_param, only: &
    wp, pi

  use mod_sim_param, only: &
    sim_param

  use mod_geometry, only: &
    t_geo, t_geo_component, calc_geo_vel

  use mod_aeroel, only: &
    t_pot_elem_p

  use mod_wake, only: &
    t_wake

  use mod_wind, only: &
    variable_wind

  implicit none

  public :: initialize_sea, update_sea, destroy_sea

  private

contains

!----------------------------------------------------------------------

!> Store the undisturbed height of every sea point (its initial z coordinate)
  subroutine initialize_sea(geo)
    type(t_geo), intent(inout) :: geo

    integer :: ic, np

    do ic = 1, size(geo%components)
      associate(comp => geo%components(ic))
        if (comp%is_sea) then
          np = size(comp%i_points)
          allocate(comp%sea_z0(np))
          comp%sea_z0 = geo%points(3, comp%i_points)
        end if
      end associate
    end do

  end subroutine initialize_sea

!----------------------------------------------------------------------

!> Compute the velocity induced by the aerodynamic elements and the wake.
!! The sea components themselves are excluded from the sum: their doublets
!! enforce the (zero normal velocity) ground condition, so including them would
!! cancel the very velocity that is used to relax the free surface. In this way
!! the sea is deformed by the "free field" signature of the other bodies.
  subroutine compute_vel_from_all_sea(geo, elems, wake, pos, vel)
    type(t_geo),         intent(in) :: geo
    type(t_pot_elem_p),  intent(in) :: elems(:)
    type(t_wake),        intent(in) :: wake
    real(wp),            intent(in) :: pos(3)
    real(wp),            intent(out):: vel(3)

    integer  :: ie, ic
    real(wp) :: v(3)
    logical  :: skip

    vel = 0.0_wp

    do ie = 1, size(elems)
      ic   = elems(ie)%p%comp_id
      skip = .false.
      if ( ic .ge. 1 .and. ic .le. size(geo%components) ) &
        skip = geo%components(ic)%is_sea
      if ( skip ) cycle

      call elems(ie)%p%compute_vel(pos, v)
      vel = vel + v/(4.0_wp*pi)
    end do

    do ie = 1, size(wake%pan_p)
      call wake%pan_p(ie)%p%compute_vel(pos, v)
      vel = vel + v/(4.0_wp*pi)
    end do

    do ie = 1, size(wake%rin_p)
      call wake%rin_p(ie)%p%compute_vel(pos, v)
      vel = vel + v/(4.0_wp*pi)
    end do

    do ie = 1, size(wake%end_vorts)
      call wake%end_vorts(ie)%compute_vel(pos, v)
      vel = vel + v/(4.0_wp*pi)
    end do

    do ie = 1, size(wake%part_p)
      call wake%part_p(ie)%p%compute_vel(pos, v)
      vel = vel + v/(4.0_wp*pi)
    end do

  end subroutine compute_vel_from_all_sea

!----------------------------------------------------------------------

!> Relax the sea points by the local vertical velocity, with a linear spring
!! restoring them to their undisturbed height:
!!
!!   z_new = z_old + ( w - k*(z_old - z0) ) * dt
!!
!! where w is the vertical component of the induced + freestream velocity and
!! k = sim_param%sea_relax. The x and y coordinates are left unchanged.
  subroutine update_sea(geo, elems, wake)
    type(t_geo),         intent(inout) :: geo
    type(t_pot_elem_p),  intent(in)    :: elems(:)
    type(t_wake),        intent(in)    :: wake

    integer  :: ic, ie, ip, ipg
    real(wp) :: pos(3), vel(3), wind(3), w, z, z0, dz
    real(wp) :: dt, k

    dt = sim_param%dt
    k  = sim_param%sea_relax

    do ic = 1, size(geo%components)
      associate(comp => geo%components(ic))

        if (.not. comp%is_sea) cycle

        !> Save the old normal before moving (for dn_dt)
        do ie = 1, size(comp%el)
          comp%el(ie)%nor_old = comp%el(ie)%nor
        end do

        !> Relax every point
        do ip = 1, size(comp%i_points)
          ipg = comp%i_points(ip)
          pos = geo%points(:, ipg)

          call compute_vel_from_all_sea(geo, elems, wake, pos, vel)
          wind = variable_wind(pos, sim_param%time)
          w  = vel(3) + wind(3)
          z  = pos(3)
          z0 = comp%sea_z0(ip)

          dz = (w - k*(z - z0)) * dt

          geo%points(3, ipg) = z + dz
        end do

        !> Update the geometrical data of the sea panels
        do ie = 1, size(comp%el)
          call comp%el(ie)%calc_geo_data(geo%points(:, comp%el(ie)%i_ver))
          call calc_geo_vel(comp%el(ie), geo%refs(comp%ref_id)%G_g, &
            geo%refs(comp%ref_id)%f_g)
          comp%el(ie)%dn_dt = (comp%el(ie)%nor - comp%el(ie)%nor_old)/dt
        end do

      end associate
    end do

  end subroutine update_sea

!----------------------------------------------------------------------

!> Deallocate the sea-specific storage
  subroutine destroy_sea(geo)
    type(t_geo), intent(inout) :: geo

    integer :: ic

    do ic = 1, size(geo%components)
      if (allocated(geo%components(ic)%sea_z0)) deallocate(geo%components(ic)%sea_z0)
    end do

  end subroutine destroy_sea

!----------------------------------------------------------------------

end module mod_sea
