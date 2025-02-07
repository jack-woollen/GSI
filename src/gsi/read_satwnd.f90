subroutine read_satwnd(nread,ndata,nodata,infile,obstype,lunout,gstime,twind,sis,&
     prsl_full,nobs)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    read_satwnd                    read satellite winds  
!   prgmmr: su, xiujuan      org: np23                date: 2010-10-13
!
! abstract:  This routine reads satellite winds from satellite wind dump.  
!            it also has options to thin the data by using conventional 
!            thinning programs 
!            When running the gsi in regional mode, the code only
!            retains those observations that fall within the regional
!            domain
!            For the satellite ID type: 240: GOES short wave winds, 
!            241: India, 242:JMA Visible,243: EUMETSAT visible,244: AVHRR winds
!            245: GOES IR. 246: GOES WV cloud top, 247: GOES WV deep layer
!            250: JMA WV deep layer. 251:GOES visible, 252: JMA IR winds
!            253: EUMETSAT IR winds, 254: EUMETSAT WV deep layer winds
!            257,258,259: MODIS IR,WV cloud top, WV deep layer winds
!            260: VIIR IR winds
!            241: CIMSS enhanced AMV winds
!            respectively
!            For satellite subtype: 50-80 from EUMETSAT geostationary satellites(METEOSAT) 
!                                   100-199 from JMA geostationary satellites(MTSAT)
!                                   250-299 from NESDIS geostationary satellites(GOES)
!                                   700-799 from NASA Terra and Aqua satellites
!                                   <10, 200-223 from NOAA-15, 16, 17, 18, polar
!                                   orbit and EUMESAT MetOp satellites 
!           The quality mark:  QM, the values range from 0 to 15, 0-7 used, 8-15
!                              monitored, 0 is best, when the value greater than
!                              3, the observation error needed to be enflated. 
!           THe quality markers from producer:  qifn:  QI values without
!           forecast considered, qify: QI values with forecast considered, ee:
!           Expected error      

! program history log:
!   2010-10-13 su, x.  
!   2011-08-09 pondeca - add support for twodvar option
!   2011-08-27 todling - bypass this routine when SATWND from prepbufr are used
!   2011-10-03 su      - read AVHRR wind into system and modify satellite id range 
!                        and put subset as screen criterie since AVHRR from 
!                        different satellites
!   2011-10-24         -add reading observation error in this subroutine and stop
!                       statement if no prepbufr error table available.
!   2011-12-08 Su      -modify GOES reading program for new bufrtab.005 new format, reading        
!                       SDM quality mark 
!   2011-12-20 Su      -modify to read deep layer WV winds as monitor with qm=9,considering short 
!                       wave winds as subset 1 0f 245         
!   2012-07-18 Sienkiewicz - fix for infrad IR winds monitoring north of 20N
!   2012-10-13 Su      -modify the code to assimilate GOES hourly wind, changed the error and quality control
!   2013-01-26  parrish - change from grdcrd to grdcrd1 (to allow successful debug compile on WCOSS)
!   2013-02-13  parrish - set pflag=0 outside loopd to prevent runtime fatal error in debug mode.
!   2013-08-26 McCarty -modified to remove automatic rejection of AVHRR winds
!   2013-09-20  Su      - set satellite ID as satellite wind subtype
!   2014-07-16  Su      - read VIIRS winds 

!   2014-10-16  Su      -add optione for 4d thinning and option to keep thinned data  
!   2015-02-23  Rancic/Thomas - add thin4d to time window logical
!   2015-02-26  su      - add njqc as an option to choose new non linear qc 
!   2015-03-23  Su      -fix array size with maximum message and subset number from fixed number to
!                        dynamic allocated array 
!   2015-02-26  Genkova - read GOES-R like winds from ASCII files & apply Sharon Nebuda's changes for GOES-R
!   2015-05-12  Genkova - reading from ASCII files removed, read GOES-R from new BUFR, keep Nebuda's GOES-R related changes 
!   2015-03-14  Nebuda  - add QC for clear air WV AMV (WVCS) from GOES type 247, removed PCT1 check not applicable to 247
!   2015-10-01  guo     - consolidate use of ob location (in deg)
!   2016-03-15  Su      - modified the code so that the program won't stop when
!                         no subtype is found in non linear qc error table and b table !                         table
!   2016-05-05  pondeca - add 10-m u-wind and v-wind (uwnd10m, vwnd10m)
!   2016-12-13  Lim     - Addition of GOES SWIR, CAWV and VIS winds into HWRF
!   2017-08-22  Genkova - Testing Git / Add Goes-16 and JPSS SatID
!                       - Read WMO pre-approved new BUFR Goes-16 AMVs (Goes-R)
!   2018-06-13  Genkova - Goes-16 AMVs use ECMWF QC till new HAM late 2018
!                         and OE/2 
!   2019-9-25        Su - modified ithin value criteria to distinguash thinning
!                         or hilber curve downweighting
! 
!   2020-05-04  wu   - no rotate_wind for fv3_regional
!   2021-07-25 Genkova  - added code for Metop-B/C winds in new BUFR,NC005081  !
!   2022-01-20 Genkova  - added missing station_id for polar winds
!   2022-01-20 Genkova  - added code for Meteosat and Himawari AMVs in new BUFR
!   2022-12-10 Bi  - added code for CIMSS enhanced AMVs in new BUFR
!   
!
!   input argument list:
!     ithin    - flag to thin data
!     rmesh    - thinning mesh size (km)
!     gstime   - analysis time in minutes from reference date
!     infile   - unit from which to read BUFR data
!     lunout   - unit to which to write data for further processing
!     obstype  - observation type to process
!     twind    - input group time window (hours)
!     sis      - satellite/instrument/sensor indicator
!
!   output argument list:
!     nread    - number of satellite winds read 
!     ndata    - number of satellite winds retained for further processing
!     nodata   - number of satellite winds retained for further processing
!     nobs     - array of observations on each subdomain for each processor
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use kinds, only: r_kind,r_double,i_kind,r_single
  use gridmod, only: diagnostic_reg,regional,nlon,nlat,nsig,&
       tll2xy,txy2ll,rotate_wind_ll2xy,rotate_wind_xy2ll,&
       rlats,rlons,twodvar_regional,wrf_nmm_regional,fv3_regional
  use qcmod, only: errormod,njqc
  use convthin, only: make3grids,map3grids_m,del3grids,use_all
  use convthin_time, only: make3grids_tm,map3grids_m_tm,del3grids_tm,use_all_tm
  use constants, only: deg2rad,zero,rad2deg,one_tenth,&
        tiny_r_kind,huge_r_kind,r60inv,one_tenth,&
        one,two,three,four,five,half,quarter,r60inv,r100,r2000
  use converr,only: etabl
  use converr_uv,only: etabl_uv,isuble_uv,maxsub_uv
  use convb_uv,only: btabl_uv
  use obsmod, only: perturb_obs,perturb_fact,ran01dom,bmiss,reduce_diag
  use convinfo, only: nconvtype, &
       icuse,ictype,icsubtype,ioctype, &
       ithin_conv,rmesh_conv,pmesh_conv,pmot_conv,ptime_conv, &
       use_prepb_satwnd, ec_amv_qc

  use gsi_4dvar, only: l4dvar,l4densvar,iwinbgn,winlen,time_4dvar,thin4d
  use deter_sfc_mod, only: deter_sfc_type,deter_sfc2
  use mpimod, only: npe
  implicit none

! Declare passed variables
  character(len=*)                      ,intent(in   ) :: infile,obstype
  character(len=20)                     ,intent(in   ) :: sis
  integer(i_kind)                       ,intent(in   ) :: lunout
  integer(i_kind)                       ,intent(inout) :: nread,ndata,nodata
  integer(i_kind),dimension(npe)        ,intent(inout) :: nobs
  real(r_kind)                          ,intent(in   ) :: twind
  real(r_kind),dimension(nlat,nlon,nsig),intent(in   ) :: prsl_full

! Declare local parameters

  real(r_kind),parameter:: r1_2= 1.2_r_kind
  real(r_kind),parameter:: r3_33= 3.33_r_kind
  real(r_kind),parameter:: r6= 6.0_r_kind
  real(r_kind),parameter:: r50= 50.0_r_kind
  real(r_kind),parameter:: r80= 80.0_r_kind
  real(r_kind),parameter:: r90= 90.0_r_kind
  real(r_kind),parameter:: r105= 105.0_r_kind
  real(r_kind),parameter:: r110= 110.0_r_kind
  real(r_kind),parameter:: r125=125.0_r_kind
  real(r_kind),parameter:: r200=200.0_r_kind
  real(r_kind),parameter:: r250=250.0_r_kind
  real(r_kind),parameter:: r360 = 360.0_r_kind
  real(r_kind),parameter:: r600=600.0_r_kind
  real(r_kind),parameter:: r700=700.0_r_kind
  real(r_kind),parameter:: r850=850.0_r_kind
  real(r_kind),parameter:: r199=199.0_r_kind
  real(r_kind),parameter:: r299=299.0_r_kind
  real(r_kind),parameter:: r799=799.0_r_kind
  real(r_kind),parameter:: r1200= 1200.0_r_kind
  real(r_kind),parameter:: r10000= 10000.0_r_kind
  real(r_double),parameter:: rmiss=10d7 

! Declare local variables
  logical outside,inflate_error
  logical luse,ithinp
  logical,allocatable,dimension(:,:):: lmsg     ! set true when convinfo entry id found in a message

  character(70) obstr_v1, obstr_v2,hdrtr_v1,hdrtr_v2
  character(50) qcstr
  character(8) subset
! character(20) derdwtr,heightr
  character(8) c_prvstg,c_sprvstg
  character(8) c_station_id,stationid
  character(2) swcm(7)/'IR','VI','CT','DL','D5','D6','D7'/
  
  integer(i_kind) mxtb,nmsgmax,qcret
  integer(i_kind) ireadmg,ireadsb,iuse
  integer(i_kind) i,maxobs,idomsfc,nsattype,ncount
  integer(i_kind) nc,nx,isflg,j,nchanl
  integer(i_kind) ntb,ntmatch,ncx,ncsave,ntread
  integer(i_kind) kk,klon1,klat1,klonp1,klatp1
  integer(i_kind) nmind,lunin,idate,ilat,ilon,iret,k
  integer(i_kind) nreal,ithin,iout,ii
  integer(i_kind) itype,iosub,ixsub,isubsub,itypey,ierr,ihdr9
  integer(i_kind) isaid,ysub,sattab(100,1000,7,2)
  integer(i_kind) qm
  integer(i_kind) nlevp         ! vertical level for thinning
  integer(i_kind) pflag
  integer(i_kind) ntest,nvtest
  integer(i_kind) kl,k1,k2
  integer(i_kind) nmsg                ! message index
 
  integer(i_kind),dimension(nconvtype) :: ntxall 
  integer(i_kind),dimension(nconvtype+1) :: ntx  
  
  integer(i_kind),dimension(5):: idate5 
  integer(i_kind),allocatable,dimension(:):: nrep,istab
  integer(i_kind),allocatable,dimension(:,:):: tab
  integer(i_kind) :: icnt(1000)


  integer(i_kind) ntime,itime,istype

  real(r_kind) toff,t4dv
  real(r_kind) rmesh,ediff,tdiff
  real(r_kind) u0,v0,uob,vob,dx,dy,dx1,dy1,w00,w10,w01,w11
  real(r_kind) dlnpob,ppb,qifn,qify,ee,ree,pct1,experr_norm
  real(r_kind) woe,dlat,dlon,dlat_earth,dlon_earth
  real(r_kind) dlat_earth_deg,dlon_earth_deg
  real(r_kind) cdist,disterr,disterrmax,rlon00,rlat00
  real(r_kind) vdisterrmax,u00,v00
  real(r_kind) del,werrmin,obserr,var_jb,wjbmin,wjbmax
! real(r_kind) ppb1,ppb2,uob1,vob1
  real(r_kind) tsavg,ff10,sfcr,sstime,gstime,zz
  real(r_kind) crit1,timedif,xmesh,pmesh,ptime
  real(r_kind),dimension(nsig):: presl
  
  real(r_double) zangl 
  real(r_double),dimension(13):: hdrdat
  real(r_double),dimension(4):: obsdat
  real(r_double),dimension(2) :: hdrdat_test,hdrdat_005099
! real(r_double),dimension(3,5) :: heightdat
! real(r_double),dimension(6,4) :: derdwdat
  real(r_double),dimension(3,12) :: qcdat
  real(r_double),dimension(1,1):: r_prvstg,r_sprvstg
  real(r_kind),allocatable,dimension(:):: presl_thin
  real(r_kind),allocatable,dimension(:,:):: cdata_all

  logical,allocatable,dimension(:)::rthin,rusage
  logical save_all
 !integer(i_kind) numthin,numqc,numrem,numall
  integer(i_kind) nxdata,pmot


! GOES-16 new BUFR related variables
  real(r_double) :: rep_array
  integer(i_kind) :: irep_array
!  real(r_double),allocatable,dimension(:,:) :: amvaha  ! Alternative height assignment in AMV    
!  real(r_double),allocatable,dimension(:,:) :: amviii  ! Individual images imformation in AMV
!  real(r_double),allocatable,dimension(:,:) :: amvcld  ! AMV vectors cloud information
  real(r_double),allocatable,dimension(:,:) :: amvivr  ! Intermediate vectors retrieved in AMV
  real(r_double),dimension(2,4) :: amvqic ! AMV quality indicator confidence

  real(r_double) rstation_id

! equivalence to handle character names
  equivalence(r_prvstg(1,1),c_prvstg)
  equivalence(r_sprvstg(1,1),c_sprvstg)
  equivalence(rstation_id,c_station_id)

  data hdrtr_v1 /'SAID CLAT  CLON  YEAR MNTH DAYS HOUR MINU SWCM SAZA OGCE SCCF SWQM'/ ! OGCE replaces GCLONG, OGCE exists in old and new BUFR
  data hdrtr_v2 /'SAID CLATH CLONH YEAR MNTH DAYS HOUR MINU SWCM SAZA OGCE SCCF SWQM'/ ! OGCE replaces GCLONG, OGCE exists in old and new BUFR
                                                                     ! SWQM doesn't exist in the new BUFR, so qm is initialized to '2' manually

  data obstr_v1 /'HAMD PRLC WDIR WSPD'/ 
  data obstr_v2 /'EHAM PRLC WDIR WSPD'/ 
! data heightr/'MDPT '/ 
! data derdwtr/'TWIND'/
  data qcstr /' OGCE GNAP PCCF'/

  data ithin / -9 /
  data lunin / 11 /
  data rmesh / -99.999_r_kind /

!**************************************************************************

! Return when SATWND are coming from prepbufr file
  if(use_prepb_satwnd) return

  call sattabin(sattab)

! read observation error table

  disterrmax=zero
  vdisterrmax=zero
  wjbmin=zero
  wjbmax=5.0_r_kind
  pflag=0
  var_jb=zero
  icnt=0

! allocate(etabl(302,33,6)) ! add 2 ObsErr profiles for GOES-R IR(itype=301) and WV(itype=300) (not used yet, 2015-07-08, Genkova) 
  
! Set lower limits for observation errors
  werrmin=one
  nsattype=0
  nreal=26
  if(perturb_obs ) nreal=nreal+2
  ntread=1
  ntmatch=0
  ntx(ntread)=0
  ntxall=0
  do nc=1,nconvtype
     if((trim(ioctype(nc)) == 'uv' .or. trim(ioctype(nc)) == 'wspd10m' .or. trim(ioctype(nc)) == 'uwnd10m' .or. &
        trim(ioctype(nc)) == 'vwnd10m') .and. ictype(nc) >=240 .and. ictype(nc) <=265) then
        ntmatch=ntmatch+1
        ntxall(ntmatch)=nc
        ithin=ithin_conv(nc)
        if(ithin > 0 .and. ithin <5)then
           ntread=ntread+1
           ntx(ntread)=nc
        end if
     end if
  end do

  if(ntmatch == 0)then
     write(6,*) ' READ_SATWND: no matching obstype found in obsinfo ',obstype
     return
  end if
      
!!  go through the satedump to find out how many subset to process

!! get message and subset counts

  call getcount_bufr(infile,nmsgmax,mxtb)

  allocate(lmsg(nmsgmax,ntread),istab(nmsgmax),tab(mxtb,3),nrep(nmsgmax))
 
  lmsg = .false.
  maxobs=0
  tab=0
  istab=0
  nmsg=0
  nrep=0
  ntb =0
  open(lunin,file=trim(infile),form='unformatted')
  call openbf(lunin,'IN',lunin)
  call datelen(10)
  
  msg_report: do while (ireadmg(lunin,subset,idate) == 0)
     
!    Time offset
     if(nmsg == 0) call time_4dvar(idate,toff)
     nmsg=nmsg+1
     if (nmsg>nmsgmax) then
        write(6,*)'READ_SATWND: messages exceed maximum ',nmsgmax
        call stop2(49)
     endif

     read(subset,'(5x,i3.3)') ysub

     loop_report: do while (ireadsb(lunin) == 0)

        ntb = ntb+1
        nrep(nmsg)=nrep(nmsg)+1
        maxobs=maxobs+1
        if (ntb>mxtb) then
           write(6,*)'READ_SATWND: reports exceed maximum ',mxtb   
           call stop2(49)
        endif
            
        call ufbint(lunin,hdrdat,13,1,iret,hdrtr_v1) 
        if(hdrdat(9)>=10.d10) call ufbint(lunin,hdrdat(9),1,1,iret,'CMCM')
          ! SWQM doesn't exist for GOES-R/new BUFR/ hence hdrdat(13)=MISSING.
          ! qm=2, instead of using hdrdat(13)(2015-07-16, Genkova)

        isaid=nint(hdrdat(1))
        ihdr9=nint(hdrdat(9))
        if(ihdr9<1.or.ihdr9>7) cycle loop_report 

        itype   = sattab(ysub,isaid,ihdr9,1)
        istype  = sattab(ysub,isaid,ihdr9,2)

        if (istype == -1) cycle loop_report ! unassigned itypes
        if (itype  == -1) write(6,*) 'type mismatch', itype,istype
        if (itype  == -1) cycle loop_report ! unassigned itypes    `

        istab(nmsg) = istype 

!  Match ob to proper convinfo type
        ncsave=0
        matchloop:do ncx=1,ntmatch
           nc=ntxall(ncx)
           if (itype /= ictype(nc)) cycle matchloop
!  Find convtype which match ob type and subtype
           if(icsubtype(nc) == isaid) then
              ncsave=nc
              exit matchloop
           else
!  Find convtype which match ob type and subtype group (isubtype == ?*)
!       where ? specifies the group and icsubtype = ?0)
              ixsub=icsubtype(nc)/10
              iosub=isaid/10
              isubsub=icsubtype(nc)-ixsub*10
              if(ixsub == iosub .and. isubsub == 0) then
                 ncsave=nc
!  Find convtype which match ob type and subtype is all remaining
!       (icsubtype(nc) = 0)
              else if (ncsave == 0 .and. icsubtype(nc) == 0) then
                 ncsave=nc
              end if
           end if
        end do matchloop

!  Save information for next read
        if(ncsave /= 0) then
           nx=1
           if(ithin_conv(ncsave) > 0 .and. ithin_conv(ncsave) <5)then
              do ii=2,ntread
                 if(ntx(ii) == ncsave)nx=ii
              end do
           end if
           tab(ntb,1)=ncsave
           tab(ntb,2)=nx
           tab(ntb,3)=itype
           lmsg(nmsg,nx) = .true.
        end if
     enddo loop_report
  enddo msg_report

  nread=0
  ntest=0
  nvtest=0
  nchanl=0
  ilon=2
  ilat=3
  allocate(cdata_all(nreal,maxobs),rthin(maxobs),rusage(maxobs))
  rusage = .true.
  rthin = .false.

  loop_convinfo: do nx=1,ntread 

     ! set parameters for processing the next satwind type
     use_all = .true.
     use_all_tm = .true.
     ithin=0
!  Default for non thinned data is save all
     pmot=0

     if(nx >1) then
        nc=ntx(nx)
        ithin=ithin_conv(nc)
        pmot = pmot_conv(nc)
        if (ithin > 0 .and. ithin <5) then
           rmesh=rmesh_conv(nc)
           pmesh=pmesh_conv(nc)
           ptime=ptime_conv(nc)
           if(pmesh > zero) then
              pflag=1
              nlevp=r1200/pmesh
           else
              pflag=0
              nlevp=nsig
           endif
           xmesh=rmesh
           if( ptime >zero) then
              use_all_tm = .false.
              ntime=6.0_r_kind/ptime                   !!  6 hour winddow
              call make3grids_tm(xmesh,nlevp,ntime)
           else
              use_all = .false.
              call make3grids(xmesh,nlevp)
           endif
           if (.not.use_all .or. .not.use_all_tm) then
              allocate(presl_thin(nlevp))
              if (pflag==1) then
                 do k=1,nlevp
                    presl_thin(k)=(r1200-(k-1)*pmesh)*one_tenth
                 enddo
              endif
           endif
           write(6,'(a52,a16,I5,f10.2,2i5,f10.2,i5,i5,f10.2)') &
                   ' READ_SATWND: ictype(nc),rmesh,pflag,nlevp,pmesh,nc ', &
                   ioctype(nc),ictype(nc),rmesh,pflag,nlevp,pmesh,nc,pmot,ptime
        endif
     endif

     if(reduce_diag .and. pmot < 2)pmot=pmot+2
     save_all=.false.
     if(pmot /= 2 .and. pmot /= 0) save_all=.true.

     ! Open and read the file again for each satwnd type   
     call closbf(lunin)
     open(lunin,file=trim(infile),form='unformatted')
     call openbf(lunin,'IN',lunin)
     call datelen(10)
     ntb = 0
     nmsg = 0
     ncount=0
     loop_msg:  do while(IREADMG(lunin,subset,idate) == 0)
        nmsg = nmsg+1
        istype = istab(nmsg)
        if(.not.lmsg(nmsg,nx)) then    
           ntb=ntb+nrep(nmsg)
           cycle loop_msg ! no useable reports this mesage, skip ahead report count
        end if

        loop_readsb: do while(ireadsb(lunin) == 0)
           ntb = ntb+1
           nc = tab(ntb,1)
           if(nc <= 0 .or. tab(ntb,2) /= nx) cycle loop_readsb
           itype = tab(ntb,3)
           if(itype <= 0) cycle loop_readsb
           hdrdat=bmiss
           obsdat=bmiss
!          heightdat=bmiss
!          derdwdat=bmiss
           qcdat=bmiss
           uob=bmiss
           vob=bmiss
           ppb=bmiss
!          ppb1=bmiss
!          ppb2=bmiss
!          uob1=bmiss
!          vob1=bmiss
           ee=r110
           qifn=r110
           qify=r110

           ! test for BUFR version using lat/lon mnemonics
           call ufbint(lunin,hdrdat_test,2,1,iret, 'CLAT CLON')
           if ( hdrdat_test(1) > 100000000.0_r_kind .and. hdrdat_test(2) > 100000000.0_r_kind ) then
              call ufbint(lunin,hdrdat,13,1,iret,hdrtr_v2) 
              call ufbint(lunin,obsdat,4,1,iret,obstr_v2)
           else
              call ufbint(lunin,hdrdat,13,1,iret,hdrtr_v1) 
              call ufbint(lunin,obsdat,4,1,iret,obstr_v1)
           endif

           ! test for BUFR version using CMCM for wind computation method
           if(hdrdat(9)>=10.d10) call ufbint(lunin,hdrdat(9),1,1,iret,'CMCM')

           ! reject data with missing pressure or wind
           ppb=obsdat(2)
           if(ppb>rmiss .or.  hdrdat(3)>rmiss .or. obsdat(4)>rmiss) cycle loop_readsb
           if(ppb>r10000) ppb=ppb/r100 ! ppb<10000 may indicate data reported in daPa or hPa

           ! reject date above 125mb (or 850 for regional)
           if ((twodvar_regional .and. ppb <r850) .or. ppb < r125) cycle loop_readsb

           ! reject data with bad quality mark from SDM
           if(abs(hdrdat(13)) < 100._r_kind)then
              if(nint(hdrdat(13)) == 12 .or. nint(hdrdat(13)) == 14) cycle loop_readsb      
           end if

           ! reject data outside time window
           idate5(1) = hdrdat(4)     !year
           idate5(2) = hdrdat(5)     ! month
           idate5(3) = hdrdat(6)     ! day
           idate5(4) = hdrdat(7)     ! hours
           idate5(5) = hdrdat(8)     ! minutes
           call w3fs21(idate5,nmind)
           t4dv = real((nmind-iwinbgn),r_kind)*r60inv
           sstime = real(nmind,r_kind) 
           tdiff=(sstime-gstime)*r60inv
           if (l4dvar.or.l4densvar) then
              if (t4dv<zero .OR. t4dv>winlen) cycle loop_readsb 
           else
              if (abs(tdiff)>twind) cycle loop_readsb 
           endif

           ! reject data with bad lat/lon
           if(abs(hdrdat(2)) >r90 ) cycle loop_readsb 
           if( hdrdat(3) <zero) hdrdat(3) = hdrdat(3) + r360
           if( hdrdat(3) == r360) hdrdat(3) = hdrdat(3) - r360
           if( hdrdat(3) > r360) cycle loop_readsb 

           qm=2
           zangl=hdrdat(10)
           isaid=nint(hdrdat(01))
           ihdr9=nint(hdrdat(09))
           write(stationid,'(i3.3)') isaid  
           if(ihdr9<1.or.ihdr9>7) cycle loop_readsb

           ! counter for satwnd types
           !if(itype>=240.and.itype<=279) icnt(itype)=icnt(itype)+1             

           ! collect any qc data ahead of time to use it !
           call ufbrep(lunin,qcdat,3,12,qcret,qcstr)

!------------------------------------------------------------------------------------------
           select case (istype) ! special treatment for each istype        
!------------------------------------------------------------------------------------------

           case(0) ! quality block for new EUMETSAT BUFR

              c_prvstg='EUMETSAT'
              c_station_id=swcm(ihdr9)//stationid
              c_sprvstg=swcm(ihdr9)

           case(1) ! quality block for new EUMETSAT BUFR

              if(zangl >68.0_r_kind) cycle loop_readsb   !   reject data zenith angle >68.0 degree 
              c_prvstg='EUMETSAT'
              c_station_id=swcm(ihdr9)//stationid
              c_sprvstg=swcm(ihdr9)

              do j=4,9
                 if( qify <r105 .and. qifn <r105 .and. ee <r105) exit
                 if(qcdat(2,j) < r10000 .and. qcdat(3,j) <r10000) then
                    if(qcdat(2,j) == one .and. qify >r105) then
                       qify=qcdat(3,j)
                    else if(qcdat(2,j) == two .and. qifn >r105) then
                       qifn=qcdat(3,j)
                    else if(qcdat(2,j) ==  three .and. ee >r105) then
                       ee=qcdat(3,j)
                    endif
                 endif
              enddo
              if(qifn <85.0_r_kind ) qm=15    !  qifn, QI without forecast

           case(2) ! Extra block for new EUMETSAT BUFR: Start

              if(zangl >68.0_r_kind) cycle loop_readsb   !   reject data zenith angle >68.0 degree 
              c_prvstg='EUMETSAT'
              c_station_id=swcm(ihdr9)//stationid
              c_sprvstg=swcm(ihdr9)
              
              if(ihdr9>=4) qm =9

              !  get quality information THIS SECTION NEEDS TO BE TESTED!!!
              call ufbint(lunin,rep_array,1,1,iret, '{AMVIVR}')
              irep_array = max(1,int(rep_array))
              allocate( amvivr(2,irep_array))
              call ufbrep(lunin,amvivr,2,irep_array,iret, 'TCOV CVWD')
              pct1 = amvivr(2,1)     ! use of pct1 (a new variable in the BUFR) is introduced by Nebuda/Genkova
              deallocate( amvivr )
              call ufbseq(lunin,amvqic,2,4,iret, 'AMVQIC') ! AMVQIC:: GNAPS PCCF
              qifn = amvqic(2,2)  ! QI w/ fcst does not exist in this BUFR
              ee = amvqic(2,4) ! NOTE: GOES-R's ee is in [m/s]
              if(qifn <85.0_r_kind ) qm=15    !  qifn, QI without forecast

           case(3) 

              c_prvstg='JMA'
              c_station_id=swcm(ihdr9)//stationid
              c_sprvstg=swcm(ihdr9)

           case(4) 

              if(zangl >68.0_r_kind) cycle loop_readsb   !   reject data zenith angle >68.0 degree 
              c_prvstg='JMA'
              c_station_id=swcm(ihdr9)//stationid
              c_sprvstg=swcm(ihdr9)

              do j=4,9
                 if( qify <=r105 .and. qifn <r105 .and. ee <r105) exit
                 if(qcdat(2,j) <= r10000 .and. qcdat(3,j) <r10000) then
                    if(qcdat(2,j) == 101.0_r_kind .and. qify >r105 ) then
                       qify=qcdat(3,j)
                    else if(qcdat(2,j) == 102.0_r_kind .and. qifn >r105 ) then
                       qifn=qcdat(3,j)
                    else if(qcdat(2,j) == 103.0_r_kind .and. ee >r105) then
                       ee=qcdat(3,j)
                    endif
                 endif
              enddo
              if(qifn <85.0_r_kind ) qm=15     ! qifn: QI value without forecast 

           case(5) 

              if(zangl >68.0_r_kind) cycle loop_readsb   !   reject data zenith angle >68.0 degree 
              c_prvstg='JMA'
              c_station_id=swcm(ihdr9)//stationid
              c_sprvstg=swcm(ihdr9)

              if(ihdr9>=4) qm=9

              call ufbint(lunin,rep_array,1,1,iret, '{AMVIVR}')
              irep_array = max(1,int(rep_array))
              allocate( amvivr(2,irep_array))
              call ufbrep(lunin,amvivr,2,irep_array,iret, 'TCOV CVWD')
              pct1 = amvivr(2,1)     ! use of pct1 (a new variable in the BUFR) is introduced by Nebuda/Genkova
              deallocate( amvivr )
              call ufbseq(lunin,amvqic,2,4,iret, 'AMVQIC') ! AMVQIC:: GNAPS PCCF
              qifn = amvqic(2,2)  ! QI w/ fcst does not exist in this BUFR
              ee = amvqic(2,4) ! NOTE: GOES-R's ee is in [m/s]

              if(qifn <85.0_r_kind ) qm=15    !  qifn, QI without forecast

           case(6) 

              !if(zangl >68.0_r_kind) cycle loop_readsb   !   reject data zenith angle >68.0 degree 
              c_prvstg='NESDIS' 
              c_station_id=swcm(ihdr9)//stationid
              c_sprvstg=swcm(ihdr9)

           case(7) 

              if(zangl >68.0_r_kind) cycle loop_readsb   !   reject data zenith angle >68.0 degree 
              c_prvstg='NESDIS' 
              c_station_id=swcm(ihdr9)//stationid
              c_sprvstg=swcm(ihdr9)

              do j=1,8
                 if( qify <=r105 .and. qifn <r105 .and. ee < r105) exit
                 if(qcdat(2,j) <= r10000 .and. qcdat(3,j) <r10000) then
                    if( qcdat(2,j) == one .and. qifn >r105 ) then
                       qifn=qcdat(3,j)
                    else if(qcdat(2,j) == three .and. qify >r105) then
                       qify=qcdat(3,j)
                    else if( qcdat(2,j) == four .and. ee >r105) then
                       ee=qcdat(3,j) 
                    endif
                 endif
              enddo

              !QI not applied to CAWV for now - may in the future
              if(qifn <85.0_r_kind .and. itype /= 247)  qm=15

              if(wrf_nmm_regional) then
                 ! Minimum speed requirement for CAWV of 8m/s for HWRF. 
                 ! Tighten QC for 247 winds by removing winds below 450hPa
                 if(itype == 247 .and. obsdat(4) < 8.0_r_kind .and. ppb > 450.0_r_kind) then
                    qm=15
                 ! Tighten QC for 240 winds by remove winds above 700hPa
                 elseif(itype == 240 .and. ppb < 700.0_r_kind) then
                    qm=15
                 ! Tighten QC for 251 winds by remove winds above 750hPa
                 elseif(itype == 251 .and. ppb < 750.0_r_kind) then
                    qm=15
                 endif
              else
                 ! Minimum speed requirement for CAWV of 10m/s
                 if(itype == 247 .and. obsdat(4) < 10.0_r_kind)  then
                    qm=15
                 endif
              endif

           case(8) 

              c_prvstg='MODIS' 

              if(ihdr9 == 1)  then           
                 c_station_id='IR'//stationid
                 c_sprvstg='IR'
              else if(ihdr9 == 3) then                     
                 c_station_id='WV'//stationid
                 c_sprvstg='WVCLOP'
              else if(ihdr9 >= 4) then                    
                 c_station_id='WV'//stationid
                 c_sprvstg='WVDLAYER'
              endif

              do j=1,8
                 if( qify <=r105 .and. qifn <r105 .and. ee < r105) exit
                 if(qcdat(2,j) <= r10000 .and. qcdat(3,j) <r10000) then
                    if(qcdat(2,j) == one .and. qifn >r105) then
                       qifn=qcdat(3,j)
                    else if(qcdat(2,j) == three .and. qify >r105) then
                       qify=qcdat(3,j)
                    else if( qcdat(2,j) == four .and. ee >r105 ) then
                       ee=qcdat(3,j) 
                    endif
                 endif
              enddo

           case(9) 

              c_prvstg='AVHRR'

              do j=1,6
                 if( qify <=r105 .and. qifn <r105 .and. ee <r105) exit
                 if(qcdat(2,j) <= r10000 .and. qcdat(3,j) <r10000 ) then
                    if(qcdat(2,j) ==  one  .and. qifn >r105) then
                       qifn=qcdat(3,j)
                    else if(qcdat(2,j) ==  three .and. qify >r105) then
                       qify=qcdat(3,j)
                    else if( qcdat(2,j) == four .and. ee >r105) then
                       ee=qcdat(3,j)
                    endif
                 endif
              enddo

           case(10)

              c_prvstg='METOP' 
              c_station_id=swcm(ihdr9)//stationid
              c_sprvstg=swcm(ihdr9)

              call ufbint(lunin,rep_array,1,1,iret, '{AMVIVR}')
              irep_array = int(rep_array)
              allocate( amvivr(2,irep_array))
              call ufbrep(lunin,amvivr,2,irep_array,iret, 'TCOV CVWD')
              pct1 = amvivr(2,1)     ! use of pct1 is limited to GOES-16/17) as introduced by Nebuda/Genkova
              deallocate( amvivr )
              call ufbseq(lunin,amvqic,2,4,iret, 'AMVQIC') ! AMVQIC:: GNAPS PCCF
              qifn = amvqic(2,2)  ! QI w/ fcst does not exist in this BUFR
              ee = amvqic(2,4) ! NOTE: GOES-R's ee is in [m/s]

           case(11)

              if(zangl >68.0_r_kind) cycle loop_readsb   !   reject data zenith angle >68.0 degree 
              c_prvstg='NESDIS'
              c_station_id=swcm(ihdr9)//stationid
              c_sprvstg=swcm(ihdr9)

              do j=1,6
                 if( qify <=r105 .and. qifn <r105 .and. ee <r105) exit
                 if(qcdat(2,j) <= r10000 .and. qcdat(3,j) <r10000 ) then
                    if(qcdat(2,j) ==  one  .and. qifn >r105) then
                       qifn=qcdat(3,j)
                    else if(qcdat(2,j) ==  three .and. qify >r105) then
                       qify=qcdat(3,j)
                    else if( qcdat(2,j) == four .and. ee >r105) then
                       ee=qcdat(3,j)
                    endif
                 endif
              enddo
              ! Tighten QC for 240 winds by removing winds above 700hPa
              if(wrf_nmm_regional) then
                 if(itype == 240 .and. ppb < 700.0_r_kind) qm=15
              endif

           case(12)

              c_prvstg='LEOGEO'
              c_station_id=swcm(ihdr9)//stationid
              c_sprvstg=swcm(ihdr9)

           case(13)

              c_prvstg='VIIRS'
              c_station_id=swcm(ihdr9)//stationid
              c_sprvstg=swcm(ihdr9)
 
              do j=1,6
                 if( qify <=r105 .and. qifn <r105 .and. ee <r105) exit
                 if(qcdat(2,j) <= r10000 .and. qcdat(3,j) <r10000 ) then
                    if(qcdat(2,j) ==  one  .and. qifn >r105) then
                       qifn=qcdat(3,j)
                    else if(qcdat(2,j) ==  three .and. qify >r105) then
                       qify=qcdat(3,j)
                    else if( qcdat(2,j) == four .and. ee >r105) then
                       ee=qcdat(3,j)
                    endif
                 endif
              enddo
              if(qifn <85.0_r_kind ) qm=15    !  qifn, QI without forecast

           case(14)

              c_prvstg='VIIRS'
              c_station_id=swcm(ihdr9)//stationid
              c_sprvstg=swcm(ihdr9)

              call ufbint(lunin,rep_array,1,1,iret, '{AMVIVR}')
              irep_array = int(rep_array)
              allocate( amvivr(2,irep_array))
              call ufbrep(lunin,amvivr,2,irep_array,iret, 'TCOV CVWD')
              pct1 = amvivr(2,1)     ! use of pct1 (a new variable in the BUFR) is introduced by Nebuda/Genkova
              deallocate( amvivr )

              call ufbseq(lunin,amvqic,2,4,iret, 'AMVQIC') ! AMVQIC:: GNAPS PCCF
              qifn = amvqic(2,2)  ! QI w/ fcst does not exist in this BUFR
              ee = amvqic(2,4) ! NOTE: GOES-R's ee is in [m/s]

           case default

           ! istypes 15-20 are handled differently

           if (istype >= 15 .and. istype <=20)then

              c_prvstg='GOESR' 
              if(istype == 15)  then                 ! IR LW winds
                 if(hdrdat(10) >68.0_r_kind) cycle loop_readsb   !   reject data zenith angle >68.0 degree 
!                itype=245
                 c_station_id='IR'//stationid
                 c_sprvstg='IR'
                 !write(6,*)'itype= ',itype
              else if(istype == 16)  then            ! IR SW winds
                 if(hdrdat(10) >68.0_r_kind) cycle loop_readsb   !   reject data zenith angle >68.0 degree 
!                itype=240                                      
                 c_station_id='IR'//stationid
                 c_sprvstg='IRSW'
                 !write(6,*)'itype= ',itype
              else if(istype == 17)  then            ! VIS winds
                 if(hdrdat(10) >68.0_r_kind) cycle loop_readsb   !   reject data zenith angle >68.0 degree 
!                itype=251
                 c_station_id='VI'//stationid
                 c_sprvstg='VIS'
                    !write(6,*)'itype= ',itype
              else if(istype == 18)  then            ! WV cloud top
                 if(hdrdat(10) >68.0_r_kind) cycle loop_readsb   !   reject data zenith angle >68.0 degree 
!                itype=246
                 c_station_id='WV'//stationid
                 c_sprvstg='WVCT'
                 !write(6,*)'itype= ',itype
              else if(istype == 19)  then            ! WV clear sky/deep layer
                 if(hdrdat(10) >68.0_r_kind) cycle loop_readsb   !   reject data zenith angle >68.0 degree 
!                itype=247
                 c_station_id='WV'//stationid
                 c_sprvstg='WVCS'
                 !write(6,*)'itype= ',itype
              else if(istype == 20)  then            ! WV clear sky/deep layer
                 hdrdat(10)=61.23 ! set zenith angle for CIMSS AMVs to 67 to pass QC, no value in origional data
!                itype=241
                 c_station_id='IR'//stationid
                 c_sprvstg='IR'
              endif

!              call ufbint(lunin,rep_array,1,1,iret, '{AMVAHA}')
!              irep_array = int(rep_array)
!              allocate( amvaha(4,irep_array))
!              call ufbint(lunin,amvaha,4,irep_array,iret, 'EHAM PRLC TMDBST HOCT')
!              deallocate( amvaha )

!              call ufbint(lunin,rep_array,1,1,iret, '{AMVIII}')
!              irep_array = int(rep_array)
!              allocate( amviii(12,irep_array))
!              call ufbrep(lunin,amviii,12,irep_array,iret, 'LTDS SCLF SAID SIID CHNM SCCF ORBN SAZA BEARAZ EHAM PRLC TMDBST')
!              deallocate( amviii )

              if (itype /= 241) then

                call ufbint(lunin,rep_array,1,1,iret, '{AMVIVR}')
                irep_array = int(rep_array)
                allocate( amvivr(2,irep_array))
                call ufbrep(lunin,amvivr,2,irep_array,iret, 'TCOV CVWD') 
                pct1 = amvivr(2,1)     ! use of pct1 (a new variable in the BUFR) is introduced by Nebuda/Genkova
                deallocate( amvivr )

!               call ufbrep(lunin,rep_array,1,1,iret, '{AMVCLD}')
!               irep_array = int(rep_array)
!               allocate( amvcld(12,irep_array))
!               call ufbrep(lunin,amvcld,12,irep_array,iret, 'FOST CDTP MUCE VSAT TMDBST VSAT CDTP MUCE OECS CDTP HOCT COPT')
!               deallocate( amvcld )

                call ufbseq(lunin,amvqic,2,4,iret, 'AMVQIC')
                qifn = amvqic(2,2)  ! QI w/ fcst does not exist in this BUFR
                ee = amvqic(2,4) ! NOTE: GOES-R's ee is in [m/s]

! Additional QC introduced by Sharon Nebuda (for GOES-R winds from MSG proxy images)
                if (qifn < 80_r_kind .or. qifn > r100 )then
                   qm=15 !reject data with low QI
                else if (ppb < 125.0_r_kind) then
                   qm=15 !reject data above 125hPa: Trop check in setup.f90
                else if (obsdat(4) > 0.1_r_kind) then  ! obsdat(4) is the AMV speed
                   experr_norm = (10.0_r_kind - 0.1_r_kind * ee)/obsdat(4)   ! introduced by Santek/Nebuda 
                   if (experr_norm > 0.9_r_kind) qm=15 ! reject data with EE/SPD>0.9
                else
                   qm=15
                end if

                if(wrf_nmm_regional) then
                   ! type 251 has been determine not suitable to be subjected to pct1 range check
                   if(itype==240 .or. itype==245 .or. itype==246 .or. itype==241) then
                      if (pct1 < 0.04_r_kind .or. pct1 > 0.50_r_kind) qm=15
                   elseif (itype==251) then
                      if (pct1 > 0.50_r_kind) qm=15
                   endif
                else
                   if(itype==240 .or. itype==245 .or. itype==246 .or. itype==251) then 
                   ! types 245 and 246 have been used to determine the acceptable pct1 range, but that pct1 range is applied to all GOES-R winds
                      if (pct1 < 0.04_r_kind .or. pct1 > 0.50_r_kind) qm=15
                   endif
                endif

! GOES-16 additional QC addopting ECMWF's approach(Katie Lean,14IWW)-start
                if (EC_AMV_QC) then 
                   if (qifn < 90_r_kind .or. qifn > r100 )   qm=15 ! stricter QI
                   if (ppb < 150.0_r_kind) qm=15                   ! all high level
                   if (itype==251 .and. ppb < 700.0_r_kind) qm=15  ! VIS
                   if (itype==246 .and. ppb > 300.0_r_kind) qm=15  ! WVCA 
                   if (qm < 15)then
                      dlon_earth=hdrdat(3)*deg2rad
                      dlat_earth=hdrdat(2)*deg2rad
                      call deter_sfc_type(dlat_earth,dlon_earth,t4dv,isflg,tsavg)
                      if (isflg == 1 .and. ppb > 850.0_r_kind) qm=15  ! low over land
                   end if
                endif

              else ! Assign values for the mnemonics/variables missing in original datafile for type 241

                call ufbint(lunin,hdrdat_005099,2,1,iret, 'GNAPS PCCF');
                qifn=hdrdat_005099(2);
                qm=2            ! do not reject the wind
                pct1=0.4_r_kind ! do not reject the wind
                ee=1.0_r_kind   ! do not reject the wind

              endif

                 ! winds rejected by qc dont get used
              if (qm == 3 .or. qm ==7) woe=woe*r1_2
                 ! set strings for diagnostic output

           else
              cycle loop_readsb ! no cases selected then skip this subset
           endif 

           end select

           ! assign types and get quality info : end

           if ( qify == zero) qify=r110
           if ( qifn == zero) qifn=r110
           if ( ee == zero)   ee=r110

           nread=nread+2
           dlon_earth_deg=hdrdat(3)
           dlat_earth_deg=hdrdat(2)
           dlon_earth=hdrdat(3)*deg2rad
           dlat_earth=hdrdat(2)*deg2rad
                              
!       If regional, map obs lat,lon to rotated grid.
           if(regional)then
              call tll2xy(dlon_earth,dlat_earth,dlon,dlat,outside)
              if(diagnostic_reg) then
                 call txy2ll(dlon,dlat,rlon00,rlat00)
                 ntest=ntest+1
                 cdist=sin(dlat_earth)*sin(rlat00)+cos(dlat_earth)*cos(rlat00)* &
                       (sin(dlon_earth)*sin(rlon00)+cos(dlon_earth)*cos(rlon00))
                 cdist=max(-one,min(cdist,one))
                 disterr=acos(cdist)*rad2deg
                 disterrmax=max(disterrmax,disterr)
              end if
              if(outside) cycle loop_readsb 
           else
              dlon=dlon_earth
              dlat=dlat_earth
              call grdcrd1(dlat,rlats,nlat,1)
              call grdcrd1(dlon,rlons,nlon,1)
           endif

!!   detect surface type for  IR winds monitoring over land for lat greter than 20N
!     isflg    - surface flag
!                0 sea
!                1 land
!                2 sea ice
!                3 snow
!                4 mixed
           if( .not. twodvar_regional) then
              if(itype ==245 .or. itype ==252 .or. itype ==253 .or. itype ==240 .or. itype ==241) then
                 if(hdrdat(2) >20.0_r_kind) then 
                    call deter_sfc_type(dlat_earth,dlon_earth,t4dv,isflg,tsavg)
                    if(isflg /= 0) cycle loop_readsb 
                 endif
              endif
           endif

!!    convert from wind direction and speed to u,v component
           uob=-obsdat(4)*sin(obsdat(3)*deg2rad)
           vob=-obsdat(4)*cos(obsdat(3)*deg2rad)
!!!  some information only has in NESDIS satellite winds
!          if(hdrdat(1) >=r200 .and. hdrdat(1) <= r299 ) then
!             call ufbseq(lunin,heightdat,3,5,iret,heightr)         
!             call ufbseq(lunin,derdwdat,6,4,iret,derdwtr)         
!             write(99,*) 'heightdat ',itype
!             write(99,101) heightdat(2,1),heightdat(2,2),heightdat(2,3),heightdat(2,4),heightdat(2,5)
!101 format(5e10.2)
!             uob1=-derdwdat(6,2)*sin(derdwdat(5,2)*deg2rad)    ! get originial wind info
!             vob1=-derdwdat(6,2)*cos(derdwdat(5,2)*deg2rad)    ! get originial wind info
!             if(itype == 245 ) then
!                ppb1=heightdat(2,1)/r100                        ! window height assignment value
!                ppb2=heightdat(2,4)/r100                        ! co2 height assignment value  
!             else if(itype == 246) then
!                ppb1=heightdat(2,3)/r100                        !  H2O height assignment value
!                ppb2=heightdat(2,4)/r100                        ! co2 height assignment value
!             endif
!          endif

!  first to get observation error from PREPBUFR observation error table
           ppb=max(zero,min(ppb,r2000))
           if (njqc) then
              itypey=itype
              ierr=0
              do i =1,maxsub_uv
                 if( icsubtype(nc) == isuble_uv(itypey,i) ) then
                    ierr=i+1
                    exit
                 else if( i == maxsub_uv .and. icsubtype(nc) /= isuble_uv(itypey,i)) then
                    ncount=ncount+1
                    do j=1,maxsub_uv
                       if(isuble_uv(itypey,j) ==0 ) then
                          ierr=j+1
                          exit
                       endif
                    enddo
                    if (ncount ==1) then
                       write(6,*) 'READ_SATWND,WARNING cannot find subtype in the error table,&
                                   itype,isaid=',itypey,icsubtype(nc)
                       write(6,*) 'read error table at colomn subtype as 0,error table column=',ierr
                    endif
                 endif
              enddo
              if(ppb>=etabl_uv(itypey,1,1)) k1=1
              do kl=1,32
                 if(ppb>=etabl_uv(itypey,kl+1,1).and.ppb<=etabl_uv(itypey,kl,1)) then
                    k1=kl
                    exit
                 endif
              end do
              k2=k1+1
              if(ppb<=etabl_uv(itypey,33,1)) then
                 k1=33
                 k2=33
              endif
              ediff = etabl_uv(itypey,k2,1)-etabl_uv(itypey,k1,1)
              if (abs(ediff) > tiny_r_kind) then
                 del = (ppb-etabl_uv(itypey,k1,1))/ediff
              else
                 del = huge_r_kind
              endif
              del=max(zero,min(del,one))
              obserr=(one-del)*etabl_uv(itypey,k1,ierr)+del*etabl_uv(itypey,k2,ierr)
              obserr=max(obserr,werrmin)
!  get non linear qc parameter from b table
              var_jb=(one-del)*btabl_uv(itypey,k1,ierr)+del*btabl_uv(itypey,k2,ierr)
              var_jb=max(var_jb,wjbmin)
              if (var_jb >=10.0_r_kind) var_jb=zero
!              if (itype ==245 ) then
!                write(6,*)
!                'READ_SATWND:obserr,var_jb,ppb,del,one,etabl_uv,btabl_uv=',&
!                obserr,var_jb,ppb,del,one,etabl_uv(itypey,k1,ierr),btabl_uv(itypey,k1,ierr),wjbmin,werrmin
!           endif
           else                         ! else use the ONE error table
              if(ppb>=etabl(itype,1,1)) k1=1
              do kl=1,32
                 if(ppb>=etabl(itype,kl+1,1).and.ppb<=etabl(itype,kl,1)) k1=kl
              end do
              if(ppb<=etabl(itype,33,1)) k1=33
              k2=k1+1
              ediff = etabl(itype,k2,1)-etabl(itype,k1,1)
              if (abs(ediff) > tiny_r_kind) then
                 del = (ppb-etabl(itype,k1,1))/ediff
              else
                 del = huge_r_kind
              endif
              del=max(zero,min(del,one))
              obserr=(one-del)*etabl(itype,k1,4)+del*etabl(itype,k2,4)
              obserr=max(obserr,werrmin)
           endif                    ! end of njqc

           if((itype==245 .or. itype==246) &
              .and. istype == 7) then !only applies to AMVs from legacy algorithm (pre GOES-R)
!  using Santek quality control method,calculate the original ee value:
!  NOTE: Up until GOES-R winds algorithm, EE (expected error, ee) is reported as percent 0-100% (the higher the ee, the better the wind quality)
!  NOTE: In the new GOES-R BUFR, EE (expected error, ee) is reported in m/s (the smaller the ee, the better the wind quality)
              if(ee <r105) then
                 ree=(ee-r100)/(-10.0_r_kind)
                 if(obsdat(4) >zero) then
                    ree=ree/obsdat(4)
                 else
                    ree=two
                 endif
              else
                 ree=0.2_r_kind
              endif
              if( ppb >= 800.0_r_kind .and. ree >0.55_r_kind) then
                 qm=15
              else if (ree >0.8_r_kind) then
                 qm=15
              endif
           endif

! Reduce OE for the GOES-R winds by half following Sharon Nebuda's work
! GOES-R wind are identified/recognised here by subset, but it could be done by itype or SAID
! After completing the evaluation of GOES-R winds, REVISE this section!!!
           if(istype >= 15 .and. istype <=20)then  
              obserr=obserr/two
           endif

!           if(itype==240) then;  c_prvstg='NESDIS'   ;  c_sprvstg='IR'       ; endif
!           if(itype==242) then;  c_prvstg='JMA'      ;  c_sprvstg='VI'       ; endif
!           if(itype==243) then;  c_prvstg='EUMETSAT' ;  c_sprvstg='VI'       ; endif
!           if(itype==244) then;  c_prvstg='AVHRR'    ;  c_sprvstg='IR'       ; endif
!           if(itype==245) then;  c_prvstg='NESDIS'   ;  c_sprvstg='IR'       ; endif
!           if(itype==246) then;  c_prvstg='NESDIS'   ;  c_sprvstg='WV'       ; endif
!           if(itype==250) then;  c_prvstg='JMA'      ;  c_sprvstg='WV'       ; endif
!           if(itype==251) then;  c_prvstg='NESDIS'   ;  c_sprvstg='VI'       ; endif
!           if(itype==252) then;  c_prvstg='JMA'      ;  c_sprvstg='IR'       ; endif
!           if(itype==253) then;  c_prvstg='EUMETSAT' ;  c_sprvstg='IR'       ; endif
!           if(itype==254) then;  c_prvstg='EUMETSAT' ;  c_sprvstg='WV'       ; endif
!           if(itype==255) then;  c_prvstg='LEOGEO'   ;  c_sprvstg='IR'       ; endif
!           if(itype==257) then;  c_prvstg='MODIS'    ;  c_sprvstg='IR'       ; endif
!           if(itype==258) then;  c_prvstg='MODIS'    ;  c_sprvstg='WVCTOP'   ; endif
!           if(itype==259) then;  c_prvstg='MODIS'    ;  c_sprvstg='WVDLAYER' ; endif
!           if(itype==260) then;  c_prvstg='VIIRS'    ;  c_sprvstg='IR'       ; endif
!           c_station_id='SATWND'

! Get information from surface file necessary for conventional data here
           call deter_sfc2(dlat_earth,dlon_earth,t4dv,idomsfc,tsavg,ff10,sfcr,zz)
 
!!    process the thining procedure
                
           ithin=ithin_conv(nc)
           ithinp = ithin > 0  .and. ithin <5 .and. qm < 4
!          if(ithinp  .and. iuse >=0 )then
           if(ithinp .and. pflag /= 0   )then
!          Interpolate guess pressure profile to observation location
              klon1= int(dlon);  klat1= int(dlat)
              dx   = dlon-klon1; dy   = dlat-klat1
              dx1  = one-dx;     dy1  = one-dy
              w00=dx1*dy1; w10=dx1*dy; w01=dx*dy1; w11=dx*dy
              klat1=min(max(1,klat1),nlat); klon1=min(max(0,klon1),nlon)
              if (klon1==0) klon1=nlon
              klatp1=min(nlat,klat1+1); klonp1=klon1+1
              if (klonp1==nlon+1) klonp1=1
              do kk=1,nsig
                 presl(kk)=w00*prsl_full(klat1 ,klon1 ,kk) +  &
                           w10*prsl_full(klatp1,klon1 ,kk) + &
                           w01*prsl_full(klat1 ,klonp1,kk) + &
                           w11*prsl_full(klatp1,klonp1,kk)
              end do
 
 !         Compute depth of guess pressure layersat observation location
           end if

           dlnpob=log(one_tenth*ppb)  ! ln(pressure in cb)
           ppb=one_tenth*ppb         ! from mb to cb
 !         Special block for data thinning - if requested
           if (ithinp) then
 !         Set data quality index for thinning
              if (thin4d) then
                 timedif = zero
              else
                 timedif=abs(t4dv-toff)
              endif
              crit1 = timedif/r6+half
              if(itype == 243 .or. itype == 253 .or. itype == 254) then
                 if(qifn <r105) crit1 = crit1 + four*(one-qifn/r100)*r3_33
              else if(itype == 245 .or. itype == 246) then
                 if(qifn <r105 .and. ee <r105) crit1 = crit1  + &
                          four*(one-qifn/r100)*r3_33+(one-ee/r100)*r3_33
              endif
              if (pflag==0) then
                 do kk=1,nsig
                    presl_thin(kk)=presl(kk)
                 end do
              endif
              if (ptime >zero ) then
                 itime=int((tdiff+three)/ptime)+1
                 if (itime >ntime) itime=ntime
                 call map3grids_m_tm(-1,save_all,pflag,presl_thin,nlevp,dlat_earth,dlon_earth,&
                              ppb,itime,crit1,ndata,luse,maxobs,rthin,.false.,.false.)
              else
                 call map3grids_m(-1,save_all,pflag,presl_thin,nlevp,dlat_earth,dlon_earth,&
                              ppb,crit1,ndata,luse,maxobs,rthin,.false.,.false.)
              endif
              if(.not. luse) cycle loop_readsb
           else
              ndata=ndata+1
           endif
           iout=ndata
           iuse=icuse(nc)
           if(iuse < 0)qm = 9
           if(qm > 7 .or. iuse < 0 )rusage(iout)=.false.
           inflate_error=.false.
           if (qm==3 .or. qm==7) inflate_error=.true.
           woe=obserr
           if (inflate_error) woe=woe*r1_2
           if(regional .and. .not. fv3_regional)then
              u0=uob
              v0=vob
              call rotate_wind_ll2xy(u0,v0,uob,vob,dlon_earth,dlon,dlat)
              if(diagnostic_reg) then
                 call rotate_wind_xy2ll(uob,vob,u00,v00,dlon_earth,dlon,dlat)
                 nvtest=nvtest+1
                 disterr=sqrt((u0-u00)**2+(v0-v00)**2)
                 vdisterrmax=max(vdisterrmax,disterr)
              end if
           endif
           cdata_all(1,iout)=woe                  ! wind error
           cdata_all(2,iout)=dlon                 ! grid relative longitude
           cdata_all(3,iout)=dlat                 ! grid relative latitude
           cdata_all(4,iout)=dlnpob               ! ln(pressure in cb)
           cdata_all(5,iout)=ee                   !  quality information 
           cdata_all(6,iout)=uob                  ! u obs
           cdata_all(7,iout)=vob                  ! v obs 
           cdata_all(8,iout)=rstation_id          ! station id 
           cdata_all(9,iout)=t4dv                 ! time
           cdata_all(10,iout)=nc                  ! index of type in convinfo file
           cdata_all(11,iout)=qifn +1000.0_r_kind*qify   ! quality indicator  
           cdata_all(12,iout)=qm                  ! quality mark
           cdata_all(13,iout)=obserr              ! original obs error
           cdata_all(14,iout)=0                   ! usage parameter
           cdata_all(15,iout)=idomsfc             ! dominate surface type
           cdata_all(16,iout)=tsavg               ! skin temperature
           cdata_all(17,iout)=ff10                ! 10 meter wind factor
           cdata_all(18,iout)=sfcr                ! surface roughness
           cdata_all(19,iout)=dlon_earth_deg      ! earth relative longitude (degrees)
           cdata_all(20,iout)=dlat_earth_deg      ! earth relative latitude (degrees)
           cdata_all(21,iout)=zz                  ! terrain height at ob location
           cdata_all(22,iout)=r_prvstg(1,1)       ! provider name
           cdata_all(23,iout)=r_sprvstg(1,1)      ! subprovider name
           cdata_all(25,iout)=var_jb              ! non linear qc parameter
           cdata_all(26,iout)=one                 ! hilbert curve weight

           if(perturb_obs)then
              cdata_all(27,iout)=ran01dom()*perturb_fact ! u perturbation
              cdata_all(28,iout)=ran01dom()*perturb_fact ! v perturbation
           endif


        enddo  loop_readsb
 !   End of bufr read loop
     enddo loop_msg
!    Deallocate arrays used for thinning data
     if (.not.use_all) then
        deallocate(presl_thin)
        call del3grids
     endif
     if (.not.use_all_tm) then
        deallocate(presl_thin)
        call del3grids_tm
     endif
! Normal exit
  enddo loop_convinfo! loops over convinfo entry matches
  deallocate(lmsg,tab,nrep)
! Close unit to bufr file
  call closbf(lunin)
!
  if(ndata > 0)then
!  numthin=0
!  numqc=0
!  numrem=0
!  do i=1,ndata
!     if(.not. rusage(i))then
!        numqc=numqc+1
!     else if(rthin(i))then
!        numthin=numthin+1
!     else
!        numrem=numrem+1
!     end if
!  end do
!  write(6,*) ' smar ',trim(ioctype(nc)),ictype(nc),icsubtype(nc),numall,numrem,numqc,numthin
!   If thinned data set usage
     do i=1,ndata
       if(rthin(i))then
          cdata_all(12,i)=14
          cdata_all(14,i)=101.0_r_kind
       end if
       if(.not. rusage(i))cdata_all(14,i) = 100.0_r_kind
     end do
     nxdata=ndata
!  If flag to not save thinned data is set - compress data
     ndata=0
     do i=1,nxdata
!   pmot=0 - all obs - thin obs
!   pmot=1 - all obs
!   pmot=2 - use obs
!   pmot=3 - use obs + thin obs
        if((pmot == 0 .and. .not. rthin(i)) .or. &
           (pmot == 1) .or.  &
           (pmot == 2 .and. rusage(i) .and. .not. rthin(i))  .or. &
           (pmot == 3 .and. rusage(i))) then

           ndata=ndata+1
           do k=1,nreal
              cdata_all(k,ndata)=cdata_all(k,i)
           end do
        end if
     end do
     nodata=nodata+2*ndata
  end if
  deallocate(rusage,rthin)


  ! Write header record and data to output file for further processing
  
  call count_obs(ndata,nreal,ilat,ilon,cdata_all,nobs)
  write(lunout) obstype,sis,nreal,nchanl,ilat,ilon
  write(lunout) ((cdata_all(k,i),k=1,nreal),i=1,ndata)

  deallocate(cdata_all)

  if(diagnostic_reg)then
     if(ntest>0) write(6,*)'READ_SATWND:  ',&
       'ntest,disterrmax=',ntest,disterrmax
     if(nvtest>0) write(6,*)'READ_SATWND:  ',&
       'nvtest,vdisterrmax=',ntest,vdisterrmax
  end if

  if (ndata == 0) then
     write(6,*)'READ_SATWND:  closbf(',lunin,')'
  endif
  
  write(6,*) 'READ_SATWND,nread,ndata,nreal,nodata=',nread,ndata,nreal,nodata

  close(lunin)

end subroutine read_satwnd
!-------------------------------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------------------------------
      subroutine sattabin(sattab)

      integer sattab(100,1000,7,2)
      integer goes(20)/731,732,733,734,735,250,251,252,253,254,255,256,257,258,259,270,271,272,273,000/
      integer insa(20)/430,431,432,450,451,452,410,470,000,000,000,000,000,000,000,000,000,000,000,000/
      integer hima(20)/153,154,150,151,152,171,172,173,174,000,000,000,000,000,000,000,000,000,000,000/
      integer meto(20)/058,059,050,051,052,053,054,055,056,057,070,071,000,000,000,000,000,000,000,000/
      integer modi(20)/783,784,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000/
      integer lege(20)/854,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000/
      integer avhr(20)/003,004,005,206,207,208,209,223,225,226,000,000,000,000,000,000,000,000,000,000/
      integer viir(20)/224,225,226,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000/
      integer i

      sattab = -1

      do i=1,20; if(goes(i)==0) cycle
      sattab(001,goes(i),1,1)=245; sattab(001,goes(i),1,2)=06 ! MSG TYPE 005-001 NESDIS SATWIND, GOES LO-D IR(LW)(BINRY 
      sattab(002,goes(i),2,1)=251; sattab(002,goes(i),2,2)=06 ! MSG TYPE 005-002 NESDIS SATWIND, GOES LO-D VIS (BINARY 
      sattab(003,goes(i),3,1)=246; sattab(003,goes(i),3,2)=06 ! MSG TYPE 005-003 NESDIS SATWIND, GOES LO-D WV-IM(BINARY 
      sattab(004,goes(i),4,1)=245; sattab(004,goes(i),4,2)=06 ! MSG TYPE 005-004 NESDIS SATWIND, GOES PTRIP (OLD BINARY 

      sattab(005,goes(i),1,1)=245; sattab(005,goes(i),1,2)=06 ! MSG TYPE 005-005 NESDIS SATWIND, GOES HI-D IR(LW)(BINRY 
      sattab(006,goes(i),3,1)=251; sattab(006,goes(i),3,2)=06 ! MSG TYPE 005-006 NESDIS SATWIND, GOES HI-D WV-IM(BINARY 
      sattab(008,goes(i),2,1)=246; sattab(008,goes(i),2,2)=06 ! MSG TYPE 005-008 UW-CIMSS SATWIND, GOES VISIBLE (BINARY 
      sattab(009,goes(i),4,1)=245; sattab(009,goes(i),4,2)=06 ! MSG TYPE 005-009 NESDIS SATWIND, GOES PTRIP (NEW BINARY 

      sattab(010,goes(i),1,1)=245; sattab(010,goes(i),1,2)=07 ! MSG TYPE 005-010 NESDIS SATWIND, GOES HI-D IR(LW) (BUFR 
      sattab(011,goes(i),3,1)=246; sattab(011,goes(i),3,2)=07 ! MSG TYPE 005-011 NESDIS SATWIND, GOES HI-D WV-IMG (BUFR 
      sattab(012,goes(i),2,1)=251; sattab(012,goes(i),2,2)=07 ! MSG TYPE 005-012 NESDIS SATWIND, GOES HI-DENS VIS (BUFR 
      sattab(013,goes(i),4,1)=245; sattab(013,goes(i),4,2)=07 ! MSG TYPE 005-013 NESDIS SATWIND, GOES PICT. TRIP (BUFR 

      sattab(015,goes(i),1,1)=245; sattab(015,goes(i),1,2)=07 ! MSG TYPE 005-015 NESDIS SATWIND, GOES H-D IR (GTS-BUF 
      sattab(016,goes(i),3,1)=246; sattab(016,goes(i),3,2)=07 ! MSG TYPE 005-016 NESDIS SATWIND, GOES H-D WV-I (GTS-BUF 
      sattab(017,goes(i),2,1)=251; sattab(017,goes(i),2,2)=07 ! MSG TYPE 005-017 NESDIS SATWIND, GOES H-D VIS (GTS-BUF 
      sattab(019,goes(i),1,1)=240; sattab(019,goes(i),1,2)=11 ! MSG TYPE 005-019 NESDIS SATWIND, GOES HI-D IR(SW) (BUFR 
      enddo

      do i=1,20; if(insa(i)==0) cycle
      sattab(021,insa(i),1,1)=256; sattab(021,insa(i),1,2)=-1 ! MSG TYPE 005-021 INDIA SATWIND, INSAT IR CHANNEL 
      sattab(022,insa(i),2,1)=256; sattab(022,insa(i),2,2)=-1 ! MSG TYPE 005-022 INDIA SATWIND, INSAT VIS CHANNEL 
      sattab(023,insa(i),3,1)=256; sattab(023,insa(i),3,2)=-1 ! MSG TYPE 005-023 INDIA SATWIND, INSAT WV-IMG CHANNEL 
      sattab(024,insa(i),1,1)=256; sattab(024,insa(i),1,2)=-1 ! MSG TYPE 005-024 INDIA SATWIND, INSAT IR CHN (BUFR) 
      sattab(025,insa(i),2,1)=256; sattab(025,insa(i),2,2)=-1 ! MSG TYPE 005-025 INDIA SATWIND, INSAT VIS CHN(BUFR) 
      sattab(026,insa(i),3,1)=256; sattab(026,insa(i),3,2)=-1 ! MSG TYPE 005-026 INDIA SATWIND, INSAT WV CHN (BUFR) 
      enddo

      do i=1,20; if(goes(i)==0) cycle
      sattab(030,goes(i),1,1)=245; sattab(030,goes(i),1,2)=15 ! MSG TYPE 005-030 NESDIS SATWIND, GOES-16 IR(LW) (BUFR 
      sattab(031,goes(i),4,1)=247; sattab(031,goes(i),4,2)=19 ! MSG TYPE 005-031 NESDIS SATWIND, GOES-16 WV-IMG/DL(BUFR 
      sattab(031,goes(i),5,1)=247; sattab(031,goes(i),5,2)=19 ! MSG TYPE 005-031 NESDIS SATWIND, GOES-16 WV-IMG/DL(BUFR 
      sattab(032,goes(i),2,1)=251; sattab(032,goes(i),2,2)=17 ! MSG TYPE 005-032 NESDIS SATWIND, GOES-16 VIS (BUFR 
      sattab(034,goes(i),3,1)=246; sattab(034,goes(i),3,2)=18 ! MSG TYPE 005-034 NESDIS SATWIND, GOES-16 WV-IMG/CT(BUFR 
      sattab(039,goes(i),1,1)=240; sattab(039,goes(i),1,2)=16 ! MSG TYPE 005-039 NESDIS SATWIND, GOES-16 IR(SW) (BUFR 
      enddo

      do i=1,20; if(hima(i)==0) cycle
      sattab(041,hima(i),1,1)=252; sattab(041,hima(i),1,2)=03 ! MSG TYPE 005-041 JMA SATWIND, GMS/MTSAT IR CHANNEL 
      sattab(042,hima(i),2,1)=242; sattab(042,hima(i),2,2)=03 ! MSG TYPE 005-042 JMA SATWIND, GMS/MTSAT VIS CHANNEL 
      sattab(043,hima(i),3,1)=250; sattab(043,hima(i),3,2)=03 ! MSG TYPE 005-043 JMA SATWIND, GMS/MTSAT WV-IMG CHANNEL 
      sattab(043,hima(i),4,1)=250; sattab(043,hima(i),4,2)=03 ! MSG TYPE 005-043 JMA SATWIND, GMS/MTSAT WV-IMG CHANNEL 
      sattab(043,hima(i),5,1)=250; sattab(043,hima(i),5,2)=03 ! MSG TYPE 005-043 JMA SATWIND, GMS/MTSAT WV-IMG CHANNEL 
      sattab(044,hima(i),1,1)=252; sattab(044,hima(i),1,2)=04 ! MSG TYPE 005-044 JMA SATWIND, HIMAWARI IR CHANNEL (BUFR 
      sattab(045,hima(i),2,1)=242; sattab(045,hima(i),2,2)=04 ! MSG TYPE 005-045 JMA SATWIND, HIMAWARI VIS CHANNEL(BUFR 
      sattab(046,hima(i),3,1)=250; sattab(046,hima(i),3,2)=04 ! MSG TYPE 005-046 JMA SATWIND, HIMAWARI WV-IMG CHN (BUFR 
      sattab(046,hima(i),4,1)=250; sattab(046,hima(i),4,2)=04 ! MSG TYPE 005-046 JMA SATWIND, HIMAWARI WV-IMG CHN (BUFR 
      sattab(046,hima(i),5,1)=250; sattab(046,hima(i),5,2)=04 ! MSG TYPE 005-046 JMA SATWIND, HIMAWARI WV-IMG CHN (BUFR 
      sattab(047,hima(i),1,1)=253; sattab(047,hima(i),1,2)=05 ! MSG TYPE 005-047 JMA SATWIND, HIMAWARI IR (BUFR 310077) 
      sattab(048,hima(i),2,1)=242; sattab(048,hima(i),2,2)=05 ! MSG TYPE 005-048 JMA SATWIND, HIMAWARI VIS (BUFR 310077 
      sattab(049,hima(i),3,1)=250; sattab(049,hima(i),3,2)=05 ! MSG TYPE 005-049 JMA SATWIND, HIMAWARI WV (BUFR 310077) 
      sattab(049,hima(i),4,1)=250; sattab(049,hima(i),4,2)=05 ! MSG TYPE 005-049 JMA SATWIND, HIMAWARI WV (BUFR 310077) 
      sattab(049,hima(i),5,1)=250; sattab(049,hima(i),5,2)=05 ! MSG TYPE 005-049 JMA SATWIND, HIMAWARI WV (BUFR 310077) 
      enddo


      do i=1,20; if(goes(i)==0) cycle
      sattab(052,goes(i),1,1)=245; sattab(052,goes(i),1,2)=15 ! MSG TYPE 005-052 NESDIS SATWIND, GOES-16 IR(LW) (BUFR 
      sattab(053,goes(i),4,1)=247; sattab(053,goes(i),4,2)=19 ! MSG TYPE 005-053 NESDIS SATWIND, GOES-16 WV-IMG/DL(BUFR 
      sattab(054,goes(i),2,1)=251; sattab(054,goes(i),2,2)=17 ! MSG TYPE 005-054 NESDIS SATWIND, GOES-16 VIS (BUFR 
      sattab(055,goes(i),3,1)=246; sattab(055,goes(i),3,2)=18 ! MSG TYPE 005-055 NESDIS SATWIND, GOES-16 WV-IMG/CT(BUFR 
      sattab(056,goes(i),1,1)=240; sattab(056,goes(i),1,2)=16 ! MSG TYPE 005-056 NESDIS SATWIND, GOES-16 IR(SW) (BUFR 
      enddo

      do i=1,20; if(meto(i)==0) cycle
      sattab(061,meto(i),1,1)=253; sattab(061,meto(i),1,2)=00 ! MSG TYPE 005-061 EUMETSAT SATWIND, METEOSAT IR CHAN 
      sattab(062,meto(i),2,1)=243; sattab(062,meto(i),2,2)=00 ! MSG TYPE 005-062 EUMETSAT SATWIND, METEOSAT VIS CHAN 
      sattab(063,meto(i),3,1)=254; sattab(063,meto(i),3,2)=00 ! MSG TYPE 005-063 EUMETSAT SATWIND, METEOSAT WV-IMG CHN 
      sattab(063,meto(i),4,1)=254; sattab(063,meto(i),4,2)=00 ! MSG TYPE 005-063 EUMETSAT SATWIND, METEOSAT WV-IMG CHN 
      sattab(063,meto(i),5,1)=254; sattab(063,meto(i),5,2)=00 ! MSG TYPE 005-063 EUMETSAT SATWIND, METEOSAT WV-IMG CHN 
      sattab(064,meto(i),1,1)=253; sattab(064,meto(i),1,2)=01 ! MSG TYPE 005-064 EUMETSAT SATWIND, METEOSAT IR CHN (BUF 
      sattab(065,meto(i),2,1)=243; sattab(065,meto(i),2,2)=01 ! MSG TYPE 005-065 EUMETSAT SATWIND, METEOSAT VIS CHN(BUF 
      sattab(066,meto(i),3,1)=254; sattab(066,meto(i),3,2)=01 ! MSG TYPE 005-066 EUMETSAT SATWIND, METEOSAT WV CHN (BUF 
      sattab(066,meto(i),4,1)=254; sattab(066,meto(i),4,2)=01 ! MSG TYPE 005-066 EUMETSAT SATWIND, METEOSAT WV CHN (BUF 
      sattab(066,meto(i),5,1)=254; sattab(066,meto(i),5,2)=01 ! MSG TYPE 005-066 EUMETSAT SATWIND, METEOSAT WV CHN (BUF 
      sattab(067,meto(i),1,1)=253; sattab(067,meto(i),1,2)=02 ! MSG TYPE 005-067 EUMETSAT SATWIND, MTSAT IR (BUFR 31007 
      sattab(068,meto(i),2,1)=243; sattab(068,meto(i),2,2)=02 ! MSG TYPE 005-068 EUMETSAT SATWIND, MTSAT VIS(BUFR 31007 
      sattab(069,meto(i),3,1)=254; sattab(069,meto(i),3,2)=02 ! MSG TYPE 005-069 EUMETSAT SATWIND, MTSAT WV (BUFR 31007 
      sattab(069,meto(i),4,1)=254; sattab(069,meto(i),4,2)=02 ! MSG TYPE 005-069 EUMETSAT SATWIND, MTSAT WV (BUFR 31007 
      sattab(069,meto(i),5,1)=254; sattab(069,meto(i),5,2)=02 ! MSG TYPE 005-069 EUMETSAT SATWIND, MTSAT WV (BUFR 31007 
      enddo

      do i=1,20; if(modi(i)==0) cycle
      sattab(070,modi(i),1,1)=257; sattab(070,modi(i),1,2)=08 ! MSG TYPE 005-070 MODIS SATWIND, AQUA/TERRA IR(LW) CHN 
      sattab(071,modi(i),3,1)=258; sattab(071,modi(i),3,2)=08 ! MSG TYPE 005-071 MODIS SATWIND, AQUA/TERRA WV-IMG CHANN 
      sattab(071,modi(i),4,1)=259; sattab(071,modi(i),4,2)=08 ! MSG TYPE 005-071 MODIS SATWIND, AQUA/TERRA WV-IMG CHANN 
      sattab(071,modi(i),5,1)=259; sattab(071,modi(i),5,2)=08 ! MSG TYPE 005-071 MODIS SATWIND, AQUA/TERRA WV-IMG CHANN 
      enddo

      do i=1,20; if(lege(i)==0) cycle
      sattab(072,lege(i),1,1)=255; sattab(072,lege(i),1,2)=12 ! MSG TYPE 005-072 SSEC/WISC LEO-GEO WINDS 
      enddo

      do i=1,20; if(avhr(i)==0) cycle
      sattab(080,avhr(i),1,1)=244; sattab(080,avhr(i),1,2)=09 ! MSG TYPE 005-080 AVHRR SATWIND, NOAA/METOP IR(LW) CHN 
      sattab(081,avhr(i),1,1)=244; sattab(081,avhr(i),1,2)=10 ! MSG TYPE 005-081 AVHRR SATWIND, NOAA/METOP IR(LW) CHN 
      enddo

      do i=1,20; if(viir(i)==0) cycle
      sattab(090,viir(i),1,1)=260; sattab(090,viir(i),1,2)=13 ! MSG TYPE 005-090 VIIRS SATWIND, NPP IR(LW) CHANNEL 
      sattab(091,viir(i),1,1)=260; sattab(091,viir(i),1,2)=14 ! MSG TYPE 005-091 VIIRS SATWIND, NPP IR(LW) CHANNEL 
      enddo

      do i=1,20
      if(goes(i)/=0) sattab(099,goes(i),1,1)=241; sattab(099,goes(i),1,2)=20 ! MSG TYPE 005-099 CIMSS AMV TROPICAL CYCLONE WINDS 
      if(hima(i)/=0) sattab(099,hima(i),1,1)=241; sattab(099,hima(i),1,2)=20 ! MSG TYPE 005-099 CIMSS AMV TROPICAL CYCLONE WINDS 
      if(meto(i)/=0) sattab(099,meto(i),1,1)=241; sattab(099,meto(i),1,2)=20 ! MSG TYPE 005-099 CIMSS AMV TROPICAL CYCLONE WINDS 
      if(viir(i)/=0) sattab(099,viir(i),1,1)=241; sattab(099,viir(i),1,2)=20 ! MSG TYPE 005-099 CIMSS AMV TROPICAL CYCLONE WINDS 
      enddo

      end subroutine
