export VGREP_ARCHIVE_PATH="/tmp/vgrep/archive";

rm -rf ${VGREP_ARCHIVE_PATH}

CURRENT_DIR=$(pwd)

echo "Building application..."
cd ..
dub build --build=release

./install.sh ${VGREP_ARCHIVE_PATH}/usr

echo "Creating archive"
cd ${VGREP_ARCHIVE_PATH}
zip -r vgrep.zip *

cp vgrep.zip ${CURRENT_DIR}/vgrep.zip
cd ${CURRENT_DIR}
