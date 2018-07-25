#!/bin/bash

set -o errexit

pip install gh-pr-comment

source /opt/ros/${ROS_DISTRO}/setup.bash

set -o verbose

cd /catkin_ws

mkdir -p /catkin_ws/build/mcl_3dl/test/
mv /catkin_ws/src/mcl_3dl/.cached-dataset/* /catkin_ws/build/mcl_3dl/test/
ls -lh /catkin_ws/build/mcl_3dl/test/

sed -i -e '5a set(CMAKE_C_FLAGS "-Wall -Werror -O1 -coverage")' \
  /opt/ros/${ROS_DISTRO}/share/catkin/cmake/toplevel.cmake
sed -i -e '5a set(CMAKE_CXX_FLAGS "-Wall -Werror -O1 -coverage")' \
  /opt/ros/${ROS_DISTRO}/share/catkin/cmake/toplevel.cmake

CM_OPTIONS=""
if [ x${ROS_DISTRO} == "xindigo" ]
then
  CM_OPTIONS="${CM_OPTIONS} -DCMAKE_BUILD_TYPE=Release"
  echo "On indigo-trusty, we need release build due to the bug of PCL1.7 with c++11." 1>&2
fi


catkin_make -DMCL_3DL_EXTRA_TESTS=ON ${CM_OPTIONS} || \
  (gh-pr-comment "[#${TRAVIS_BUILD_NUMBER}] FAILED on ${ROS_DISTRO}" '```catkin_make``` failed'; false)
catkin_make tests -DMCL_3DL_EXTRA_TESTS=ON ${CM_OPTIONS} || \
  (gh-pr-comment "[#${TRAVIS_BUILD_NUMBER}] FAILED on ${ROS_DISTRO}" '```catkin_make tests``` failed'; false)
catkin_make run_tests -DMCL_3DL_EXTRA_TESTS=ON ${CM_OPTIONS} || \
  (gh-pr-comment "[#${TRAVIS_BUILD_NUMBER}] FAILED on ${ROS_DISTRO}" '```catkin_make run_tests``` failed'; false)

if [ catkin_test_results ];
then
  result_text="
\`\`\`
`catkin_test_results --all | grep -v Skipping || true`
\`\`\`
"
else
  result_text="
\`\`\`
`catkin_test_results --all | grep -v Skipping || true`
\`\`\`
`find build/test_results/ -name *.xml | xargs -n 1 -- bash -c 'echo; echo \#\#\# $0; echo; echo \\\`\\\`\\\`; xmllint --format $0; echo \\\`\\\`\\\`;'`
"
fi
catkin_test_results || (gh-pr-comment "[#${TRAVIS_BUILD_NUMBER}] FAILED on ${ROS_DISTRO}" "<details><summary>Test failed</summary>

$result_text</details>"; false)

(cd src/mcl_3dl/; cp -r /catkin_ws/build ./; bash <(curl -s https://codecov.io/bash) -y .codecov.yml)

gh-pr-comment "[#${TRAVIS_BUILD_NUMBER}] PASSED on ${ROS_DISTRO}" "<details><summary>All tests passed</summary>

$result_text</details>" || true