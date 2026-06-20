#!/bin/bash

set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pushd "$HERE" &> /dev/null

if [[ -z "$1" ]] ; then
  echo "Usage: setup.sh x64|arm64"
  exit 1
fi

if [[ `uname -s` == "Linux" ]] ; then
  libasound_status="$(dpkg-query -W -f='${Status}' libasound2-dev 2> /dev/null || true)"
  if [[ "$libasound_status" != "install ok installed" ]] ; then
    echo "Missing required package: libasound2-dev"
    echo "Install it with: sudo apt install libasound2-dev"
    exit 1
  fi
fi

rm -rf tmp lib/3rd_party/portaudio lib/3rd_party/onnxruntime

mkdir -p tmp/portaudio
cd tmp/portaudio
curl -Lo portaudio.tgz http://files.portaudio.com/archives/pa_stable_v190700_20210406.tgz
tar xvf portaudio.tgz

cd portaudio
mkdir dist install
cd dist

portaudio_cmake="cmake -DCMAKE_POLICY_VERSION_MINIMUM=3.5"
if [[ `uname -s` == "MINGW"* ]] ; then
  portaudio_cmake+=" -A x64"
elif [[ `uname -s` == "Darwin" ]] ; then
  portaudio_cmake+=" -DCMAKE_OSX_DEPLOYMENT_TARGET=10.14"
  if [[ "$1" == "x64" ]] ; then
    portaudio_cmake+=" -DCMAKE_OSX_ARCHITECTURES=x86_64"
  elif [[ "$1" == "arm64" ]] ; then
    portaudio_cmake+=" -DCMAKE_OSX_ARCHITECTURES=arm64"
  fi
fi

portaudio_cmake+=" .."
eval $portaudio_cmake
cmake --build . --config Release
cmake --install . --prefix ../install
cp -r ../install ../../../../lib/3rd_party/portaudio

cd ../../..
mkdir onnxruntime
cd onnxruntime

if [[ `uname -s` == "MINGW"* ]] ; then
  mkdir -p ../../lib/3rd_party/onnxruntime/lib
  curl -Lo onnxruntime.zip https://www.nuget.org/api/v2/package/Microsoft.ML.OnnxRuntime/1.10.0
  unzip onnxruntime.zip
  cp -r build/native/include ../../lib/3rd_party/onnxruntime

  path="win-x64"

  cp runtimes/$path/native/*.dll ../../lib/3rd_party/onnxruntime/lib
  cp runtimes/$path/native/*.lib ../../lib/3rd_party/onnxruntime/lib
else
  path="onnxruntime-linux-x64-1.10.0"
  if [[ `uname -s` == "Darwin" ]] ; then
    if [[ "$1" == "x64" ]] ; then
      path="onnxruntime-osx-x86_64-1.10.0"
    elif [[ "$1" == "arm64" ]] ; then
      path="onnxruntime-osx-arm64-1.10.0"
    fi
  fi

  curl -Lo onnxruntime.tgz https://github.com/microsoft/onnxruntime/releases/download/v1.10.0/$path.tgz
  tar xvf onnxruntime.tgz
  cp -r $path ../../lib/3rd_party/onnxruntime
fi

cd ../..
rm -rf tmp
popd &> /dev/null
