# icon-clm_patch

This repo contains a patch for the ICON release-2024.07. The patch includes missing GPU ports for the official ICON-CLM namelist setup.

- [GPU port of `irad_aero = 18` (transient aerosol datasets)](https://gitlab.dkrz.de/icon/icon-nwp/-/commit/2907e622f0aa57f588cdf9ca1e77817744cfb641)
- [GPU port of `irad_o3 = 5` (transient ozone climatology)](https://gitlab.dkrz.de/icon/icon-nwp/-/commit/d2cf99cb78690339a62758db6259c4318adb3af5)
- [GPU port of `icpl_aero_gscp = 3` (MODIS climatology for cloud-droplet number)](https://gitlab.dkrz.de/icon/icon-nwp/-/commit/82bacb0f77789c5c004c22df2327aaddcd36e5ad)
- [GPU port of HPBL output diagnostic](https://gitlab.dkrz.de/icon/icon-nwp/-/commit/395d65d06345c40ff1690997a6160c48fa6b563c)
- [Cleanup in radiation and aerosol code parts](https://gitlab.dkrz.de/icon/icon-nwp/-/commit/1aa9faedeed9eb6fd334dbfe4740220880a5b130)
