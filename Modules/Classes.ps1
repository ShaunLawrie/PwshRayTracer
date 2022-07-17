# https://raytracing.github.io/books/RayTracingInOneWeekend.html#thevec3class
# Utility functions are defined in the more normal for powershell way rather than using this class to define instance methods
# See Vector.psm1 for vector functions
class Vec3 {
    [float] $X
    [float] $Y
    [float] $Z
}

# Rather than use the vec3 to also represent colours there is a separate RGB class
class Rgb {
    [int] $Red
    [int] $Green
    [int] $Blue
}

# https://raytracing.github.io/books/RayTracingInOneWeekend.html#rays,asimplecamera,andbackground/therayclass
class Ray {
    [System.Numerics.Vector3] $Origin
    [System.Numerics.Vector3] $Direction
}

# Objects
class Sphere {
    [System.Numerics.Vector3] $Center
    [float] $Radius
    [rgb] $Rgb
}

# https://raytracing.github.io/books/RayTracingInOneWeekend.html#surfacenormalsandmultipleobjects/anabstractionforhittableobjects
class HitRecord {
    [System.Numerics.Vector3] $Point
    [System.Numerics.Vector3] $Normal
    [float] $T
    [bool] $FrontFace
}