// Self-check: an exact SDF satisfies the eikonal equation |grad f| = 1
// everywhere except on its medial axis (a measure-zero crease set). Central-
// difference every shape on a grid and require the median to be ~1 and the
// bulk of samples to be within 5%. Catches dropped terms and sign slips.
//
//   typst compile check.typ /dev/null   # passes silently, errors on regression

#import "eikonal.typ": *

#let eikonal(f, s: 1.5, n: 41) = {
  let eps = 2 * s / 2000
  let gs = ()
  for j in range(n) {
    let y = -s + 2 * s * (j + 0.5) / n
    for i in range(n) {
      let x = -s + 2 * s * (i + 0.5) / n
      let gx = (f(x + eps, y) - f(x - eps, y)) / (2 * eps)
      let gy = (f(x, y + eps) - f(x, y - eps)) / (2 * eps)
      gs.push(calc.sqrt(gx * gx + gy * gy))
    }
  }
  let gs = gs.sorted()
  (
    median: gs.at(int(gs.len() / 2)),
    good: gs.filter(g => calc.abs(g - 1) < 0.05).len() / gs.len(),
  )
}

#let shapes = (
  ("circle", sd-circle(r: 0.8)),
  ("rounded-box", sd-rounded-box(w: 0.8, h: 0.5, r: (0.4, 0.05, 0.2, 0.1))),
  ("chamfer-box", sd-chamfer-box(w: 0.7, h: 0.5, chamfer: 0.3)),
  ("box", sd-box(w: 0.8, h: 0.5)),
  ("oriented-box", sd-oriented-box(a: (-0.7, -0.4), b: (0.7, 0.4), th: 0.4)),
  ("segment", sd-segment(a: (-0.7, -0.4), b: (0.7, 0.4), r: 0.15)),
  ("rhombus", sd-rhombus(w: 0.8, h: 0.5)),
  ("trapezoid", sd-trapezoid(r1: 0.8, r2: 0.4, he: 0.6)),
  ("parallelogram", sd-parallelogram(wi: 0.5, he: 0.5, sk: 0.4)),
  ("equilateral-tri", sd-equilateral-triangle(r: 0.7)),
  ("isosceles-tri", sd-triangle-isosceles(w: 0.6, he: -0.9)),
  ("triangle", sd-triangle(p0: (-0.8, -0.5), p1: (0.7, -0.7), p2: (0.1, 0.8))),
  ("uneven-capsule", sd-uneven-capsule(r1: 0.5, r2: 0.15, h: 0.8)),
  ("pentagon", sd-pentagon(r: 0.8)),
  ("hexagon", sd-hexagon(r: 0.8)),
  ("octogon", sd-octogon(r: 0.8)),
  ("hexagram", sd-hexagram(r: 0.5)),
  ("pentagram", sd-pentagram(r: 0.8)),
  ("star", sd-star(r: 0.9, n: 6, m: 3.0)),
  ("pie", sd-pie(aperture: 50deg, r: 0.9)),
  ("cut-disk", sd-cut-disk(r: 0.9, h: 0.3)),
  ("arc", sd-arc(aperture: 100deg, ra: 0.8, rb: 0.15)),
  ("ring", sd-ring(angle: 60deg, r: 0.8, th: 0.25)),
  ("horseshoe", sd-horseshoe(aperture: 60deg, r: 0.6, w: 0.3, h: 0.15)),
  ("vesica", sd-vesica(w: 0.9, h: 0.4)),
  ("oriented-vesica", sd-oriented-vesica(a: (-0.6, -0.5), b: (0.6, 0.5), w: 0.35)),
  ("moon", sd-moon(d: 0.5, ra: 0.8, rb: 0.7)),
  ("rounded-cross", sd-rounded-cross(h: 0.5)),
  ("egg", sd-egg(he: 0.4, ra: 0.5, rb: 0.2, bu: 0.6)),
  ("heart", sd-heart()),
  ("rounded-x", sd-rounded-x(w: 1.0, r: 0.2)),
  ("polygon", sd-polygon(v: ((-0.8, -0.5), (0.2, -0.8), (0.8, 0.1), (0.0, 0.8), (-0.3, 0.1)))),
  ("ellipse", sd-ellipse(a: 0.9, b: 0.5)),
  ("parabola", sd-parabola(k: 1.5)),
  ("parabola-segment", sd-parabola-segment(wi: 0.8, he: 0.8)),
  ("bezier", sd-bezier(A: (-0.8, -0.5), B: (0.0, 1.2), C: (0.8, -0.5))),
  ("blobby-cross", sd-blobby-cross(he: 0.3)),
  ("tunnel", sd-tunnel(w: 0.6, h: 0.5)),
  ("stairs", sd-stairs(w: 0.35, h: 0.35, n: 4)),
  ("quadratic-circle", sd-quadratic-circle()),
  ("hyperbola", sd-hyperbola(k: 0.15, he: 1.0)),
  ("cool-s", sd-cool-s()),
  ("circle-wave", sd-circle-wave(tb: 0.6, ra: 0.5)),
)

#let rows = shapes.map(((name, f)) => (name, eikonal(f)))

#table(
  columns: 3,
  [*shape*], [*median |grad|*], [*% within 5%*],
  ..rows
    .map(((name, r)) => (
      name,
      str(calc.round(r.median, digits: 4)),
      str(calc.round(r.good * 100, digits: 1)),
    ))
    .flatten(),
)

#for (name, r) in rows {
  assert(calc.abs(r.median - 1) < 0.01, message: name + ": median |grad| = " + str(r.median))
  assert(r.good > 0.85, message: name + ": only " + str(r.good * 100) + "% eikonal")
}
