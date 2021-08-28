[int] $global:width     = 120
[int] $global:height    = 60
[int] $global:xCenter   = $global:width / 2
[int] $global:yCenter   = $global:height / 2

function Set-Display ( [int] $width, [int] $height ) {
    
    $window             = $Host.UI.RawUI
    $newSize            = $window.windowSize
    $newSize.height     = $height
    $newSize.width      = $width
    $window.windowSize  = $newSize
}

function Set-Cursor ( [int] $x, [int] $y ) {
    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $x, $y
}

function Get-Char () {
    if ( $Host.UI.RawUI.KeyAvailable ) {
        [char] $ch = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp,IncludeKeyDown").Character
        $Host.UI.RawUI.FlushInputBuffer()
        return $ch
    } else {
        return $null
    }
}

function Set-Buffer () {
    $global:buffer = [Object[]]::new($global:height)
    for ( $i = 0; $i -lt $global:height; $i++ ) {
        $global:buffer[$i] = [char[]]::new($global:width)
    }
}

function Clear-Buffer ( [bool] $clear ) {
    for ( $i = 0; $i -lt $global:height; $i++ ) {
        if ( $clear -eq $true ) {
            for ( $j = 0; $j -lt $global:width; $j++ ) {
                $global:buffer[$i][$j] = ' '
            }
        }
        $global:buffer[$i][-1] = [char]10
    }
}

function Get-Buffer () {
    [string] $screen = '';
    for ( $i = 0; $i -lt $global:height; $i++ ) {
        for ( $j = 0; $j -lt $global:width; $j++ ) {
            $screen += $global:buffer[$i][$j]
        }
    }
    Write-Host $screen -NoNewline
}

function Set-Line ( [int] $x1, [int] $y1, [int] $x2, [int] $y2 ) {
    [int] $xi = $yi = $ai = $bi = $dx = $dy = $d = $null
    [int] $xMax = $global:width - 2 
    [int] $yMax = $global:height - 1
    [int] $x    = $x1
    [int] $y    = $y1
    if ( $x1 -lt $x2 ) {
        $xi = 1
        $dx = $x2 - $x1
    } else {
        $xi = -1
        $dx = $x1 - $x2
    }
    if ( $y1 -lt $y2 ) {
        $yi = 1
        $dy = $y2 - $y1
    } else {
        $yi = -1
        $dy = $y1 - $y2
    }
    if ( $x -le $xMax -and $x -ge 0 -and $y -le $yMax -and $y -ge 0 ) {
        $global:buffer[$y][$x] = $global:pixel
    }
    if ($dx -gt $dy) {
        $ai = ($dy - $dx) -shl 1
        $bi = $dy -shl 1
        $d = $bi - $dx
        while ($x -ne $x2) {
            if ($d -ge 0) {
                $y += $yi
                $d += $ai
            } else {
                $d += $bi
            }
            $x += $xi
            if ( $x -le $xMax -and $x -ge 0 -and $y -le $yMax -and $y -ge 0 ) {
                $global:buffer[$y][$x] = $global:pixel
            }
        }
    } else {
        $ai = ( $dx - $dy ) -shl 1
        $bi = $dx -shl 1
        $d = $bi - $dy
        while ( $y -ne $y2 ) {
            if ( $d -ge 0 ) {
                $x += $xi
                $d += $ai
            } else {
                $d += $bi
            }
            $y += $yi
            if ( $x -le $xMax -and $x -ge 0 -and $y -le $yMax -and $y -ge 0 ) {
                $global:buffer[$y][$x] = $global:pixel
            }
        }
    }
}

function Get-xRotation ( [int] $x, [int] $y, [int] $z, [float] $angle ) {
    [int] $x_ = $x;
    [int] $y_ = [Math]::cos($angle) * $y - [Math]::sin($angle) * $z
    [int] $z_ = [Math]::sin($angle) * $y + [Math]::cos($angle) * $z
    return @($x_, $y_, $z_)
}

function Get-yRotation ( [int] $x, [int] $y, [int] $z, [float] $angle ) {
    [int] $x_ = [Math]::cos($angle) * $x - [Math]::sin($angle) * $z
    [int] $y_ = $y
    [int] $Z_ = [Math]::sin($angle) * $x + [Math]::cos($angle) * $z
    return @($x_, $y_, $z_)
}

function Get-zRotation ( [int] $x, [int] $y, [int] $z, [float] $angle ) {
    [int] $x_ = [Math]::cos($angle) * $x - [Math]::sin($angle) * $y
    [int] $y_ = [Math]::sin($angle) * $x + [Math]::cos($angle) * $z
    #[int] $y_ = -[Math]::sin($angle) * $x + [Math]::cos($angle) * $z
    [int] $z_ = $z
    return @($x_, $y_, $z_)
}
function Get-Coordinates ( [int] $x, [int] $y, [int] $z, [int] $zoom, [int] $distance ) {
    $x += $global:vx
    $y += $global:vy
    $z += $global:vz
    [int] $x_ = $global:xCenter + $zoom * ( -( $x / $y ) * $distance )
    [int] $y_ = $global:yCenter - $zoom * ( -( $z / $y ) * $distance )
    return @( $x_, $y_, $x, $y, $z )
}

function New-LineCount ( $obj ) {
    [int] $count = 0
    for ( [int] $i = 0; $i -lt $obj.Count; $i++ ) {
        $count += $obj[$i].Count
    }
    return  @( [int] 0, [int] $count, [int] 0 )
}

function Add-Table ( $obj, [string] $name, [string] $newName, [int] $width = 0 ) {
    [int] $w = 0
    if ( $width -gt 0 ) {
        $w = $width
    }
    [int] $h = $obj[$name].Count

    $obj[$newName] = [Object[]]::new($h)
    for ( $i = 0; $i -lt $h; $i++ ) {
        if ( $width -eq 0 ) {
            $w = $obj[$name][$i].Count
        }
        $obj[$newName][$i] += [int[]]::new($w)
    }
}

Clear-Host
$Host.UI.RawUI.FlushInputBuffer()
Set-Display $global:width $($global:height + 1)

Set-Buffer

[int] $width = 50
$figures = @{
    "cube" = @{
        "zoom"      = 15;
        "distance"  = 10;
        "points"    = @(
            @( -$width, $width, $width ),   @( $width, $width, $width ),    @( $width, -$width, $width ),   @( -$width, -$width, $width ),
            @( -$width, $width, -$width ),  @( $width, $width, -$width ),   @( $width, -$width, -$width ),  @( -$width, -$width, -$width )
        );
        "shapes" = @(
            @( 0, 1, 2, 3, 0 ), @( 1, 0, 4, 5, 1 ), @( 5, 4, 7, 6, 5 ), @( 6, 7, 3, 2, 6 ), @( 4, 0, 3, 7, 4 ), @( 1, 5, 6, 2, 1 )
        )
    };
    "triangle" = @{
        "zoom"      = 15;
        "distance"  = 12;
        "points"    = @(
            @( -$width, $width, $width ), @( $width, $width, $width ), @( 0, $width, -$width ), @( 0, -$width, 0 )
        );
        "shapes" = @(
            @( 1, 0, 2, 1 ), @( 0, 1, 3, 0 ), @( 2, 0, 3, 2 ), @( 1, 2, 3, 1 )
        )
    };
    "pyramid" = @{
        "zoom"      = 15;
        "distance"  = 10;
        "points"    = @(
            @( -$width, $width, $width ), @( $width, $width, $width ), @( $width, -$width, $width ), @( -$width, -$width, $width ), @( 0, 0, -$width )
        );
        "shapes" = @(
            @( 0, 1, 2, 3, 0 ), @( 1, 0, 4, 1 ), @( 2, 1, 4, 2 ), @( 3, 2, 4, 3 ), @( 0, 3, 4, 0 )
        )
    };
    "star" = @{
        "zoom"      = 25;
        "distance"  = 6;
        "points"    = @(
            @( -$width, $width, $width ),   @( $width, $width, $width ),    @( $width, -$width, $width ),   @( -$width, -$width, $width ),
            @( -$width, $width, -$width ),  @( $width, $width, -$width ),   @( $width, -$width, -$width ),  @( -$width, -$width, -$width )
            @( 0, 0, $($width*1.5) ),       @( 0, $($width*1.5), 0 ),       @( 0, 0, -$($width*1.5) ),      @( 0, -$($width*1.5), 0 ),
            @( -$($width*1.5), 0, 0 ),      @( $($width*1.5), 0, 0 )
        );
        "shapes" = @(
            @( 0, 1, 8, 0 ),    @( 1, 2, 8, 1 ),    @( 2, 3, 8, 2 ),    @( 3, 0, 8, 3 ), 
            @( 1, 0, 9, 1 ),    @( 0, 4, 9, 0 ),    @( 4, 5, 9, 4 ),    @( 5, 1, 9, 5 ),
            @( 5, 4, 10, 5 ),   @( 4, 7, 10, 4 ),   @( 7, 6, 10, 7 ),   @( 6, 5, 10, 6 ),
            @( 6, 7, 11, 6 ),   @( 7, 3, 11, 7 ),   @( 3, 2, 11, 3 ),   @( 2, 6, 11, 2 ),
            @( 4, 0, 12, 4 ),   @( 0, 3, 12, 0 ),   @( 3, 7, 12, 3 ),   @( 7, 4, 12, 7 ),
            @( 1, 5, 13, 1 ),   @( 5, 6, 13, 5 ),   @( 6, 2, 13, 6 ),   @( 2, 1, 13, 2 )
        )
    };
    "dodecahedron" = @{
        "zoom"      = 25;
        "distance"  = 10;
        "points"    = @(
            @( 0, -18, 47 ),    @( 29, -29, 29 ),   @( 47, 0, 18 ),     @( 29, 29, 29 ),    @(  0, 18, 47 ),
            @( -29, 29, 29 ),   @( -47, 0, 18 ),    @( -29, -29, 29 ),  @( -18, -47, 0 ),   @( 18, -47, 0 ),
            @( 29, -29, -29 ),  @( 47, 0, -18 ),    @( 29, 29, -29 ),   @( 18, 47, 0 ),     @( -18, 47, 0 ),
            @( -29, 29, -29 ),  @( -47, 0, -18 ),   @( -29, -29, -29 ), @( 0, -29, -47 ),   @( 0, 18, -47 )
        );
        "shapes" = @(
            @( 0, 1, 2, 3, 4, 0 ),          @( 0, 4, 5, 6, 7, 0 ),          @( 0, 7, 8, 9, 1, 0 ),
            @( 1, 9, 10, 11, 2, 1 ),        @( 2, 11, 12, 13, 3, 2 ),       @( 3, 13, 14, 5, 4, 3 ),
            @( 5, 14, 15, 16, 6, 5 ),       @( 6, 16, 17, 8, 7, 6 ),        @( 8, 17, 18, 10, 9, 8 ),
            @( 10, 18, 19, 12, 11, 10 ),    @( 12, 19, 15, 14, 13, 12 ),    @( 15, 19, 18, 17, 16, 15 )
        )
    }
}
$object = $figures.cube
#$object = $figures.triangle
#$object = $figures.pyramid
#$object = $figures.star
#$object = $figures.dodecahedron

[int] $global:vx            = 0
[int] $global:vy            = 500
[int] $global:vz            = 0
[int] $sk                   = $null
[char] $global:pixel        = '0'
[char] $char                = $null
[float] $alfa               = 0
[float] $beta               = 0
[float] $gamma              = 0
[float] $pi                 = [Math]::pi
[bool] $hiddenLines         = $true
[string] $drawnLinesIndex   = ""
[int[]] $lineCount          = New-LineCount $object.shapes
Add-Table $object "points" "points_"
Add-Table $object "points" "coords" 2

While ( $true ) {
    $char = Get-Char
    if ( $char -eq '1' ) {
        $object = $figures.cube
    } elseif ( $char -eq '2' ) {
        $object = $figures.triangle
    } elseif ( $char -eq '3' ) {
        $object = $figures.pyramid
    } elseif ( $char -eq '4' ) {
        $object = $figures.star
    } elseif ( $char -eq '5' ) {
        $object = $figures.dodecahedron
    } elseif ( $char -eq '0' ) { 
        ([int]$global:pixel)++
        Start-Sleep -Milliseconds 100
    } elseif ( $char -eq 'h' ) {
        $lineCount = New-LineCount $object.shapes
        Start-Sleep -Milliseconds 100
        $hiddenLines = $hiddenLines -xor 0x01
    } elseif ( $char -eq 'q' ) {
        break
    }
    if ( $char -match "[1-5]" ) {
        $lineCount = New-LineCount $object.shapes
        Add-Table $object "points" "points_"
        Add-Table $object "points" "coords" 2
    }
    $Host.UI.RawUI.FlushInputBuffer()

    if ( $alfa -le $pi * 2 ) {
        $alfa   += $pi / 50
        $beta    = $gamma = $alfa
    } else {
        $alfa = $beta = $gamma = 0
    }
    
    Clear-Buffer $true
    Set-Cursor 0 0

    for ( $i = 0; $i -lt $object.points.Count; $i++ ) {
        $p_ = Get-xRotation $object.points[$i][0] $object.points[$i][1] $object.points[$i][2] $alfa
        #$p_ = Get-yRotation $p_[0] $p_[1] $p_[2] $beta
        $object.points_[$i] = Get-yRotation $p_[0] $p_[1] $p_[2] $beta
        #$object.points_[$i] = Get-zRotation $p_[0] $p_[1] $p_[2] $gamma
        $p_ = Get-Coordinates $object.points_[$i][0] $object.points_[$i][1] $object.points_[$i][2] $object.zoom $object.distance
        $object.coords[$i][0] = $p_[0]
        $object.coords[$i][1] = $p_[1]
    }

    $lineCount[0]   = 0
    $drawnLines     = @{}
    $sk             = $null
    for ( [int] $i = 0; $i -lt $object.shapes.Count; $i++ ) {
        if ( $hiddenLines -eq $true ) {
            #$px0 = $object.coords[$object.shapes[$i][0]][0]
            #$py0 = $object.coords[$object.shapes[$i][0]][1]
            #$px1 = $object.coords[$object.shapes[$i][1]][0]
            #$py1 = $object.coords[$object.shapes[$i][1]][1]
            #$px2 = $object.coords[$object.shapes[$i][2]][0]
            #$py2 = $object.coords[$object.shapes[$i][2]][1]
            #$sk = ( $px1 - $px0 ) * ( $py2 - $py1 ) - ( $py1 - $py0 ) * ( $px2 - $px1 )
            $sk = ( $object.coords[$object.shapes[$i][1]][0] - $object.coords[$object.shapes[$i][0]][0] ) * `
                  ( $object.coords[$object.shapes[$i][2]][1] - $object.coords[$object.shapes[$i][1]][1] ) - `
                  ( $object.coords[$object.shapes[$i][1]][1] - $object.coords[$object.shapes[$i][0]][1] ) * `
                  ( $object.coords[$object.shapes[$i][2]][0] - $object.coords[$object.shapes[$i][1]][0] )
        }
        if ( $sk -ge 0 ) {
            #$global:pixel = $(0x30 + $i)
            for ( $j = 0; $j -lt $object.shapes[$i].Count - 1; $j++ ) {
                $p1 = $object.shapes[$i][$j]
                $p2 = $object.shapes[$i][$j+1]
                if ( $p1 -gt $p2 ) {
                    $drawnLinesIndex = "$p2$p1"
                } else {
                    $drawnLinesIndex = "$p1$p2"
                    }
                if ( $null -eq $drawnLines[$drawnLinesIndex] ) {
                    Set-Line $object.coords[$p1][0] $object.coords[$p1][1] $object.coords[$p2][0] $object.coords[$p2][1]
                    $lineCount[0]++
                    $drawnLines[$drawnLinesIndex] = $false
                }
            }
        }
    }

    Get-Buffer
    Set-Cursor 0 0
    if ( $lineCount[0] -gt $lineCount[2] ) {
        $lineCount[2] = $lineCount[0]
    } elseif ( $lineCount[0] -lt $lineCount[1] ) {
        $lineCount[1] = $lineCount[0]
    }
    Write-Host "Line #:" $lineCount[0] "| Min:" $lineCount[1] "| Max:" $lineCount[2]
    #Read-Host
}
