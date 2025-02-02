# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION ${CMAKE_VERSION}) # this file comes with cmake

# If CMAKE_DISABLE_SOURCE_CHANGES is set to true and the source directory is an
# existing directory in our source tree, calling file(MAKE_DIRECTORY) on it
# would cause a fatal error, even though it would be a no-op.
if(NOT EXISTS "/Users/macncheese/Desktop/University_24/Second/Microprocessors/pico-apps/pico-sdk/tools/pioasm")
  file(MAKE_DIRECTORY "/Users/macncheese/Desktop/University_24/Second/Microprocessors/pico-apps/pico-sdk/tools/pioasm")
endif()
file(MAKE_DIRECTORY
  "/Users/macncheese/Desktop/University_24/Second/Microprocessors/pico-apps/pioasm"
  "/Users/macncheese/Desktop/University_24/Second/Microprocessors/pico-apps/examples/ws2812_rgb/pioasm"
  "/Users/macncheese/Desktop/University_24/Second/Microprocessors/pico-apps/examples/ws2812_rgb/pioasm/tmp"
  "/Users/macncheese/Desktop/University_24/Second/Microprocessors/pico-apps/examples/ws2812_rgb/pioasm/src/PioasmBuild-stamp"
  "/Users/macncheese/Desktop/University_24/Second/Microprocessors/pico-apps/examples/ws2812_rgb/pioasm/src"
  "/Users/macncheese/Desktop/University_24/Second/Microprocessors/pico-apps/examples/ws2812_rgb/pioasm/src/PioasmBuild-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/Users/macncheese/Desktop/University_24/Second/Microprocessors/pico-apps/examples/ws2812_rgb/pioasm/src/PioasmBuild-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/Users/macncheese/Desktop/University_24/Second/Microprocessors/pico-apps/examples/ws2812_rgb/pioasm/src/PioasmBuild-stamp${cfgdir}") # cfgdir has leading slash
endif()
