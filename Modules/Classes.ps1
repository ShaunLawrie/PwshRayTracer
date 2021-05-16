class Rgb {
    [int] $Red
    [int] $Green
    [int] $Blue
}

class Sphere {
    [vec3] $Center
    [float] $Radius
    [rgb] $Rgb
}

class Vec3 {
    [float] $X
    [float] $Y
    [float] $Z
}

class Ray {
    [vec3] $Origin
    [vec3] $Direction
}