# Specify the name of the executable.
add_executable(lab06 lab06.c)
target_link_libraries(lab06 pico_stdlib pico_multicore)
pico_add_extra_outputs(lab06)
apps_auto_set_url(lab06)