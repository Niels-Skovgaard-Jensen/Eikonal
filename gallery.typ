#import "eikonal.typ": *
#set page(width: 21cm, height: auto, margin: 1cm)
#set text(size: 7pt, font: "DejaVu Sans Mono")

#let shapes = (
  ("circle", sd-circle(r: 0.8), 1.5),
  ("rounded-box", sd-rounded-box(w: 0.8, h: 0.5, r: (0.4, 0.05, 0.2, 0.1)), 1.5),
  ("chamfer-box", sd-chamfer-box(w: 0.7, h: 0.5, chamfer: 0.3), 1.5),
  ("box", sd-box(w: 0.8, h: 0.5), 1.5),
  ("oriented-box", sd-oriented-box(a: (-0.7, -0.4), b: (0.7, 0.4), th: 0.4), 1.5),
  ("segment", sd-segment(a: (-0.7, -0.4), b: (0.7, 0.4), r: 0.15), 1.5),
  ("rhombus", sd-rhombus(w: 0.8, h: 0.5), 1.5),
  ("trapezoid", sd-trapezoid(r1: 0.8, r2: 0.4, he: 0.6), 1.5),
  ("parallelogram", sd-parallelogram(wi: 0.5, he: 0.5, sk: 0.4), 1.5),
  ("equilateral-tri", sd-equilateral-triangle(r: 0.7), 1.5),
  ("isosceles-tri", sd-triangle-isosceles(w: 0.6, he: -0.9), 1.5),
  ("triangle", sd-triangle(p0: (-0.8, -0.5), p1: (0.7, -0.7), p2: (0.1, 0.8)), 1.5),
  ("uneven-capsule", sd-uneven-capsule(r1: 0.5, r2: 0.15, h: 0.8), 1.5),
  ("pentagon", sd-pentagon(r: 0.8), 1.5),
  ("hexagon", sd-hexagon(r: 0.8), 1.5),
  ("octogon", sd-octogon(r: 0.8), 1.5),
  ("hexagram", sd-hexagram(r: 0.5), 1.5),
  ("pentagram", sd-pentagram(r: 0.8), 1.5),
  ("star", sd-star(r: 0.9, n: 6, m: 3.0), 1.5),
  ("pie", sd-pie(aperture: 50deg, r: 0.9), 1.5),
  ("cut-disk", sd-cut-disk(r: 0.9, h: 0.3), 1.5),
  ("arc", sd-arc(aperture: 100deg, ra: 0.8, rb: 0.15), 1.5),
  ("ring", sd-ring(angle: 60deg, r: 0.8, th: 0.25), 1.5),
  ("horseshoe", sd-horseshoe(aperture: 60deg, r: 0.6, w: 0.3, h: 0.15), 1.5),
  ("vesica", sd-vesica(w: 0.9, h: 0.4), 1.5),
  ("oriented-vesica", sd-oriented-vesica(a: (-0.6, -0.5), b: (0.6, 0.5), w: 0.35), 1.5),
  ("moon", sd-moon(d: 0.5, ra: 0.8, rb: 0.7), 1.5),
  ("rounded-cross", sd-rounded-cross(h: 0.5), 2.2),
  ("egg", sd-egg(he: 0.4, ra: 0.5, rb: 0.2, bu: 0.6), 1.5),
  ("heart", sd-heart(), 2.0),
  ("cross", sd-cross(w: 0.8, h: 0.3, r: 0.1), 1.5),
  ("rounded-x", sd-rounded-x(w: 1.0, r: 0.2), 1.5),
  ("polygon", sd-polygon(v: ((-0.8, -0.5), (0.2, -0.8), (0.8, 0.1), (0.0, 0.8), (-0.3, 0.1))), 1.5),
  ("ellipse", sd-ellipse(a: 0.9, b: 0.5), 1.5),
  ("parabola", sd-parabola(k: 1.5), 1.5),
  ("parabola-segment", sd-parabola-segment(wi: 0.8, he: 0.8), 1.5),
  ("bezier", sd-bezier(A: (-0.8, -0.5), B: (0.0, 1.2), C: (0.8, -0.5)), 1.5),
  ("blobby-cross", sd-blobby-cross(he: 0.3), 1.2),
  ("tunnel", sd-tunnel(w: 0.6, h: 0.5), 1.5),
  ("stairs", sd-stairs(w: 0.35, h: 0.35, n: 4), 2.0),
  ("quadratic-circle", sd-quadratic-circle(), 1.5),
  ("hyperbola", sd-hyperbola(k: 0.15, he: 1.0), 1.5),
  ("cool-s", sd-cool-s(), 1.5),
  ("circle-wave", sd-circle-wave(tb: 0.6, ra: 0.5), 1.5),
)

= 2D SDF primitives (#shapes.len() shapes)

#grid(
  columns: 6,
  gutter: 4pt,
  align: center,
  ..shapes.map(((name, f, s)) => [
    #sdf-image(f, res: 110, bounds: (-s, -s, s, s), width: 100%)
    #name
  ]),
)
