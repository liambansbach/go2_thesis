cmake_minimum_required(VERSION 3.8)
project(hexlab_go2w_description)

find_package(ament_cmake REQUIRED)

install(
  DIRECTORY xacro meshes launch rviz
  DESTINATION share/${PROJECT_NAME}
)

ament_package()
