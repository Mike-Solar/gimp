#!/bin/sh

case $(readlink /proc/$$/exe) in
  *bash)
    set -o posix
    ;;
esac
set -e

if [ -z "$GITLAB_CI" ]; then
  # Make the script work locally
  if [ "$0" != 'build/linux/flatpak/2_build-gimp-flatpakbuilder.sh' ] && [ $(basename "$PWD") != 'flatpak' ]; then
    printf '\033[31m(ERROR)\033[0m: Script called from wrong dir. Please, read: https://developer.gimp.org/core/setup/build/linux/\n'
    exit 1
  elif [ $(basename "$PWD") = 'flatpak' ]; then
    cd ../../..
  fi

  git submodule update --init
fi


# Install part of the deps
eval "$(sed -n '/Install part/,/End of check/p' build/linux/flatpak/1_build-deps-flatpakbuilder.sh)"

if [ "$GITLAB_CI" ]; then
  # Extract deps from previous job
  tar xf .flatpak-builder.tar
fi


# Prepare env (only GIMP_PREFIX is needed for flatpak)
if [ -z "$GIMP_PREFIX" ]; then
  export GIMP_PREFIX="$PWD/../_install"
fi


# Build GIMP only
if [ -z "$GITLAB_CI" ]; then
  BUILDER_ARGS='--ccache --state-dir=../.flatpak-builder'
else
  BUILDER_ARGS='--user --disable-rofiles-fuse'
fi

printf "\e[0Ksection_start:`date +%s`:gimp_build[collapsed=true]\r\e[0KBuilding GIMP\n"
eval $FLATPAK_BUILDER --force-clean $BUILDER_ARGS --keep-build-dirs --build-only --disable-download \
                      "$GIMP_PREFIX" build/linux/flatpak/org.gimp.GIMP-nightly.json > gimp-flatpak-builder.log 2>&1 || { cat gimp-flatpak-builder.log; exit 1; }
if [ "$GITLAB_CI" ]; then
  tar cf gimp-meson-log.tar .flatpak-builder/build/gimp-1/_flatpak_build/meson-logs/meson-log.txt
fi
printf "\e[0Ksection_end:`date +%s`:gimp_build\r\e[0K\n"

## Cleanup GIMP_PREFIX (not working) and export it to OSTree repo
## https://github.com/flatpak/flatpak-builder/issues/14
printf "\e[0Ksection_start:`date +%s`:gimp_bundle[collapsed=true]\r\e[0KCreating OSTree repo\n"
eval $FLATPAK_BUILDER $BUILDER_ARGS --finish-only --repo=repo \
                      "$GIMP_PREFIX" build/linux/flatpak/org.gimp.GIMP-nightly.json
if [ "$GITLAB_CI" ]; then
  tar cf repo.tar repo/
fi
printf "\e[0Ksection_end:`date +%s`:gimp_bundle\r\e[0K\n"
