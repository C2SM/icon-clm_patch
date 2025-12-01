# ICON-CLM GPU Patch

This repo contains a patch for the ICON release-2024.07. The patch includes missing GPU ports for the official ICON-CLM namelist setup.
It consists of two parts:

- `icon-clm_2024.07_2024.patch`
- `icon-clm_2024.07_cdnc.patch`

which are merged to the final patch file `icon-clm_2024.07_gpu.patch`.

To apply the patch, do the following:

```
git clone https://github.com/C2SM/icon-clm_patch.git
git clone https://gitlab.dkrz.de/icon/icon-model/-/tree/release-2024.07-public?ref_type=heads
cd icon-model
git apply ../icon-clm_patch/icon-clm_2024.07_gpu.patch
```

## Recreating this Patch

The code to create the whole patch is the following:

```
git clone -b release-2024.07-public git@gitlab.dkrz.de:icon/icon-model.git
cd icon-model

# Apply 2024 patch
git apply ../icon-clm_2024.07_2024.patch
git add .
git commit -m "GPU patch for ICON-CLM (until end of 2024)"

# Apply custom manual patch
git apply ../icon-clm_2024.07_cdnc.patch
git add .
git commit -m "Custom GPU patch for lscale_cdnc"

# Combine into one final patch 
git reset --soft HEAD~2
git commit -m "GPU patch for ICON-CLM (2024 + lscale_cdnc)"
git format-patch -1 HEAD --stdout > ../icon-clm_2024.07_gpu.patch
```

## 1. Missing ports until the end of 2024

1. [Cleanup in radiation and aerosol code parts](https://gitlab.dkrz.de/icon/icon-nwp/-/commit/1aa9faedeed9eb6fd334dbfe4740220880a5b130)
2. [GPU port of `irad_o3 = 5` (transient ozone climatology)](https://gitlab.dkrz.de/icon/icon-nwp/-/commit/d2cf99cb78690339a62758db6259c4318adb3af5)
3. [GPU port of `irad_aero = 18` (transient aerosol datasets)](https://gitlab.dkrz.de/icon/icon-nwp/-/commit/2907e622f0aa57f588cdf9ca1e77817744cfb641)
4. [GPU port of `icpl_aero_gscp = 3` (MODIS climatology for cloud-droplet number)](https://gitlab.dkrz.de/icon/icon-nwp/-/commit/82bacb0f77789c5c004c22df2327aaddcd36e5ad)
5. [GPU port of HPBL output diagnostic](https://gitlab.dkrz.de/icon/icon-nwp/-/commit/395d65d06345c40ff1690997a6160c48fa6b563c)

### Code to create this patch

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
git format-patch -1 HEAD --stdout > ../icon-clm_2024.07_2024.patch
```

## 2. Port for the CDNC scaling

This port had to be done manually, since the codebase changed. In fact, `lscale_cdnc` 
has been replaced in newer ICON versions. See [MR 1826](https://gitlab.dkrz.de/icon/icon-nwp/-/merge_requests/1826).
