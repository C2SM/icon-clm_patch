# icon-clm_patch

This repo contains a patch for the ICON release-2024.07. The patch includes missing GPU ports for the official ICON-CLM namelist setup.

- GPU port of `irad_aero = 18` (transient aerosol datasets)
- GPU port of `irad_o3 = 5` (transient ozone climatology)
- GPU port of `icpl_aero_gscp = 3` (MODIS climatology for cloud-droplet number)
- GPU port of HPBL output diagnostic
