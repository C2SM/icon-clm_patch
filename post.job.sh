#!/usr/bin/env bash
# ICON-CLM Starter Package (SPICE_v2.3)
#
# ---------------------------------------------------------------
# Copyright (C) 2009-2025, Helmholtz-Zentrum Hereon
# Contact information: https://www.clm-community.eu/
#
# See AUTHORS.TXT for a list of authors
# See LICENSES/ for license information
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPICE docs: https://hereon-coast.atlassian.net/wiki/spaces/SPICE/overview
# ---------------------------------------------------------------
set -e
# ============================================================================

############################################################
# Post-processing ICON data
# Trang Van Pham, DWD 20.03.2018 initial version adapted from COSMO-CLM post-processing script (Burkhardt Rockel, Hereon)
# Burkhardt Rockel, Hereon, 2020, included in SPICE (Starter Package for ICON Experiments)
############################################################

#################################################
#  Pre-Settings
#################################################

#... get the job_settings environment variables
source ${PFDIR}/${EXPID}/job_settings

# load the necessary modules
module load cdo/${CDO_VERSION}
module load nco/${NCO_VERSION}

  INPDIR=${SCRATCHDIR}/${EXPID}/input/post
  OUTDIR=${WORKDIR}/${EXPID}/post
  if [[ ${#CURRENT_DATE} -eq 10 ]]
  then
    NEXT_DATE=$(${CFU} get_next_dates ${CURRENT_DATE} 01:00:00 ${ITYPE_CALENDAR} | cut -c1-10)
  else
    NEXT_DATE=$(${CFU} get_next_dates ${CURRENT_DATE} 01:00:00 ${ITYPE_CALENDAR} | cut -c1-14)
  fi
  PREV_DATE=$(${CFU} get_prev_date  ${CURRENT_DATE} 01:00:00 ${ITYPE_CALENDAR} | cut -c1-10)

  YYYY=${CURRENT_DATE:0:4}
  MM=${CURRENT_DATE:4:2}
  YYYY_MM=${YYYY}_${MM}
  YDATE_NEXT=${NEXT_DATE}
  YYYY_NEXT=${NEXT_DATE:0:4}
  MM_NEXT=${NEXT_DATE:4:2}
  YYYY_PREV=${PREV_DATE:0:4}
  MM_PREV=${PREV_DATE:4:2}

  ISO_NEXT_DATE=${NEXT_DATE:0:8}T${NEXT_DATE:8:2}0000Z

#... set maximum number of parallel processes
(( MAXPP=TASKS_POST ))

#################################################
#  Main part
#################################################

echo "post      ${YYYY_MM} START    $(date)" >> ${PFDIR}/${EXPID}/chain_status.log
echo START ${YYYY} ${MM}  >> ${WORKDIR}/${EXPID}/joblogs/post/finish_joblist
DATE_START=$(date +%s)
ERROR_delete=0 # error flag for deletion of output in ${SCRATCHDIR}

#... load the functions to calculate timeseries and additional parameters
export CURRENT_DATE
export INPDIR
export OUTDIR
export YYYY_MM
source ${PFDIR}/${EXPID}/scripts/functions.inc

# post processing for ICON
#
#################################################
# post processing the data (e.g. daily, monthly means, creating time series etc.)
#################################################

##################################################################################################
# build time series
##################################################################################################

if [[ ${ITYPE_TS} -ne 0 ]] # if no time series are required skip a lot
then

if [[ ${ONLY_YEARLY} -eq 0 ]]  # if ONLY_YEARLY=1 no calculation of time series are needed
then
#set -xv
#... create some files and directories (needed to be done just once at the beginning of the simulation)
if [[ ${CURRENT_DATE} -eq ${YDATE_START} ]]
then
  #... save the constant file
  if [[ ! -f ${OUTDIR}/icon_c.nc ]]
  then
    cp ${INPDIR}/icon_${YDATE_START:0:8}T${YDATE_START:8:2}0000Zc.nc ${OUTDIR}/icon_c.nc
    rm ${INPDIR}/icon_${YDATE_START:0:8}T${YDATE_START:8:2}0000Zc.nc
      ${NCO_BINDIR}/ncks -h -v clon,clat,clon_bnds,clat_bnds ${OUTDIR}/icon_c.nc ${OUTDIR}/icon_grid.nc
      ${NCO_BINDIR}/ncatted -h -a ,global,d,, ${OUTDIR}/icon_grid.nc
  fi
  if [[ ! -f ${OUTDIR}/icon_c.nc ]]
  then
    echo ERROR, file not exists: ${OUTDIR}/icon_c.nc
    DATE_END=$(date +%s)
    SEC_TOTAL=$(${PYTHON} -c "print(${DATE_END}-${DATE_START})")
    echo "post      ${YYYY_MM} FAILED   $(date) --- ${SEC_TOTAL}s" >> ${PFDIR}/${EXPID}/chain_status.log
    exit
  fi
  set +u
  iconcor 0 00:00:00 ${OUTDIR}/icon_c.nc
  set -u

  if [[ ${CURRENT_DATE} -eq ${YDATE_START} ]]
  then
    #... Field capacity, pore volume and wilting point is written to the constant file
    set +u
    timeseries FIELDCAP
    set -u
  fi

  #weights with source mask by using usual icon output
  ${CDO} -P ${OMP_THREADS_POST} gennn,${TARGET_GRID} ${OUTDIR}/icon_c.nc ${OUTDIR}/remapnn_weights.nc

  ${CDO} -s -P ${OMP_THREADS_POST} remap,${TARGET_GRID},${OUTDIR}/remapnn_weights.nc ${OUTDIR}/icon_c.nc ${OUTDIR}/${EXPID}_c.nc
  ${CDO} -s setmissval,-1.E20 ${OUTDIR}/${EXPID}_c.nc tmp.nc
  mv tmp.nc ${OUTDIR}/${EXPID}_c.nc

  if [[ ${ITYPE_TS} -eq 2 ]] || [[ ${ITYPE_TS} -eq 3 ]]    # in case of yearly time series
  then
    [[ -d ${OUTDIR}/yearly/HSURF ]] || mkdir -p  ${OUTDIR}/yearly/HSURF
    if [ ! -f ${OUTDIR}/yearly/HSURF/HSURF.nc ]
    then
      ${NCO_BINDIR}/ncks -h -v HSURF ${OUTDIR}/${EXPID}_c.nc ${OUTDIR}/yearly/HSURF/HSURF.nc
    fi
    [[ -d ${OUTDIR}/yearly/FR_LAND ]] || mkdir -p  ${OUTDIR}/yearly/FR_LAND
    if [ ! -f ${OUTDIR}/yearly/FR_LAND/FR_LAND.nc ]
    then
      ${NCO_BINDIR}/ncks -h -v FR_LAND ${OUTDIR}/${EXPID}_c.nc ${OUTDIR}/yearly/FR_LAND/FR_LAND.nc
    fi
  fi
fi
####
##For repairment-runs: in case the data are coming from archieved tar-file they have to be unzipped
####
cd ${INPDIR}/${YYYY_MM}/
if [ -n "$(ls -A  */icon_*.ncz 2>/dev/null)" ]
then
  export COUNTPP=0
  echo  ${INPDIR}/${YYYY_MM}/ contains ncz-files which have to be unzipped befores timeseries can be build
  for file in */icon_*.ncz ; do
    ofile=${file%ncz}nc
    nccopy -6 $file $ofile &
    (( COUNTPP=COUNTPP+1 ))
    if [[ ${COUNTPP} -ge ${MAXPP} ]]
    then
      COUNTPP=0
      wait
    fi
    wait
  done
  echo unzipping of ncz-files in ${INPDIR}/${YYYY_MM}/ done
  rm ${INPDIR}/${YYYY_MM}/*/*ncz
fi

if [[ ! -d ${OUTDIR}/${YYYY_MM} ]]
then
  mkdir ${OUTDIR}/${YYYY_MM}
fi
cd ${OUTDIR}/${YYYY_MM}

#... time series part 1
echo time series part 1  --- build time series for selected variables
# --- build time series for selected variables

ts_command_list=(
'timeseries RAIN_CON  out03 remapnn' #accumulated convective surface rain [kg/m2]
'timeseries SNOW_CON  out03 remapnn' #accumulated convective surface snow [kg/m2]
'timeseries RAIN_GSP  out03 remapnn' #accumulated grid scale surface rain [kg/m2]
'timeseries SNOW_GSP  out03 remapnn' #accumulated grid scale surface snow [kg/m2]
'timeseries TOT_PREC  out03 remapnn' #total precicitation [kg/m2]
#
'timeseries AEVAP_S   out08 remapnn'
'timeseries ALHFL_S   out08 remapnn' #latent heat flux (surface) [W/m2]
'timeseries ASHFL_S   out08 remapnn' #sensible heat flux (surface) [W/m2]
#'timeseries ATHD_S    out08 remapnn'
'timeseries ATHU_S    out08 remapnn' #
'timeseries ASOB_S    out08 remapnn' #
'timeseries ASOB_T    out08 remapnn'
'timeseries ASOD_T    out08 remapnn'
'timeseries ASODIFD_S out08 remapnn'
'timeseries ASODIFU_S out08 remapnn'
'timeseries ATHB_S    out08 remapnn'
'timeseries ATHB_T    out08 remapnn'
#'timeseries ASODIRD_S  out08 remapnn'
#'timeseries ALB_RAD   out08 remapnn'
'timeseries AUMFL_S   out08 remapnn' #u-momentum flux at the surface [N/m2]
'timeseries AVMFL_S   out08 remapnn' #v-momentum flux at the surface [N/m2]
#
'timeseries CLCT      out03 remapnn'
'timeseries CLCT_MOD  out03 remapnn' #	modified total cloud cover
'timeseries SPGUST_10M  out03 remapnn'
'timeseries SP_10M    out03 remapnn' # 10m wind speed
#timeseries HPBL      out03 remapnn  #boundary layer height above sea level [m]
'timeseries PMSL      out03 remapnn' #mean sea level pressure [Pa]
'timeseries PS        out03 remapnn' #surface pressure [Pa]
'timeseries QV_2M     out03 remapnn' #specific water vapor content in 2m [kg/kg]
'timeseries T_2M      out03 remapnn'
'timeseries TD_2M     out03 remapnn'
'timeseries U_10M     out03 remapnn'
'timeseries V_10M     out03 remapnn'
'timeseries RELHUM_2M out03 remapnn'
'timeseries RUNOFF_S  out03 remapnn' #surface water runoff; sum over forecast [kg/m2]
'timeseries RUNOFF_G  out03 remapnn' #ground water runoff; sum over forecast [kg/m2]
'timeseries SNOW_MELT out03 remapnn' #snow melt [kg/m2]
#
'timeseries CAPE_ML   out05 remapnn'
'timeseries CAPE_CON  out05 remapnn'
'timeseries H_SNOW    out05 remapnn'
'timeseries TQC       out05 remapnn'
'timeseries TQI       out05 remapnn'
'timeseries TQR       out05 remapnn'
'timeseries TQS       out05 remapnn'
'timeseries TQV       out05 remapnn' #column integrated water vapour [kg m-2]
#
'timeseries W_I       out02 remapnn'
'timeseries T_SO      out02 remapnn'
'timeseries W_SO      out02 remapnn'
'timeseries W_SO_ICE  out02 remapnn'
'timeseries T_S       out02 remapnn'
'timeseries T_G       out02 remapnn'
'timeseries W_SNOW    out02 remapnn' #water content of snow [m H2O]

'timeseries TMAX_2M   out04 remapnn'
'timeseries TMIN_2M   out04 remapnn'
'timeseries DURSUN    out04 remapnn' # sunshine duration [s]
'timeseries LAI       out04 remapnn'
'timeseries PLCOV     out04 remapnn'
'timeseries ROOTDP    out04 remapnn'

'timeseries SODIFD_S  out09 remapnn'
'timeseries SOBS_RAD  out09 remapnn'
'timeseries SODIFU_S  out09 remapnn'
'timeseries THBS_RAD  out09 remapnn'
)

NUMFILES=${#ts_command_list[@]}

set +u
export COUNTPP=0
for ts_command in "${ts_command_list[@]}"
do
  ${ts_command} &
  (( COUNTPP=COUNTPP+1 ))
  if [[ ${COUNTPP} -ge ${MAXPP} ]]
  then
    COUNTPP=0
    wait
  fi
done
wait

#... time series part 2
echo time series part 2 --- building a time series for a given quantity on pressure- and z-levels
#... building a time series for a given quantity on pressure- and z-levels

ts_command_list=(
'timeseriesp OMEGA    out06 PLEVS[@] remapnn'
'timeseriesp T        out06 PLEVS[@] remapnn'
'timeseriesp U        out06 PLEVS[@] remapnn'
'timeseriesp V        out06 PLEVS[@] remapnn'
'timeseriesp FI       out06 PLEVS[@] remapnn'
'timeseriesp QV       out06 PLEVS[@] remapnn'
'timeseriesp RELHUM   out06 PLEVS[@] remapnn'
'timeseriesz T        out07 ZLEVS[@] remapnn'
'timeseriesz U        out07 ZLEVS[@] remapnn'
'timeseriesz V        out07 ZLEVS[@] remapnn'
'timeseriesz RELHUM   out07 ZLEVS[@] remapnn'
'timeseriesz QV       out07 ZLEVS[@] remapnn'
'timeseriesz P        out07 ZLEVS[@] remapnn'
'timeseriesz T        out10 HLEVS[@] remapnn'
'timeseriesz U        out10 HLEVS[@] remapnn'
'timeseriesz V        out10 HLEVS[@] remapnn'
'timeseriesz RELHUM   out10 HLEVS[@] remapnn'
'timeseriesz QV       out10 HLEVS[@] remapnn'
'timeseriesz P        out10 HLEVS[@] remapnn'
)

#... counting number of files to be created
for ts_command in "${ts_command_list[@]}"
do
  if ($(grep -q 'PLEVS' <<< ${ts_command}))
  then
    NUMFILES=$((${NUMFILES} + ${#PLEVS[@]}))
  elif ($(grep -q 'ZLEVS' <<< ${ts_command}))
  then
    NUMFILES=$((${NUMFILES} + ${#ZLEVS[@]}))
  elif ($(grep -q 'HLEVS' <<< ${ts_command}))
  then
    NUMFILES=$((${NUMFILES} + ${#HLEVS[@]}))
  fi
done

COUNTPP=0
for ts_command in "${ts_command_list[@]}"
do
  ${ts_command} &
  (( COUNTPP=COUNTPP+1 ))
  if [[ ${COUNTPP} -ge ${MAXPP} ]]
  then
    COUNTPP=0
    wait
  fi
done
wait

#... time series part 3
echo time series part 3 --- building additional time series for a given quantities on pressure- and z-levels
#... building additional time series for a given quantities on pressure- and z-levels
#...   these quantities are based on the time series in part 2
ts_command_list=(
'timeseriesap SP            PLEVS[@] '
'timeseriesap DD            PLEVS[@] '
'timeseriesaz SP            ZLEVS[@]  NN '
'timeseriesaz DD            ZLEVS[@]  NN '
'timeseriesaz SP            HLEVS[@] '
'timeseriesaz DD            HLEVS[@] '
)

#... counting number of files to be created
for ts_command in "${ts_command_list[@]}"
do
  if ($(grep -q 'PLEVS' <<< ${ts_command}))
  then
    NUMFILES=$((${NUMFILES} + ${#PLEVS[@]}))
  elif ($(grep -q 'ZLEVS' <<< ${ts_command}))
  then
    NUMFILES=$((${NUMFILES} + ${#ZLEVS[@]}))
  elif ($(grep -q 'HLEVS' <<< ${ts_command}))
  then
    NUMFILES=$((${NUMFILES} + ${#HLEVS[@]}))
  fi
done

COUNTPP=0
for ts_command in "${ts_command_list[@]}"
do
  ${ts_command} &
  (( COUNTPP=COUNTPP+1 ))
  if [[ ${COUNTPP} -ge ${MAXPP} ]]
  then
    COUNTPP=0
    wait
  fi
done
wait

#... time series part 4
echo time series part 4 --- building additional quantities calculated from the quantities in part 1
#... !!! any additional quantities calculated from the quantities in part 1
#... should be included here !!!
#... one has to split the list in two parts, if in case of parallel computation
#...    variables depend on other additional variables (e.g. ASOD_S depends on ASODIRD_S)

ts_command_list=(
'timeseries RUNOFF_S_corr'    # runoff_s correction for lake shores; arguments are outputintervals of RUNOFF_S, TOT_PREC, and AEVAP_S
'timeseries ASODIRD_S'
'timeseries ASOD_S'
'timeseries ASOU_T'
'timeseries ATHD_S'
'timeseries DD_10M'
'timeseries DTR_2M'
'timeseries FR_SNOW'
'timeseries PVAP_2M'
'timeseries PREC_CON'
'timeseries TOT_SNOW'
'timeseries TQW'
)
num_double_entries=1     # number of corrected quantities, which therefore occur twice in the ts_command_list

NUMFILES=$((${NUMFILES} + ${#ts_command_list[@]}- $num_double_entries))

export COUNTPP=0
for ts_command in "${ts_command_list[@]}"
do
  ${ts_command} &
  (( COUNTPP=COUNTPP+1 ))
  if [[ ${COUNTPP} -ge ${MAXPP} ]]
  then
    COUNTPP=0
    wait
  fi
done
wait
#... time series part 5
echo time series part 5 --- building additional quantities calculated from the quantities in part 1
#... !!! any additional quantities calculated from the quantities in part 4
#... should be included here !!!
#... one has to split the list in two parts, if in case of parallel computation
#...    variables depend on other additional variables (e.g. ASOD_S depends on ASODIRD_S)

ts_command_list=(
'timeseries RUNOFF_T'    # runoff_s + runoff_g
)

NUMFILES=$((${NUMFILES} + ${#ts_command_list[@]}))
export COUNTPP=0
for ts_command in "${ts_command_list[@]}"
do
  ${ts_command} &
  (( COUNTPP=COUNTPP+1 ))
  if [[ ${COUNTPP} -ge ${MAXPP} ]]
  then
    COUNTPP=0
    wait
  fi
done
wait
set -u

###############################################
# remove the icon output for YYYY_MM from the SCRATCH directory
# Safety check whether *tmp files exist. In that case something
#   may have gone wrong and the directory is not deleted in order
#   to run " subchain post YYYYMMDD00" again interactively
###############################################

echo ... checking the number of files in ${WORKDIR}/${EXPID}/post/${YYYY_MM} - ${NUMFILES} files are expected
if [[ $(ls -1 ${WORKDIR}/${EXPID}/post/${YYYY_MM} | wc -l) -ne ${NUMFILES} ]]
then
  echo ... wrong number of files exist: $(ls -1 ${WORKDIR}/${EXPID}/post/${YYYY_MM} | wc -l)
  echo ... ${SCRATCHDIR}/${EXPID}/output/icon/${YYYY_MM} not deleted
  ERROR_delete=1
else
  echo "      OK, all time series files found"
  echo ... checking for corrupted tmp files
  set +e
  ls ${WORKDIR}/${EXPID}/post/${YYYY_MM}/*tmp  2> /dev/null
  ERROR=$?
  set -e
  if [[ ${ERROR} -eq 0 ]]
  then
     echo ... tmp files found in ${WORKDIR}/${EXPID}/post/${YYYY_MM}
     echo ... ${SCRATCHDIR}/${EXPID}/output/icon/${YYYY_MM} not deleted
     ERROR_delete=1
  else
  echo "      OK, no tmp file found"
  echo ... checking if time series are on rotated grid
    ERROR=0
    FILELIST=$(ls -1 ${WORKDIR}/${EXPID}/post/${YYYY_MM}/*)
    for FILE in ${FILELIST}
    do
      if [[ "x$(${NC_BINDIR}/ncdump -h ${FILE} | grep 'rotated')" == "x" ]]
      then
        ERROR=1
        echo ${FILE}
      fi
    done
    if [[ ${ERROR} -eq 1 ]]
    then
      echo ... not all time series files are on rotated grid
      echo ... ${SCRATCHDIR}/${EXPID}/output/icon/${YYYY_MM} not deleted
      ERROR_delete=1
    else
     echo "      OK, all files are on rotated grid"
      if [[ ITYPE_SAMOVAR_TS -eq 1 ]]
      then
        echo ... checking output variables for valid range - the limits are given in ${SAMOVAR_LIST_TS}
        set +e
	FILELIST=$(ls -1 ${WORKDIR}/${EXPID}/post/${YYYY_MM}/*ts.nc | grep -v uncorr) # exclude uncorrected timeseries from samovar check
        ${SAMOVAR_SH} F ${SAMOVAR_LIST_TS} ${WORKDIR}/${EXPID}/joblogs/post/samovar_${YYYY_MM}_ts.log "${FILELIST}"
        ERROR_STATUS=$?
        if [[ $ERROR_STATUS -eq 0 ]]
        then
          echo SAMOVAR check for time series -- OK -- log file ${WORKDIR}/${EXPID}/joblogs/post/samovar_${YYYY_MM}_ts.log deleted
	  rm ${WORKDIR}/${EXPID}/joblogs/post/samovar_${YYYY_MM}_ts.log
        else
          echo SAMOVAR check for time series -- FAILED --
          echo Error in post occured.  > ${PFDIR}/${EXPID}/error_message
          echo Date: ${YYYY} / ${MM} >> ${PFDIR}/${EXPID}/error_message
	  echo Error in checking time series by SAMOVAR >> ${PFDIR}/${EXPID}/error_message
          echo check ${WORKDIR}/${EXPID}/joblogs/post/samovar_${YYYY_MM}_ts.log >> ${PFDIR}/${EXPID}/error_message
          if [ -n "${NOTIFICATION_ADDRESS}" ]
          then
            ${NOTIFICATION_SCRIPT} ${NOTIFICATION_ADDRESS}  "SUBCHAIN ${EXPID} abort due to errors" ${PFDIR}/${EXPID}/error_message
          fi
          DATE2=$(date +%s)
          SEC_TOTAL=$(${PYTHON} -c "print(${DATE2}-${DATE_START})")
          echo "post      ${YYYY_MM} FAILED   $(date) --- ${SEC_TOTAL}s" >> ${PFDIR}/${EXPID}/chain_status.log
          exit 2 # do not comment this line but edit the SAMOVAR limits in ${SAMOVAR_LIST_TS}
        fi
        set -e
      fi
    fi
  fi
fi

fi # ONLY_YEARLY

#################################################
# calculate yearly time series from the monthly ones
#################################################
if [[ ${ITYPE_TS} -eq 2 ]] || [[ ${ITYPE_TS} -eq 3 ]]    # yearly time series
then

  #... check whether a year is completed and perform the yearly time series in that case
  #... ATTENTION: the yearly time series will not work properly for the last simulation year,
  #...               if YDATE_STOP is the 1st of February
  if [[ ${MM#0*} -eq 1 ]] && [[ ${CURRENT_DATE} -ne ${YDATE_START} ]]
  then

    if [[ $(ls -d1 ${SCRATCHDIR}/${EXPID}/output/icon/${YYYY_PREV}* 2> /dev/null | wc -l) -gt 0 ]]
    then
      echo Not all post-processing jobs have run successfully for ${YYYY_PREV}
      echo Please check the following dates and run the \"subchain post YYYYMMDDHH\" manually for these months again
      echo   before re-running the yearly collection for ${YYYY_PREV}
      ls -d1 ${SCRATCHDIR}/${EXPID}/output/icon/${YYYY_PREV}*
      if [[ -n "${NOTIFICATION_ADDRESS}" ]]
      then
        echo Not all post-processing jobs have run successfully for ${YYYY_PREV}> ${PFDIR}/${EXPID}/finish_message
        echo Please check the following dates and run the \"subchain post YYYYMMDDHH\" manually for these months again >> ${PFDIR}/${EXPID}/finish_message
        echo   before re-running the yearly collection for ${YYYY_PREV} >> ${PFDIR}/${EXPID}/finish_message
        ls -d1 ${SCRATCHDIR}/${EXPID}/output/icon/${YYYY_PREV}*  >> ${PFDIR}/${EXPID}/finish_message
        ${NOTIFICATION_SCRIPT} ${NOTIFICATION_ADDRESS}  "ICON-CLM ${EXPID} job finished" ${PFDIR}/${EXPID}/finish_message
      fi
    else
      echo building yearly time series
      source ${PFDIR}/${EXPID}/scripts/post_yearly_cmor.inc
	
      ## check if all yearly files for ${YYYY_PREV} were produced properly
      NFILES=$(ls -1 ${OUTDIR}/${YYYY_PREV}_12 | wc -l)
      if [ ${NFILES} -ne $(ls -1 ${OUTDIR}/yearly/*/*_${YYYY_PREV}* | wc -l) ]
      then
        echo ERROR: Not the same number of yearly files for ${YYYY_PREV} as files in ${YYYY_PREV}_12 are produced.

        if [ -n "${NOTIFICATION_ADDRESS}" ]
        then
          echo Error in post > ${PFDIR}/${EXPID}/error_message
          echo Not all directories of ${OUTDIR}/yearly contain the same number of files for ${YYYY_PREV} as ${OUTDIR}/${YYYY_PREV}_${MM}
          ${NOTIFICATION_SCRIPT} ${NOTIFICATION_ADDRESS}  "SUBCHAIN ${EXPID} abort due to errors in post" ${PFDIR}/${EXPID}/error_message
          rm ${PFDIR}/${EXPID}/error_message
        fi
      else
        echo yearly time series built successfully
        if [[ ${ITYPE_TS} -eq 2 ]]
        then
##          rm -rf ${OUTDIR}/${YYYY_PREV}_??
          rm -rf ${OUTDIR}/${YYYY_PREV}_0[2-9] ${OUTDIR}/${YYYY_PREV}_1[01] # January and december might be needed later on for repair jobs
        fi
      fi
    fi
  elif [[ ${NEXT_DATE} -eq ${YDATE_STOP} ]]
  then

    if [[ $(ls -d1 ${SCRATCHDIR}/${EXPID}/output/icon/${YYYY}_0[1-9]* ${SCRATCHDIR}/${EXPID}/output/icon/${YYYY}_1[01]*  2> /dev/null | wc -l) -gt 0 ]]
    then
      ERROR_delete=1
      echo Not all post-processing jobs have run successfully for ${YYYY}
      echo Please check the following dates and run the \"subchain post YYYYMMDDHH\" manually for these months again
      echo   before re-running the yearly collection for ${YYYY}
      ls -d1 ${SCRATCHDIR}/${EXPID}/output/icon/${YYYY}*
      if [[ -n "${NOTIFICATION_ADDRESS}" ]]
      then
        echo Not all post-processing jobs have run successfully for ${YYYY}> ${PFDIR}/${EXPID}/finish_message
        echo Please check the following dates and run the \"subchain post YYYYMMDDHH\" manually for these months again >> ${PFDIR}/${EXPID}/finish_message
        echo   before re-running the yearly collection for ${YYYY} >> ${PFDIR}/${EXPID}/finish_message
        ls -d1 ${SCRATCHDIR}/${EXPID}/output/icon/${YYYY}*  >> ${PFDIR}/${EXPID}/finish_message
        ${NOTIFICATION_SCRIPT} ${NOTIFICATION_ADDRESS}  "ICON-CLM ${EXPID} job finished" ${PFDIR}/${EXPID}/finish_message
      fi
    else
      echo building yearly time series
      source ${PFDIR}/${EXPID}/scripts/post_yearly_cmor.inc
      ## check if all yearly files were produced properly
      NFILES=$(ls -1 ${OUTDIR}/${YYYY}_${MM} | wc -l)
      if [ ${NFILES} -ne $(ls -1 ${OUTDIR}/yearly/*/*_${YYYY}* | wc -l) ]
      then
        ERROR_delete=1
        echo ERROR: Not all monthly directories of ${YYYY} contain the same number of files
        if [ -n "${NOTIFICATION_ADDRESS}" ]
        then
          echo Error in post > ${PFDIR}/${EXPID}/error_message
          echo Not all directories of ${OUTDIR}/yearly contain the same number of files for ${YYYY} as ${OUTDIR}/${YYYY}_${MM}
          ${NOTIFICATION_SCRIPT} ${NOTIFICATION_ADDRESS}  "SUBCHAIN ${EXPID} abort due to errors in post" ${PFDIR}/${EXPID}/error_message
          rm ${PFDIR}/${EXPID}/error_message
        fi
      else
        echo checking readability of the yearly files
        ERROR_delete=0
        FILELIST=$(ls -1 ${OUTDIR}/yearly/*/*_${YYYY}*)
        for FILE in ${FILELIST}
        do
          [[ ! $(cdo showvar $FILE  2> /dev/null ) ]] &&  ERROR_delete=1
        done
        if [ ERROR_delete=1 ]
        then
          echo ERROR: Not all yearly timeseries of ${YYYY} are readable - you have to redo the process!
          if [ -n "${NOTIFICATION_ADDRESS}" ]
          then
            echo Error in post > ${PFDIR}/${EXPID}/error_message
            echo Not all files in  ${OUTDIR}/yearly for ${YYYY} are readable
            ${NOTIFICATION_SCRIPT} ${NOTIFICATION_ADDRESS}  "SUBCHAIN ${EXPID} abort due to errors in post" ${PFDIR}/${EXPID}/error_message
            rm ${PFDIR}/${EXPID}/error_message
          fi
        else
          echo yearly time series built successfully
          if [[ ${ITYPE_TS} -eq 2 ]]
          then
            rm -rf ${OUTDIR}/${YYYY}_0[2-9] ${OUTDIR}/${YYYY}_1[01] # January and december might be needed later on for repair jobs
            set +e
            DIRNN=$(ls -df ${OUTDIR}/????_0[2-9] ${OUTDIR}/????_1[01] |wc -l) # check whether all yearly files were produced successfully
            set -e
            if [[ $DIRNN -ne 0 ]]
            then
              echo Number of unexpected directories in ${OUTDIR}: $DIRNN - please check the completeness of yearly files.
	            echo These data and the all data from Januaries and Decembers are still available for repair yearly fiels.
              echo Unexpected directories in ${OUTDIR} found > ${PFDIR}/${EXPID}/error_message
              ${NOTIFICATION_SCRIPT} ${NOTIFICATION_ADDRESS}  "SUBCHAIN ${EXPID} found errors in post-yearly" ${PFDIR}/${EXPID}/error_message
              rm ${PFDIR}/${EXPID}/error_message
            else
              rm -rf ${OUTDIR}/????_01 ${OUTDIR}/????_12
            fi
          fi
        fi
      fi
    fi
  fi

  if [[ ${ONLY_YEARLY} -eq 1 ]]  # if ONLY_YEARLY=1 no calculation of time series are needed
  then
    DATE_END=$(date +%s)
    SEC_TOTAL=$(${PYTHON} -c "print(${DATE_END}-${DATE_START})")
    echo total time for postprocessing: ${SEC_TOTAL} s

    echo "post      ${YYYY_MM} FINISHED $(date) --- ${SEC_TOTAL}s" >> ${PFDIR}/${EXPID}/chain_status.log
    exit
  fi

else  # no yearly time series

#################################################
# compress data
#################################################
case ${ITYPE_COMPRESS_POST} in

0)        #... no compression

  echo "**** no compression ****"
  ;;

1)        #... internal netCDF compression

  echo "**** internal netCDF compression"
  cd ${OUTDIR}/${YYYY_MM}

  FORMAT_SUFFIX=ncz
  COUNTPP=0
  FILELIST=$(ls -1)
  for FILE in ${FILELIST}
  do
    (
      ${NC_BINDIR}/nccopy -d 1 -s ${FILE} $(basename ${FILE} .nc).${FORMAT_SUFFIX}
      rm ${FILE}
    )&
    (( COUNTPP=COUNTPP+1 ))
    if [[ ${COUNTPP} -ge ${MAXPP} ]]
    then
      COUNTPP=0
      wait
    fi
  done
  wait
  ;;

2)       #... gzip compression

  echo "**** gzip compression"
  cd ${OUTDIR}/${YYYY_MM}

  COUNTPP=0
  FILELIST=$(ls -1)
  for FILE in ${FILELIST}
  do
    gzip ${FILE} &
    (( COUNTPP=COUNTPP+1 ))
    if [[ ${COUNTPP} -ge ${MAXPP} ]]
    then
      COUNTPP=0
      wait
    fi
  done
  wait
  ;;

3)       #... pigz compression

  echo "**** pigz compression"
  cd ${OUTDIR}/${YYYY_MM}

  FILELIST=$(ls -1)
  for FILE in ${FILELIST}
  do
echo    ${PIGZ} --fast -p ${MAXPP} ${FILE}
    ${PIGZ} --fast -p ${MAXPP} ${FILE}
  done
  ;;

*)

  echo "**** invalid value for  ITYPE_COMPRESS_ARCH: "${ITYPE_COMPRESS_POST}
  echo "**** no compression applied"
  ;;

esac

fi  # end of ITYPE_TS if clause

fi  # end of [[ ITYPE_TS -ne 0 ]] loop
###################
if [[ $ERROR_delete -eq 0 ]] ; then
  echo ... deleting icon output and arch output of current month on scratch
  rm -rf ${SCRATCHDIR}/${EXPID}/output/icon/${YYYY_MM}
  rm -rf ${SCRATCHDIR}/${EXPID}/output/arch/${YYYY_MM}
fi

cd ${OUTDIR}

DATE_END=$(date +%s)
SEC_TOTAL=$(${PYTHON} -c "print(${DATE_END}-${DATE_START})")
echo total time for postprocessing: ${SEC_TOTAL} s

echo "post      ${YYYY_MM} FINISHED $(date) --- ${SEC_TOTAL}s" >> ${PFDIR}/${EXPID}/chain_status.log

cd ${OUTDIR}

echo NEXT_DATE: ${NEXT_DATE}  / YDATE_STOP: ${YDATE_STOP}
### at the end of the model chain clear up the SCRATCH directories
if [[ ${NEXT_DATE} -eq ${YDATE_STOP} ]]
then
  echo ... checking if all post-processing jobs run successfully
  set +e
  if [[ $(ls -1 ${SCRATCHDIR}/${EXPID}/output/icon/[12]???_?? 2> /dev/null | wc -l) -gt 0 ]]
  then
    if [[ -n "${NOTIFICATION_ADDRESS}" ]]
    then
      echo Not all post-processing jobs have run successfully. > ${PFDIR}/${EXPID}/finish_message
      echo Please check the logfiles of the following dates and run the \"subchain post YYYYMMDDHH\" manually for these months again >> ${PFDIR}/${EXPID}/finish_message
      ls -1 ${SCRATCHDIR}/${EXPID}/output/icon |grep \_ >> ${PFDIR}/${EXPID}/finish_message
      ${NOTIFICATION_SCRIPT} ${NOTIFICATION_ADDRESS}  "ICON-CLM ${EXPID} job finished" ${PFDIR}/${EXPID}/finish_message
      DATE_END=$(date +%s)
      SEC_TOTAL=$(${PYTHON} -c "print(${DATE_END}-${DATE_START})")
      echo "post      ${YYYY_MM} FAILED   $(date) --- ${SEC_TOTAL}s" >> ${PFDIR}/${EXPID}/chain_status.log
      exit
    else
      echo Not all post-processing jobs have run successfully
      echo Please check the following dates and run the \"subchain post YYYYMMDDHH\" manually for these months again
      ls -1 ${SCRATCHDIR}/${EXPID}/output/icon
      DATE_END=$(date +%s)
      SEC_TOTAL=$(${PYTHON} -c "print(${DATE_END}-${DATE_START})")
      echo "post      ${YYYY_MM} FAILED   $(date) --- ${SEC_TOTAL}s" >> ${PFDIR}/${EXPID}/chain_status.log
      exit
    fi
  else
    echo ... deleting the whole ${EXPID} directory on scratch
    rm -rf ${SCRATCHDIR}/${EXPID}
  fi
  set -e

  #... calculate total time for the job
  FIRST_LINE=$(head -n 1 ${PFDIR}/${EXPID}/chain_status.log)
  START=${FIRST_LINE:27:30}
  TOTAL_TIME=$(($(date +%s) - $(date -d "${START}" +%s)))
  set +e
  #... find days
#  (( DD = ${TOTAL_TIME} / 86400  ))
  let "DD = TOTAL_TIME / 86400"
  #... find hours
#  (( HH = (${TOTAL_TIME} - ${DD} * 86400) / 3600 ))
  let "HH = (TOTAL_TIME - DD * 86400) / 3600"
  #... find minutes
#  (( MM = (${TOTAL_TIME} - (${DD} * 86400) - (${HH} * 3600)) / 60 ))
  let "MM = (TOTAL_TIME - (DD * 86400) - (HH * 3600)) / 60"
  #... find seconds
#  (( SS = ${TOTAL_TIME} - (${DD} * 86400) - (${HH} * 3600) -(${MM} * 60) ))
  let "SS = $TOTAL_TIME - ($DD * 86400) - ($HH * 3600) -($MM * 60)"
#  echo Total time: ${DD} days -- ${HH} hours -- ${MM} minutes -- ${SS} seconds
  echo "subchain          FINISHED $(date) --- ${DD}d ${HH}h ${MM}m ${SS}s" >> ${PFDIR}/${EXPID}/chain_status.log
  set -e

  ### send notification message that job has been finished
  if [[ -n "${NOTIFICATION_ADDRESS}" ]]
  then
    echo ICON-CLM job ${EXPID} finished `date` > ${PFDIR}/${EXPID}/finish_message
    echo afterburners may still not be finished, e.g. eva-suite or arch-slk > ${PFDIR}/${EXPID}/finish_message
    echo "Total time used for the experiment: ${DD}d ${HH}h ${MM}m ${SS}s" >> ${PFDIR}/${EXPID}/finish_message
    ${NOTIFICATION_SCRIPT} ${NOTIFICATION_ADDRESS}  "ICON-CLM ${EXPID} job finished" ${PFDIR}/${EXPID}/finish_message
    rm ${PFDIR}/${EXPID}/finish_message
  fi
  echo ------------------------------------------
  echo  Job ${EXPID} finished
  echo ------------------------------------------

fi

echo "END  " ${YYYY} ${MM}  >> ${WORKDIR}/${EXPID}/joblogs/post/finish_joblist
