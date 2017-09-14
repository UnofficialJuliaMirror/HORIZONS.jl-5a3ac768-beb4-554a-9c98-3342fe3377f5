# The HORIZONS.jl package is licensed under the MIT "Expat" License:
# Copyright (c) 2017: Jorge Perez.

#The following methods implement some functionality from JPL's Horizons telnet interface
#For more detailed info about JPL HORIZONS system, visit http://ssd.jpl.nasa.gov/?horizons

# The following code is based on the vec_tbl script, as was retrieved from:
# ftp://ssd.jpl.nasa.gov/pub/ssd/SCRIPTS/vec_tbl.inp
# Date retrieved: Jul 19, 2017
# Credit: Jon D. Giorgini, NASA-JPL
# Jon.D.Giorgini@jpl.nasa.gov

"""
    vec_tbl(OBJECT_NAME; kwargs...)

    vec_tbl(OBJECT_NAME, local_file; kwargs...)

Automate the Horizons session required to produce a VECTOR table for an
object already listed in the Horizons database: a planet, natural satellite,
asteroid, comet, spacecraft, or dynamical point. If the file name `local_file`
is specified, then output is saved to that file in current folder. Otherwise,
then output is returned as a Julia string.

Generally, this script is suited for situations where the same output
format (as defined by the input file) is desired for a list of objects
specified one at a time on the script's command-line.

The current keyword arguments are:

    + `timeout=15`
    + `EMAIL_ADDR = "your@domain.name"`
    + `CENTER = "@ssb"`
    + `REF_PLANE = "ECLIP"`
    + `START_TIME = "2000-Jan-1"`
    + `STOP_TIME = "2000-Jan-2"`
    + `STEP_SIZE = "1 d"`
    + `COORD_TYPE = "G"`
    + `SITE_COORD = "0,0,0"`
    + `REF_SYSTEM = "J2000"`
    + `VEC_CORR = "1"`
    + `VEC_DELTA_T = "NO"`
    + `OUT_UNITS = "1"`
    + `CSV_FORMAT = "NO"`
    + `VEC_LABELS = "NO"`
    + `VEC_TABLE= "3"`

More detailed information may be found at the HORIZONS system documentation:

https://ssd.jpl.nasa.gov/?horizons_doc

The original script vec_tbl, written by Jon D. Giorgini, may be found at src/SCRIPTS

"""
function vec_tbl(OBJECT_NAME::String; timeout::Int=15,
        EMAIL_ADDR::String="joe@your.domain.name", CENTER::String="@ssb",
        REF_PLANE::String="ECLIP", START_TIME::String="2000-Jan-1",
        STOP_TIME::String="2000-Jan-2", STEP_SIZE::String="1 d",
        COORD_TYPE::String="G", SITE_COORD::String="0,0,0",
        REF_SYSTEM::String="J2000", VEC_CORR::Int=1,
        VEC_DELTA_T::Bool=false, OUT_UNITS::Int=1,
        CSV_FORMAT::Bool=false, VEC_LABELS::Bool=false,
        VEC_TABLE::Int=3)

    ftp_name = get_vec_tbl(OBJECT_NAME, timeout=timeout,
        EMAIL_ADDR=EMAIL_ADDR, CENTER=CENTER, REF_PLANE=REF_PLANE,
        START_TIME=START_TIME, STOP_TIME=STOP_TIME, STEP_SIZE=STEP_SIZE,
        COORD_TYPE=COORD_TYPE, SITE_COORD=SITE_COORD, REF_SYSTEM=REF_SYSTEM,
        VEC_CORR=VEC_CORR, VEC_DELTA_T=VEC_DELTA_T, OUT_UNITS=OUT_UNITS,
        CSV_FORMAT=CSV_FORMAT, VEC_LABELS=VEC_LABELS, VEC_TABLE=VEC_TABLE)

    # # Retrieve file by anonymous FTP and return output as string
    ftp_init()
    ftp = FTP(hostname=HORIZONS_MACHINE, username="anonymous", password=EMAIL_ADDR)
    cd(ftp, HORIZONS_FTP_DIR)
    buffer = download(ftp, ftp_name)
    close(ftp)
    ftp_cleanup()

    return readstring(buffer)
end

function vec_tbl(OBJECT_NAME::String, local_file::String; timeout::Int=15,
        EMAIL_ADDR::String="joe@your.domain.name", CENTER::String="@ssb",
        REF_PLANE::String="ECLIP", START_TIME::String="2000-Jan-1",
        STOP_TIME::String="2000-Jan-2", STEP_SIZE::String="1 d",
        COORD_TYPE::String="G", SITE_COORD::String="0,0,0",
        REF_SYSTEM::String="J2000", VEC_CORR::Int=1,
        VEC_DELTA_T::Bool=false, OUT_UNITS::Int=1,
        CSV_FORMAT::Bool=false, VEC_LABELS::Bool=false,
        VEC_TABLE::Int=3)

    ftp_name = get_vec_tbl(OBJECT_NAME, timeout=timeout,
        EMAIL_ADDR=EMAIL_ADDR, CENTER=CENTER, REF_PLANE=REF_PLANE,
        START_TIME=START_TIME, STOP_TIME=STOP_TIME, STEP_SIZE=STEP_SIZE,
        COORD_TYPE=COORD_TYPE, SITE_COORD=SITE_COORD, REF_SYSTEM=REF_SYSTEM,
        VEC_CORR=VEC_CORR, VEC_DELTA_T=VEC_DELTA_T, OUT_UNITS=OUT_UNITS,
        CSV_FORMAT=CSV_FORMAT, VEC_LABELS=VEC_LABELS, VEC_TABLE=VEC_TABLE)

    # # Retrieve file by anonymous FTP and save to file `local_file`
    ftp_init()
    ftp = FTP(hostname=HORIZONS_MACHINE, username="anonymous", password=EMAIL_ADDR)
    cd(ftp, HORIZONS_FTP_DIR)
    file = download(ftp, ftp_name, local_file)
    close(ftp)
    ftp_cleanup()

    nothing
end

function get_vec_tbl(OBJECT_NAME::String; timeout::Int=15,
        EMAIL_ADDR::String="joe@your.domain.name", CENTER::String="@ssb",
        REF_PLANE::String="ECLIP", START_TIME::String="2000-Jan-1",
        STOP_TIME::String="2000-Jan-2", STEP_SIZE::String="1 d",
        COORD_TYPE::String="G", SITE_COORD::String="0,0,0",
        REF_SYSTEM::String="J2000", VEC_CORR::Int=1, VEC_DELTA_T::Bool=false,
        OUT_UNITS::Int=1, CSV_FORMAT::Bool=false, VEC_LABELS::Bool=false,
        VEC_TABLE::Int=3)

    ftp_name = "" # name of file at FTP server

    exp_internal = 0 # Diagnostic output: 1= on, 0=off
    
    remove_nulls = 0 # Disable null removal from Horizons output
    quiet = 0
    start_flag = 0
    
    # Connect to Horizons 
    proc = ExpectProc(`telnet $HORIZONS_MACHINE 6775`, timeout)

    # Get main prompt and proceed, turning off paging, specifying I/O model,
    # and sending object look-up from command-line 
    idx = expect!(proc, ["unknown host", "Horizons> "])
    if idx == 1
        throw("This system cannot find $HORIZONS_MACHINE")
    elseif idx == 2
        println(proc, "PAGE")
    end

    idx = expect!(proc, ["Horizons> "])
    if idx == 1
        println(proc, "\#\#2")
    end

    idx = expect!(proc, ["Horizons> "])
    if idx == 1
        println(proc, OBJECT_NAME)
    end

    # Handle object look-up confirmation 
    idx = expect!(proc, [r".*Continue.*: $", r".*such object record.*", r".*Select.*<cr>: $"])
    if idx == 1
        println(proc, "yes")
        idx = expect!(proc, [r".*PK.*: $", r".*lay.*: $"])
        if idx ==1
            println(proc, "E")
        elseif idx == 2
            println(proc, "x")
            throw(println("Cancelled -- unique object not found: $OBJECT_NAME\nObject not matched to database OR multiple matches found."))
        end
    elseif idx == 2
        println(proc, "x")
        throw(println("No such object record found: $OBJECT_NAME"))
    elseif idx == 3
        println(proc, "E")
    end

    # Request VECTOR table
    idx = expect!(proc, [r".*Observe, Elements.*: $"])
    if idx == 1
        println(proc, "V")
    end

    # Provide coordinate center
    idx = expect!(proc, [r".*Coordinate .*: $"])
    if idx == 1
        println(proc, CENTER)
    end

    # Handle coordinate center error or confirmation
    idx = expect!(proc, [r".*Cannot find central body.*: $", r".*Select.*<cr>: $", r".*Coordinate center.*<cr>: $", r".*Confirm selected.* $", r".*Cylindrical.*: $", r".*Reference plane.*: $"])

    if idx == 1
        println(proc, "X")
        throw(println("Cannot find CENTER = '$CENTER'"))
    elseif idx == 2
        println(proc, "X")
        throw(println("Non-unique CENTER = '$CENTER' (multiple matches)"))
    elseif idx == 3
        println(proc, "X")
        throw(println("Non-unique CENTER = '$CENTER' (multiple matches)"))    
    elseif idx == 4
        println(proc, "Y")
        idx = expect!(proc, [r".*Reference plane.*: $"])
        if idx == 1
            println(proc, REF_PLANE)
        end
    elseif idx == 5
        println(proc, COORD_TYPE)
        idx = expect!(proc, [r".*Unknown.*: $", r".*Enter c or g.*: $", r".*Specify.*: $"])
        if idx == 1
            println(proc, "X")
            throw(println("Unrecognized user-input coordinate: COORD_TYPE = '$COORD_TYPE'"))
        elseif idx == 2
            throw(println("Undefined or bad coordinate type: COORD_TYPE = '$COORD_TYPE'"))
        elseif idx == 3
            println(proc, SITE_COORD)
            idx = expect!(proc, [r".*Cannot read.*: $", r".*Specify.*: $", r".*Reference plane.*: $"])
            if idx == 1
                println(proc, "X")
                throw(println("Unrecognized site coordinate-triplet: SITE_COORD='$SITE_COORD'"))
            elseif idx == 2
                throw(println("Undefined site coordinate triplet: SITE_COORD = '$SITE_COORD'"))
            elseif idx == 3
                println(proc, REF_PLANE)
            end
        end
    elseif idx == 6
        println(proc, REF_PLANE)
    end

    # Handle reference plane error or START date
    idx = expect!(proc, [r".*Enter.*abbreviation.*: $", r".*Starting .*: $"])
    if idx == 1
        println(proc, "X")
        throw(println("Error in specification: REF_PLANE = '$REF_PLANE'\nSee Horizons documentation for available options."))
    elseif idx == 2
        start_flag = 1
        println(proc, START_TIME)
    end

    # Handle start date error or STOP date
    idx = expect!(proc, [r".*Cannot interpret.*: $", r".*No ephemeris.*: $", r".*Ending.*: $"])
    if idx == 1
        println(proc, "X")
        throw(println("Error in date format: START_TIME = '$START_TIME'\nSee Horizons documentation for accepted formats."))
    elseif idx == 2
        println(proc, "X")
        throw(println("START_TIME = '$START_TIME' prior to available ephemeris"))
    elseif idx == 3
        println(proc, STOP_TIME)
    end

    # Handle stop date error or get step size
    idx = expect!(proc, [r".*Cannot interpret.*", r".*No ephemeris.*", r".*Output interval.*: $"])
    if idx == 1
        println(proc, "X")
        throw(println("Error in date format: STOP_TIME = '$STOP_TIME'\nSee Horizons documentation for accepted formats."))
    elseif idx == 2
        println(proc, "X")
        throw(println("STOP_TIME = '$STOP_TIME' date beyond available ephemeris."))
    elseif idx == 3
        println(proc, STEP_SIZE)
    end

    # Handle step-size error or proceed to defaults
    idx = expect!(proc, [r".*Unknown.*: $", r".*Cannot use.*: $", r".*Accept default.*: $"])
    if idx == 1
        println(proc, "X")
        throw(println("STEP_SIZE = '$STEP_SIZE' error."))
    elseif idx == 2
        println(proc, "X")
        throw(println("STEP_SIZE = '$STEP_SIZE' error."))
    elseif idx == 3
        println(proc, "N") # never accept table defaults
    end

    # Change output table defaults
    while true
        idx = expect!(proc, [r"(Cannot interpret.*\r)", r".*frame.*].*: $", r".*Corrections.*].*: $", r".*units.*].*: $", r".*CSV.*].*: $", r".*Label.*].*: $", r".*delta-T.*].*: $", r".*table type.*].*: $", r".*Select.*: $", r".*].*: $"])
        if idx == 1
            println(proc, "X")
            throw(println("Error in $proc.match, $proc.before. \nSee Horizons documentation for acceptable values."))
        elseif idx == 2
            println(proc, REF_SYSTEM)
        elseif idx == 3
            println(proc, "$VEC_CORR")
        elseif idx == 4
            println(proc, "$OUT_UNITS")
        elseif idx == 5
            println(proc, yesornostring(CSV_FORMAT))
        elseif idx == 6
            println(proc, yesornostring(VEC_LABELS))
        elseif idx == 7
            println(proc, yesornostring(VEC_DELTA_T))
        elseif idx == 8
            println(proc, "$VEC_TABLE")
        elseif idx == 9
            break # Done w/default override
        elseif idx == 10
            println(proc, "") # Skip unknown (new?) prompt
        end 
    end
    # expect!(proc, r".*Select.*: $")

    # Osculating element table output has been generated. Now sitting at 
    # post-output prompt. Initiate FTP file transfer.
    println(proc, "F")

    # Pick out ftp file name
    result = expect!(proc, r"File name   : (.*)\r\r\n   File type")
    proc_match = match(r"File name   : (.*)\r\r\n   File type", proc.match)
    ftp_name = strip(proc_match[1]) #quit possible trailing whitespaces

    return ftp_name
end