set(STM32_CHIP_TYPES 405xx 415xx 407xx 417xx 427xx 437xx 429xx 439xx 446xx 401xC 401xE 411xE CACHE INTERNAL "stm32f4 chip types")
set(STM32_CODES "405.." "415.." "407.." "417.." "427.." "437.." "429.." "439.." "446.." "401.[CB]" "401.[ED]" "411.[CE]")

set(STM32F4_COMPILER_OPTIONS
    -fno-common
    -fmessage-length=0
    -fno-exceptions
    -ffunction-sections
    -fdata-sections
    -Wall
    -mcpu=cortex-m4
    -mthumb
    -mfloat-abi=hard
    -mfpu=fpv4-sp-d16
)

set(STM32F4_COMPILER_DEFINITIONS
    -DSTM32F4
    -DUSE_FULL_LL_DRIVER
)

# --------------------------------------
# Derive the chip type from the full chip name
# --------------------------------------
function(STM32F4_GET_CHIP_TYPE CHIP CHIP_TYPE)
    set(INDEX 0)
    string(REGEX REPLACE "^[sS][tT][mM]32[fF](4[01234][15679].[BCEGI]).*$" "\\1" STM32_CODE ${CHIP})
    
    # Search through the available chip types
    foreach(C_TYPE ${STM32_CHIP_TYPES})
        list(GET STM32_CODES ${INDEX} CHIP_TYPE_REGEXP)

        if(STM32_CODE MATCHES ${CHIP_TYPE_REGEXP})
            set(FOUND_CHIP_TYPE ${C_TYPE})
        endif()

        math(EXPR INDEX "${INDEX}+1")
    endforeach()

    # Quick check to make sure we have a valid value
    if("${FOUND_CHIP_TYPE}" STREQUAL "")
        message(FATAL_ERROR "Invalid/unsupported STM32F4 chip type")
    else()
        set(${CHIP_TYPE} ${FOUND_CHIP_TYPE} PARENT_SCOPE)
    endif()
endfunction()

# --------------------------------------
# Derive a few chip parameters
# --------------------------------------
function(STM32F4_GET_CHIP_PARAMETERS CHIP FLASH_SIZE RAM_SIZE CCRAM_SIZE)
    STRING(REGEX REPLACE "^[sS][tT][mM]32[fF](4[01234][15679].[BCEGI]).*$" "\\1" STM32_CODE ${CHIP})
    STRING(REGEX REPLACE "^[sS][tT][mM]32[fF]4[01234][15679].([BCEGI]).*$" "\\1" STM32_SIZE_CODE ${CHIP})
    
    IF(STM32_SIZE_CODE STREQUAL "B")
        SET(FLASH "128K")
    ELSEIF(STM32_SIZE_CODE STREQUAL "C")
        SET(FLASH "256K")
    ELSEIF(STM32_SIZE_CODE STREQUAL "E")
        SET(FLASH "512K")
    ELSEIF(STM32_SIZE_CODE STREQUAL "G")
        SET(FLASH "1024K")
    ELSEIF(STM32_SIZE_CODE STREQUAL "I")
        SET(FLASH "2048K")
    ENDIF()
    
    STM32F4_GET_CHIP_TYPE(${CHIP} TYPE)
    
    IF(${TYPE} STREQUAL "401xC")
        SET(RAM "64K")
    ELSEIF(${TYPE} STREQUAL "401xE")
        SET(RAM "96K")
    ELSEIF(${TYPE} STREQUAL "411xE")
        SET(RAM "128K")
    ELSEIF(${TYPE} STREQUAL "405xx")
        SET(RAM "128K")
    ELSEIF(${TYPE} STREQUAL "415xx")
        SET(RAM "128K")
    ELSEIF(${TYPE} STREQUAL "407xx")
        SET(RAM "128K")
    ELSEIF(${TYPE} STREQUAL "417xx")
        SET(RAM "128K")
    ELSEIF(${TYPE} STREQUAL "427xx")
        SET(RAM "192K")
    ELSEIF(${TYPE} STREQUAL "437xx")
        SET(RAM "192K")
    ELSEIF(${TYPE} STREQUAL "429xx")
        SET(RAM "192K")
    ELSEIF(${TYPE} STREQUAL "439xx")
        SET(RAM "192K")
    ELSEIF(${TYPE} STREQUAL "446xx")
        SET(RAM "128K")
    ENDIF()
    
    # Assign the parent scope variable with the updated value
    SET(${FLASH_SIZE} ${FLASH} PARENT_SCOPE)
    SET(${RAM_SIZE} ${RAM} PARENT_SCOPE)
    SET(${CCRAM_SIZE} "64K" PARENT_SCOPE)
endfunction()

# --------------------------------------
# Add compiler options to a target
# --------------------------------------
function(STM32F4_SET_TARGET_COMPILE_OPTIONS TARGET)
    target_compile_options(${TARGET} PUBLIC ${STM32F4_COMPILER_OPTIONS})
    target_compile_options(${TARGET} PUBLIC $<$<CONFIG:DEBUG>:-ggdb -Og>)
    target_compile_options(${TARGET} PUBLIC $<$<CONFIG:RELEASE>:-O3>)
    target_compile_options(${TARGET} PRIVATE --std=gnu11)
endfunction()

# --------------------------------------
# Add public compiler definitions to a target
# --------------------------------------
function(STM32F4_SET_TARGET_COMPILE_DEFINITIONS TARGET CHIP)
    # Find the correct chip type so that the HAL knows what device to compile for
    STM32F4_GET_CHIP_TYPE(${CHIP} PROJECT_CHIP_TYPE)

    # Append some new definitions
    set(STM32F4_COMPILER_DEFINITIONS ${STM32F4_COMPILER_DEFINITIONS}
        -DSTM32F${PROJECT_CHIP_TYPE} 

        # Do not add -D flag because these apparently expand AFTER being parsed by target_compile_definitions
        $<$<CONFIG:DEBUG>:DEBUG_DEFAULT_INTERRUPT_HANDLERS>
        $<$<CONFIG:RELEASE>:>
    )

    # Add the definitions to the target
    target_compile_definitions(${TARGET} PUBLIC ${STM32F4_COMPILER_DEFINITIONS})
endfunction()

# --------------------------------------
# Generates a target to build each one of the supported devices in debug and release mode
# --------------------------------------
function(STM32F4_GENERATE_ALL_TARGETS ROOT_DIR SRC_FILES BUILD_INC_DIRS INSTALL_INC_DIRS)
    # Keep track of target names so that the all-* custom target can be generated
    set(RELEASE_TARGETS "")
    set(DEBUG_TARGETS "")

    # --------------------------------------
    # Generate a generalized, debug, and release targets for each supported chip
    # --------------------------------------
    foreach(CHIP_TYPE ${STM32_CHIP_TYPES})
        set(TARGET_CHIP "stm32f${CHIP_TYPE}")
        set(DEBUG_TARGET "${TARGET_CHIP}_${CMAKE_DEBUG_POSTFIX}")
        set(RELEASE_TARGET "${TARGET_CHIP}_${CMAKE_RELEASE_POSTFIX}")
        set(TARGET_EXPORT "FindSTM32F4_HAL")

        # Device specific .c files 
        set(DEV_SRC_FILES 
            "${ROOT_DIR}/Device/sys/system_stm32f4xx.c"
            "${ROOT_DIR}/Device/startup/startup_${TARGET_CHIP}.c"
        )

        # --------------------------------------
        # Add general version of the library and export the target so another project can
        # import it and all its configurations.
        # --------------------------------------
        add_library(${TARGET_CHIP} STATIC ${SRC_FILES} ${DEV_SRC_FILES})
        
        target_include_directories(${TARGET_CHIP} PRIVATE ${BUILD_INC_DIRS})
        target_include_directories(${TARGET_CHIP} INTERFACE
            "$<BUILD_INTERFACE:${BUILD_INC_DIRS}>"
            "$<INSTALL_INTERFACE:${INSTALL_INC_DIRS}>"
        )

        STM32F4_SET_TARGET_COMPILE_OPTIONS(${TARGET_CHIP})
        STM32F4_SET_TARGET_COMPILE_DEFINITIONS(${TARGET_CHIP} ${TARGET_CHIP})

        # --------------------------------------
        # Exports the targets into the TARGET_EXPORT filename. For debug and release builds, CMake
        # will auto generate additional target properties that cause the appropriat static library
        # linkage at build time. See TARGET_EXPORT-debug.cmake in the install directory for examples.
        # --------------------------------------
        install(TARGETS ${TARGET_CHIP} EXPORT ${TARGET_EXPORT}
                DESTINATION ${INSTALL_CMAKE_DIR} 
                INCLUDES DESTINATION "${INSTALL_INC_DIRS}")

        # --------------------------------------
        # Add explicit debug/release targets for local builds (can't be exported)
        # --------------------------------------
        list(APPEND DEBUG_TARGETS "${DEBUG_TARGET}")
        add_custom_target("${DEBUG_TARGET}"
            COMMAND ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=Debug ${CMAKE_SOURCE_DIR}
            COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target ${TARGET_CHIP}
            COMMENT "Creating ${TARGET_CHIP} in debug mode."
        )
        
        list(APPEND RELEASE_TARGETS "${RELEASE_TARGET}")
        add_custom_target("${RELEASE_TARGET}"
            COMMAND ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=Release ${CMAKE_SOURCE_DIR}
            COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target ${TARGET_CHIP}
            COMMENT "Creating ${TARGET_CHIP} in release mode."
        )
    endforeach()

    
    install(EXPORT ${TARGET_EXPORT} DESTINATION ${INSTALL_CMAKE_DIR})
    

    # --------------------------------------
    # Adds two explicit targets that build all the supported debug/release targets locally
    # --------------------------------------
    if(CMAKE_GENERATOR STREQUAL "Unix Makefiles")
        set(BUILD_CMD "make")
    elseif(CMAKE_GENERATOR STREQUAL "MinGW Makefiles")
        set(BUILD_CMD "mingw32-make.exe")
    else()
        message(STATUS "Unsupported generator [${CMAKE_GENERATOR}] for generating all-* targets")
    endif()

    if(BUILD_CMD)
        add_custom_target(all-debug
            COMMAND ${BUILD_CMD} ${DEBUG_TARGETS}
            COMMENT "Building all STM32F4 targets in debug mode."
        )

        add_custom_target(all-release
            COMMAND ${BUILD_CMD} ${RELEASE_TARGETS}
            COMMENT "Building all STM32F4 targets in release mode."
        )
    endif()
    
endfunction()

