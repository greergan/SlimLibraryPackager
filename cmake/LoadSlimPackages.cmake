# ─────────────────────────────────────────────────────────────────────────────
# Parse required_packages
#
# File format (one entry per line):
#   # PackageName [minVersion [maxVersion]]
#
# Lines starting with '#' or that are blank are ignored.
# ─────────────────────────────────────────────────────────────────────────────

find_package(PkgConfig REQUIRED)
message(STATUS "Preparing to load Slim packages")

if(NOT EXISTS "${CMAKE_SOURCE_DIR}/required_packages")
	return()
endif()

file(STRINGS "${CMAKE_SOURCE_DIR}/required_packages" PACKAGE_LINES REGEX "^[^#\n]")
list(LENGTH PACKAGE_LINES number_of_lines)
message(STATUS "Looking for packages -> ${number_of_lines}")
message(STATUS "Looking for packages -> ${PACKAGE_LINES}")

set(FOUND_PACKAGES "")
foreach(line IN LISTS PACKAGE_LINES)
	string(REGEX MATCHALL "[^ \t]+" parts "${line}")
	list(GET parts 0 PKG_NAME_IN)
	string(TOLOWER "${PKG_NAME_IN}" PKG_NAME_LOWER)

	message(STATUS "Looking for package -> ${PKG_NAME_LOWER}")

	list(LENGTH parts part_count)

	if(part_count GREATER_EQUAL 3)
		list(GET parts 1 PKG_MIN)
		list(GET parts 2 PKG_MAX)
		pkg_check_modules(${PKG_NAME_LOWER} REQUIRED ${PKG_NAME_LOWER}>=${PKG_MIN} ${PKG_NAME_LOWER}<=${PKG_MAX})
	elseif(part_count EQUAL 2)
		list(GET parts 1 PKG_MIN)
		pkg_check_modules(${PKG_NAME_LOWER} REQUIRED ${PKG_NAME_LOWER}>=${PKG_MIN})
	else()
		pkg_check_modules(${PKG_NAME_LOWER} REQUIRED ${PKG_NAME_LOWER})
	endif()
	list(APPEND FOUND_PACKAGES ${PKG_NAME_LOWER})
endforeach()

# ${PKG_NAME}_CFLAGS, ${PKG_NAME}_CFLAGS_OTHER, ${PKG_NAME}_INCLUDE_DIRS
# ${PKG_NAME}_LDFLAGS, ${PKG_NAME}_LDFLAGS_OTHER, ${PKG_NAME}_LIBRARY_DIRS

list(LENGTH FOUND_PACKAGES number_of_packages)
message(STATUS "Found packages: ${number_of_packages}")
foreach(pkg IN LISTS FOUND_PACKAGES)
	if(${pkg}_CFLAGS)
    	message(STATUS "Package ${pkg} => CFLAGS: ${${pkg}_CFLAGS}")

		set(input ${${pkg}_CFLAGS})
		string(REGEX MATCHALL "[0-9]+" cxx_standard ${input})
		message(STATUS "Package c++ standard: ${cxx_standard}")
		if(${SLIMLIB_CXX_STANDARD} VERSION_GREATER ${cxx_standard})
			set(${pkg}_CFLAGS "new")
			message(STATUS "Package ${pkg} => CFLAGS: ${${pkg}_CFLAGS}")
			message(STATUS "Package c++ standard: is less than project standard allows ${SLIMLIB_CXX_STANDARD}")
		endif()

	else()
		message(FATAL_ERROR "Package ${pkg} => CFLAGS not found")
	endif()
	if(${pkg}_LDFLAGS)
		message(STATUS "Package ${pkg} => LDFLAGS: ${${pkg}_LDFLAGS}")
	endif()
endforeach()