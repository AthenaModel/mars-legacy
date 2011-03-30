#-----------------------------------------------------------------------
# TITLE:
#    mapsimple.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    marsutil(n) module: a simple projection(i) type.
#
#    Routines for conversion between canvas coordinates and map references.
#    A map is an image file used as a map background.
#
#    There are three kinds of coordinate in use:
#
#    * Canvas coordinates: cx,cy coordinates extending to the right and
#      and down from the origin.  The full area of the canvas can be
#      much larger than the visible area.  Canvas coordinates are floating
#      point pixels.  The canvas coordinates for a map location are
#      unique for any given zoom factor, but vary from one zoom factor
#      to another.  Conversions to and from canvas coordinates take
#      the zoom factor into account.
#
#    * Map units: mx,my coordinates extending to the right and down from
#      the upper-left corner of the map image.  Map units are
#      independent of zoom factor.  Map units are determined as
#      follows:
#
#          lat = canvas units / (delta map x * (zoom factor/100.0))
#          lon = canvas units / (delta map y * (zoom factor/100.0))
#
#      The zoom factor is a number, nominally 100, which indicates the
#      zoom level, i.e., 100%, 200%, 50%, etc.
#
#      Delta map x and delta map y are computed from the width and height
#      of the map image and the width in latitude and height in longitude.
#
#      Thus,
#          delta map x = (image width / (max lat - min lat))
#          delta map y = (image height / (max lon - min lon))
#
#      The basic assumption is that it is a nicely square patch of earth, which
#      is *very* simple, hence the name of the projection. This projection
#      should only be used if the map image conforms to this assumption.
#
#    * Map locations (map locs) : computed as above
#    * Map references (map refs): computed from the lat/long pair 
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsutil:: {
    namespace export mapsimple
}

#-----------------------------------------------------------------------
# mapref type

snit::type ::marsutil::mapsimple {
    #-------------------------------------------------------------------
    # Options

    # Width and height of map, in pixels
    option -width  \
        -type {snit::integer -min 1}  \
        -default 1000

    option -height \
        -type {snit::integer -min 1}  \
        -default 1000

    # Min/max latitude and longitude
    option -minx -type snit::double -default 0.0
    option -maxx -type snit::double -default 3.0
    option -miny -type snit::double -default 0.0
    option -maxy -type snit::double -default 3.0

    #-------------------------------------------------------------------
    # Instance Variables

    # mwid, mht
    #
    # Dimensions in map coordinates
    
    variable mwid 1000
    variable mht  1000
    variable dmx  0.1
    variable dmy  0.1
    
    #-------------------------------------------------------------------
    # Constructor

    # None needed

    #-------------------------------------------------------------------
    # Methods

    method init {} {
        set dmx [expr {($options(-maxx)-$options(-minx))/$options(-width)}]
        set dmy [expr {($options(-maxy)-$options(-miny))/$options(-height)}]
    }

    # box
    #
    # Returns the bounding box of the map in map units

    method box {} {
        list 0 0 $mwid $mht
    }

    # dim
    #
    # Returns the dimensions of the map in map units

    method dim {} {
        list $mwid $mht
    }

    # c2m zoom cx cy
    #
    # zoom     Zoom factor
    # cx,cy    Position in canvas units
    #
    # Returns the position in map units

    method c2m {zoom cx cy} {
        set fac [expr {$zoom/100.0}]
        list [expr {$cx/$fac*$dmx}] [expr {$cy/$fac*$dmy}]
    }

    # m2c zoom mx my....
    #
    # zoom     Zoom factor
    # mx,my    One or points in map units
    #
    # Returns the points in canvas units

    method m2c {zoom args} {
        set out [list]
        set fac [expr {$zoom/100.0}]
        foreach {mx my} $args {
            lappend out [expr {int($mx*$fac/$dmx)}] [expr {int($my*$fac/$dmy)}]
        }

        return $out
    }

    # c2ref zoom cx cy
    #
    # zoom     Zoom factor
    # cx,cy    Position in canvas units
    #
    # Returns the position as a map reference

    method c2ref {zoom cx cy} {
        set fac [expr {$zoom/100.0}]
        set lat [expr {$cx/$fac*$dmx}] 
        set lon [expr {$cy/$fac*$dmy}]
        return [latlong tomgrs [list $lat $lon]]
    }

    # ref2c zoom ref...
    #
    # zoom     Zoom factor
    # ref      A map reference
    #
    # Returns a list {cx cy} in canvas units

    method ref2c {zoom args} {
        set fac [expr {$zoom/100.0}]

        foreach ref $args {
            lassign [latlong frommgrs $ref] lat lon
            set cx [expr {int($lat*$fac/$dmy)}]
            set cy [expr {int($lon*$fac/$dmx)}]
            lappend result $cx $cy
        }

        return $result
    }

    # m2ref mx my....
    #
    # mx,my    Position in map units
    #
    # Returns the position(s) as mapref strings

    method m2ref {args} {
        set result [list]

        foreach {mx my} $args {
            lappend result [latlong tomgrs [list $mx $my]]
        }
        
        return $result
    }

    # ref2m ref...
    #
    # ref   A map reference string
    #
    # Returns a list {mx my...} in map units

    method ref2m {args} {
        set result ""

        foreach ref $args {
            lappend result [latlong frommgrs $ref] 
        }

        return $result
    }

    # ref validate ref....
    #
    # ref   A map reference
    #
    # Validates the map reference for form and content.

    method {ref validate} {args} {
        set prefix ""

        foreach ref $args {
            if {[catch {latlong frommgrs $ref} result]} {
                error "invalid MGRS coordinate: \"$ref\""
            }
        }

        return $args
    }
}

