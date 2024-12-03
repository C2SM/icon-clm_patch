# icon-clm_patch

This repo contains a patch for the ICON release-2024.07. The patch includes missing GPU ports for the official ICON-CLM namelist setup.

1. [Cleanup in radiation and aerosol code parts](https://gitlab.dkrz.de/icon/icon-nwp/-/commit/1aa9faedeed9eb6fd334dbfe4740220880a5b130)
2. [GPU port of `irad_o3 = 5` (transient ozone climatology)](https://gitlab.dkrz.de/icon/icon-nwp/-/commit/d2cf99cb78690339a62758db6259c4318adb3af5)
3. [GPU port of `irad_aero = 18` (transient aerosol datasets)](https://gitlab.dkrz.de/icon/icon-nwp/-/commit/2907e622f0aa57f588cdf9ca1e77817744cfb641)
4. [GPU port of `icpl_aero_gscp = 3` (MODIS climatology for cloud-droplet number)](https://gitlab.dkrz.de/icon/icon-nwp/-/commit/82bacb0f77789c5c004c22df2327aaddcd36e5ad)
5. [GPU port of HPBL output diagnostic](https://gitlab.dkrz.de/icon/icon-nwp/-/commit/395d65d06345c40ff1690997a6160c48fa6b563c)

## Code to create this patch

```
git clone -b release-2024.07-public git@gitlab.dkrz.de:icon/icon-model.git
cd icon-model
git remote add nwp git@gitlab.dkrz.de:icon/icon-nwp.git
git fetch nwp
git cherry-pick 1aa9faedeed9eb6fd334dbfe4740220880a5b130 -X theirs
git cherry-pick d2cf99cb78690339a62758db6259c4318adb3af5 -X theirs
git cherry-pick 2907e622f0aa57f588cdf9ca1e77817744cfb641 || (git ls-files -u | awk '{print $4}' | xargs -I {} git checkout 2907e622f0 -- {} && git add . && GIT_EDITOR="vim -c ':wq'" git cherry-pick --continue)
git cherry-pick 82bacb0f77789c5c004c22df2327aaddcd36e5ad -X theirs
git cherry-pick 395d65d06345c40ff1690997a6160c48fa6b563c || (git ls-files -u | awk '{print $4}' | xargs -I {} git checkout 395d65d063 -- {} && git add . && GIT_EDITOR="vim -c ':wq'" git cherry-pick --continue)
git reset --soft HEAD~5
git commit -m "GPU patch for ICON-CLM"
git format-patch -1 HEAD --stdout > ../icon-clm_2024.07_gpu.patch
```
