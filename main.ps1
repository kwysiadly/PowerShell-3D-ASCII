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
    [int] $z_ = $z
    return @($x_, $y_, $z_)
}
function Get-Coordinates ( [int] $x, [int] $y, [int] $z, [int] $zoom, [int] $distance ) {
    $x += $global:vx
    $y += $global:vy
    $z += $global:vz
    [int] $x_ = $global:xCenter + $zoom * ( -( $x / $y ) * $distance )
    [int] $y_ = $global:yCenter - $zoom * ( -( $z / $y ) * $distance )
    return @( $x_, $y_ )
}

Clear-Host
$Host.UI.RawUI.FlushInputBuffer()
Set-Display $global:width $($global:height + 1)

Set-Buffer

[int] $global:vx        = 0
[int] $global:vy        = -500
[int] $global:vz        = 0
[int] $width            = 50
[char] $global:pixel    = '0'
[float] $alfa           = 0
[float] $beta           = 0
[float] $gamma          = 0
[float] $pi             = [Math]::pi

$figures = @{
    "cube" = @{
        "zoom" = 15;
        "distance" = 6;
        "points" = @(
            @( $width, $width, $width ), @( -$width, $width, $width ), @( -$width, -$width, $width ), @( $width, -$width, $width ),
            @( $width, $width, -$width ), @( -$width, $width, -$width ), @( -$width, -$width, -$width ), @( $width, -$width, -$width )
        );
        "coords" = @(
            @(0, 0), @(0, 0), @(0, 0), @(0, 0),
            @(0, 0), @(0, 0), @(0, 0), @(0, 0)
        );
        "lines" = @(
            @( 0, 1 ), @( 1, 2 ), @( 2, 3 ), @( 3, 0 ),
            @( 4, 5 ), @( 5, 6 ), @( 6, 7 ), @( 7, 4 ),
            @( 0, 4 ), @( 1, 5 ), @( 2, 6 ), @( 3, 7 )
        )
    };
    "triangle" = @{
        "zoom" = 15;
        "distance" = 6;
        "points" = @(
            @( $width, $width, $width ), @( -$width, $width, $width ), @( 0, -$width, $width ),
            @( 0, 0, -$width )
        );
        "coords" = @(
            @(0, 0), @(0, 0), @(0, 0), @(0, 0)
        );
        "lines" = @(
            @( 0, 1 ), @( 1, 2 ), @( 2, 0 ),
            @( 0, 3 ), @( 1, 3 ), @( 2, 3 )
        )
    };
    "pyramid" = @{
        "zoom" = 15;
        "distance" = 6;
        "points" = @(
            @( $width, $width, $width ), @( -$width, $width, $width ), @( -$width, -$width, $width ), @( $width, -$width, $width ),
            @( 0, 0, -$width )
        );
        "coords" = @(
            @(0, 0), @(0, 0), @(0, 0), @(0, 0),
            @(0, 0)
        );
        "lines" = @(
            @( 0, 1 ), @( 1, 2 ), @( 2, 3 ), @( 3, 0 ),
            @( 0, 4 ), @( 1, 4 ), @( 2, 4 ), @( 3, 4 )
        )
    };
    "star" = @{
        "zoom" = 15;
        "distance" = 6;
        "points" = @(
            @( $width, $width, $width ), @( -$width, $width, $width ), @( -$width, -$width, $width ), @( $width, -$width, $width ),
            @( $width, $width, -$width ), @( -$width, $width, -$width ), @( -$width, -$width, -$width ), @( $width, -$width, -$width ),
            @( 0, 0, $($width+$width*2) ), @( 0, $($width+$width*2), 0 ), @( 0, 0, -$($width+$width*2) ), @( 0, -$($width+$width*2), 0 ),
            @( -$($width+$width*2), 0, 0 ), @( $($width+$width*2), 0, 0 )
        );
        "coords" = @(
            @( 0, 0 ), @( 0, 0 ), @( 0, 0 ), @( 0, 0 ),
            @( 0, 0 ), @( 0, 0 ), @( 0, 0 ), @( 0, 0 ),
            @( 0, 0 ), @( 0, 0 ), @( 0, 0 ), @( 0, 0 ),
            @( 0, 0 ), @( 0, 0 )
        );
        "lines" = @(
            @( 0, 1 ), @( 1, 2 ), @( 2, 3 ), @( 3, 0 ),
            @( 4, 5 ), @( 5, 6 ), @( 6, 7 ), @( 7, 4 ),
            @( 0, 4 ), @( 1, 5 ), @( 2, 6 ), @( 3, 7 ),
            @( 0, 8 ), @( 1, 8 ), @( 2, 8 ), @( 3, 8 ),
            @( 0, 9 ), @( 1, 9 ), @( 4, 9 ), @( 5, 9 ),
            @( 4, 10 ), @( 5, 10 ), @( 6, 10 ), @( 7, 10 ),
            @( 2, 11 ), @( 3, 11 ), @( 6, 11 ), @( 7, 11 ),
            @( 1, 12 ), @( 2, 12 ), @( 5, 12 ), @( 6, 12 ),
            @( 0, 13 ), @( 3, 13 ), @( 4, 13 ), @( 7, 13 )
        )
    };
    "dodecahedron" = @{
        "zoom" = 30;
        "distance" = 6;
        "points" = @(
            @( 0, -($width/3), $width ),
            @( ($width/2), -($width/2), ($width/2) ),
            @( $width, 0, ($width/3) ),
            @( ($width/2), ($width/2), ($width/2) ),
            @(  0, ($width/3), $width ),
            @( -($width/2), ($width/2), ($width/2) ),
            @( -$width, 0, ($width/3) ),
            @( -($width/2), -($width/2), ($width/2) ),
            @( -($width/3), -$width, 0 ),
            @( ($width/3), -$width, 0 ),
            @( ($width/2), -($width/2), -($width/2) ),
            @( $width, 0, -($width/3) ),
            @( ($width/2), ($width/2), -($width/2) ),
            @( ($width/3), $width, 0 ),
            @( -($width/3), $width, 0 ),
            @( -($width/2), ($width/2), -($width/2) ),
            @( -$width, 0, -($width/3) ),
            @( -($width/2), -($width/2), -($width/2) ),
            @( 0, -($width/3), -$width ),
            @( 0, ($width/3), -$width  )
        );
        "coords" = @(
            @(0, 0), @(0, 0), @(0, 0), @(0, 0), @(0, 0),
            @(0, 0), @(0, 0), @(0, 0), @(0, 0), @(0, 0),
            @(0, 0), @(0, 0), @(0, 0), @(0, 0), @(0, 0),
            @(0, 0), @(0, 0), @(0, 0), @(0, 0), @(0, 0)
        );
        "lines" = @(
            #@( 0, 1 ), @( 1, 2 ), @( 2, 3 ), @( 3, 4 ), @( 4, 0 ),
            #@( 0, 4 ), @( 4, 5 ), @( 5, 6 ), @( 6, 7 ), @( 7, 0 ),
            #@( 0, 7 ), @( 7, 8 ), @( 8, 9 ), @( 9, 1 ), @( 1, 0 ),
            #@( 1, 9 ), @( 9, 10 ), @( 10, 11 ), @( 11, 2 ), @( 2, 1 ),
            #@( 2, 11 ), @( 11, 12 ), @( 12, 13 ), @( 13, 3 ), @( 3, 2 ),
            #@( 3, 13 ), @( 13, 14 ), @( 14, 5 ), @( 5, 4 ), @( 4, 3 ),
            #@( 5, 14 ), @( 14, 15 ), @( 15, 16 ), @( 16, 6 ), @( 6, 5 ),
            #@( 6, 16 ), @( 16, 17 ), @( 17, 8 ), @( 8, 7 ), @( 7, 6 ),
            #@( 8, 17 ), @( 17, 18 ), @( 18, 10 ), @( 10, 9 ), @( 9, 8 ),
            #@( 10, 18 ), @( 18, 19 ), @( 19, 12 ), @( 12, 11 ), @( 11, 10 ),
            #@( 12, 19 ), @( 19, 15 ), @( 15, 14 ), @( 14, 13 ), @( 13, 12 ),
            #@( 15, 19 ), @( 19, 18 ), @( 18, 17 ), @( 17, 16 ), @( 16, 15 )
            @( 0, 1 ), @( 1, 2 ), @( 2, 3 ), @( 3, 4 ), @( 4, 0 ),
            @( 4, 5 ), @( 5, 6 ), @( 6, 7 ), @( 7, 0 ),
            @( 7, 8 ), @( 8, 9 ), @( 9, 1 ),
            @( 9, 10 ), @( 10, 11 ), @( 11, 2 ),
            @( 11, 12 ), @( 12, 13 ), @( 13, 3 ),
            @( 13, 14 ), @( 14, 5 ),
            @( 14, 15 ), @( 15, 16 ), @( 16, 6 ),
            @( 16, 17 ), @( 17, 8 ),
            @( 17, 18 ), @( 18, 10 ),
            @( 18, 19 ), @( 19, 12 ),
            @( 19, 15 )
        )
    }
}
$object = $figures.cube
While ( $true ) {
    [char] $char = Get-Char
    if ( $char -eq 'q' ) {
        break
    }
    switch ( $char ) {
        '1' { $object = $figures.cube }
        '2' { $object = $figures.triangle }
        '3' { $object = $figures.pyramid }
        '4' { $object = $figures.star }
        '5' { $object = $figures.dodecahedron }
        '0' { 
            [int] $temp = $global:pixel
            $temp++
            $global:pixel = $temp
        }
    }

    if ( $alfa -le $pi * 2 ) {
        $alfa += $pi / 50
        $beta = $alfa
        $gamma = $alfa
    } else {
        $alfa = 0
        $beta = 0
        $gamma = 0
    }
    
    Clear-Buffer $true
    Set-Cursor 0 0

    for ( $i = 0; $i -lt $object.points.Count; $i++ ) {
        $p_ = Get-xRotation $object.points[$i][0] $object.points[$i][1] $object.points[$i][2] $alfa
        $p_ = Get-yRotation $p_[0] $p_[1] $p_[2] $beta
        $p_ = Get-zRotation $p_[0] $p_[1] $p_[2] $gamma
        $p_ = Get-Coordinates $p_[0] $p_[1] $p_[2] $object.zoom $object.distance
        $object.coords[$i][0] = $p_[0]
        $object.coords[$i][1] = $p_[1]
    }

    for ( $i = 0; $i -lt $object.lines.Count; $i++ ) {
        $p1 = $object.lines[$i][0]
        $p2 = $object.lines[$i][1]
        Set-Line $object.coords[$p1][0] $object.coords[$p1][1] $object.coords[$p2][0] $object.coords[$p2][1]
    }

    Get-Buffer
}
