// 2D signed distance functions, ported from
// https://iquilezles.org/articles/distfunctions2d/  (Inigo Quilez, MIT).
//
// An SDF here is a closure (x, y) -> signed distance. Shape constructors are
// curried: `sd-circle(r: 0.5)` returns that closure, so shapes compose with the
// operators below and drop straight into `sdf-image`.

// --- safe math -------------------------------------------------------------
// GLSL quietly returns NaN/inf for these; Typst raises a hard compile error,
// which would abort the whole document over one bad pixel. Clamp instead.

#let _sqrt(x) = calc.sqrt(calc.max(x, 0.0))
#let _acos(x) = calc.acos(calc.clamp(x, -1.0, 1.0)).rad()
#let _div(a, b) = a / (if b == 0 { 1e-300 } else { b })
#let _cbrt(x) = if x < 0 { -calc.pow(-x, 1.0 / 3.0) } else { calc.pow(x, 1.0 / 3.0) }
#let _sign(x) = if x > 0 { 1.0 } else if x < 0 { -1.0 } else { 0.0 }
#let _mod(x, m) = x - m * calc.floor(_div(x, m)) // GLSL mod: floor-based, not calc.rem
#let _dot2(x, y) = x * x + y * y
#let _len(x, y) = calc.sqrt(x * x + y * y)

#let smoothstep(e0, e1, x) = {
  let t = calc.clamp(_div(x - e0, e1 - e0), 0.0, 1.0)
  t * t * (3 - 2 * t)
}

// --- primitives ------------------------------------------------------------

#let sd-circle(r: 1) = (x, y) => _len(x, y) - r

// r: one radius, or (top-right, bottom-right, top-left, bottom-left)
#let sd-rounded-box(w: 1, h: 1, r: 0.2) = {
  let r = if type(r) == array { r } else { (r,) * 4 }
  (x, y) => {
    let (a, b) = if x > 0 { (r.at(0), r.at(1)) } else { (r.at(2), r.at(3)) }
    let k = if y > 0 { a } else { b }
    let qx = calc.abs(x) - w + k
    let qy = calc.abs(y) - h + k
    calc.min(calc.max(qx, qy), 0.0) + _len(calc.max(qx, 0.0), calc.max(qy, 0.0)) - k
  }
}

#let sd-chamfer-box(w: 1, h: 1, chamfer: 0.2) = (x, y) => {
  let ax = calc.abs(x) - w
  let ay = calc.abs(y) - h
  let (px, py) = if ay > ax { (ay, ax) } else { (ax, ay) }
  let py = py + chamfer
  let k = 1.0 - calc.sqrt(2.0)
  if py < 0 and py + px * k < 0 { px } else if px < py {
    (px + py) * calc.sqrt(0.5)
  } else { _len(px, py) }
}

#let sd-box(w: 1, h: 1) = (x, y) => {
  let dx = calc.abs(x) - w
  let dy = calc.abs(y) - h
  _len(calc.max(dx, 0.0), calc.max(dy, 0.0)) + calc.min(calc.max(dx, dy), 0.0)
}

#let sd-oriented-box(a: (0, 0), b: (1, 0), th: 0.2) = {
  let ((ax, ay), (bx, by)) = (a, b)
  let l = _len(bx - ax, by - ay)
  let (dx, dy) = (_div(bx - ax, l), _div(by - ay, l))
  (x, y) => {
    let (ux, uy) = (x - (ax + bx) * 0.5, y - (ay + by) * 0.5)
    let qx = calc.abs(dx * ux + dy * uy) - l * 0.5
    let qy = calc.abs(-dy * ux + dx * uy) - th * 0.5
    _len(calc.max(qx, 0.0), calc.max(qy, 0.0)) + calc.min(calc.max(qx, qy), 0.0)
  }
}

#let sd-segment(a: (0, 0), b: (1, 0), r: 0) = {
  let ((ax, ay), (bx, by)) = (a, b)
  let (ex, ey) = (bx - ax, by - ay)
  let ee = _dot2(ex, ey)
  (x, y) => {
    let (px, py) = (x - ax, y - ay)
    let h = calc.clamp(_div(px * ex + py * ey, ee), 0.0, 1.0)
    _len(px - ex * h, py - ey * h) - r
  }
}

#let sd-rhombus(w: 1, h: 1) = (x, y) => {
  let (bx, by) = (w, -h)
  let (px, py) = (calc.abs(x), calc.abs(y))
  let h = calc.clamp(_div(bx * px + by * py + by * by, _dot2(bx, by)), 0.0, 1.0)
  let (qx, qy) = (px - bx * h, py - by * (h - 1))
  _len(qx, qy) * _sign(qx)
}

#let sd-trapezoid(r1: 1, r2: 0.6, he: 1) = (x, y) => {
  let (k1x, k1y) = (r2, he)
  let (k2x, k2y) = (r2 - r1, 2.0 * he)
  let px = calc.abs(x)
  let cax = px - calc.min(px, if y < 0 { r1 } else { r2 })
  let cay = calc.abs(y) - he
  let t = calc.clamp(
    _div((k1x - px) * k2x + (k1y - y) * k2y, _dot2(k2x, k2y)),
    0.0,
    1.0,
  )
  let cbx = px - k1x + k2x * t
  let cby = y - k1y + k2y * t
  let s = if cbx < 0 and cay < 0 { -1.0 } else { 1.0 }
  s * _sqrt(calc.min(_dot2(cax, cay), _dot2(cbx, cby)))
}

#let sd-parallelogram(wi: 1, he: 1, sk: 0.5) = (x, y) => {
  let (ex, ey) = (sk, he)
  let (px, py) = if y < 0 { (-x, -y) } else { (x, y) }
  let wx = px - ex - calc.clamp(px - ex, -wi, wi)
  let wy = py - ey
  let (d0, d1) = (_dot2(wx, wy), -wy)
  let s = px * ey - py * ex
  let (qx, qy) = if s < 0 { (-px, -py) } else { (px, py) }
  let t = calc.clamp(_div((qx - wi) * ex + qy * ey, _dot2(ex, ey)), -1.0, 1.0)
  let (vx, vy) = (qx - wi - ex * t, qy - ey * t)
  let d0 = calc.min(d0, _dot2(vx, vy))
  let d1 = calc.min(d1, wi * he - calc.abs(s))
  _sqrt(d0) * _sign(-d1)
}

#let sd-equilateral-triangle(r: 1) = (x, y) => {
  let k = calc.sqrt(3.0)
  let ax = calc.abs(x) - r
  let ay = y + _div(r, k)
  let (px, py) = if ax + k * ay > 0 {
    ((ax - k * ay) / 2.0, (-k * ax - ay) / 2.0)
  } else { (ax, ay) }
  let px = px - calc.clamp(px, -2.0 * r, 0.0)
  -_len(px, py) * _sign(py)
}

#let sd-triangle-isosceles(w: 0.6, he: 1) = (x, y) => {
  let (qx, qy) = (w, he)
  let px = calc.abs(x)
  let t = calc.clamp(_div(px * qx + y * qy, _dot2(qx, qy)), 0.0, 1.0)
  let (ax, ay) = (px - qx * t, y - qy * t)
  let (bx, by) = (px - qx * calc.clamp(_div(px, qx), 0.0, 1.0), y - qy)
  let s = -_sign(qy)
  let d0 = calc.min(_dot2(ax, ay), _dot2(bx, by))
  let d1 = calc.min(s * (px * qy - y * qx), s * (y - qy))
  -_sqrt(d0) * _sign(d1)
}

#let sd-triangle(p0: (-1, -0.6), p1: (1, -0.6), p2: (0, 1)) = {
  let ((p0x, p0y), (p1x, p1y), (p2x, p2y)) = (p0, p1, p2)
  let (e0x, e0y) = (p1x - p0x, p1y - p0y)
  let (e1x, e1y) = (p2x - p1x, p2y - p1y)
  let (e2x, e2y) = (p0x - p2x, p0y - p2y)
  let s = _sign(e0x * e2y - e0y * e2x)
  (x, y) => {
    let (v0x, v0y) = (x - p0x, y - p0y)
    let (v1x, v1y) = (x - p1x, y - p1y)
    let (v2x, v2y) = (x - p2x, y - p2y)
    let t0 = calc.clamp(_div(v0x * e0x + v0y * e0y, _dot2(e0x, e0y)), 0.0, 1.0)
    let t1 = calc.clamp(_div(v1x * e1x + v1y * e1y, _dot2(e1x, e1y)), 0.0, 1.0)
    let t2 = calc.clamp(_div(v2x * e2x + v2y * e2y, _dot2(e2x, e2y)), 0.0, 1.0)
    let d0 = calc.min(
      _dot2(v0x - e0x * t0, v0y - e0y * t0),
      _dot2(v1x - e1x * t1, v1y - e1y * t1),
      _dot2(v2x - e2x * t2, v2y - e2y * t2),
    )
    let d1 = calc.min(
      s * (v0x * e0y - v0y * e0x),
      s * (v1x * e1y - v1y * e1x),
      s * (v2x * e2y - v2y * e2x),
    )
    -_sqrt(d0) * _sign(d1)
  }
}

#let sd-uneven-capsule(r1: 0.4, r2: 0.15, h: 1) = (x, y) => {
  let px = calc.abs(x)
  let b = _div(r1 - r2, h)
  let a = _sqrt(1.0 - b * b)
  let k = px * -b + y * a
  if k < 0 { _len(px, y) - r1 } else if k > a * h {
    _len(px, y - h) - r2
  } else { px * a + y * b - r1 }
}

#let sd-pentagon(r: 1) = (x, y) => {
  let (kx, ky, kz) = (0.809016994, 0.587785252, 0.726542528)
  let (px, py) = (calc.abs(x), y)
  let d = 2.0 * calc.min(px * -kx + py * ky, 0.0)
  let (px, py) = (px - d * -kx, py - d * ky)
  let d = 2.0 * calc.min(px * kx + py * ky, 0.0)
  let (px, py) = (px - d * kx, py - d * ky)
  _len(px - calc.clamp(px, -r * kz, r * kz), py - r) * _sign(py - r)
}

#let sd-hexagon(r: 1) = (x, y) => {
  let (kx, ky, kz) = (-0.866025404, 0.5, 0.577350269)
  let (px, py) = (calc.abs(x), calc.abs(y))
  let d = 2.0 * calc.min(px * kx + py * ky, 0.0)
  let (px, py) = (px - d * kx, py - d * ky)
  _len(px - calc.clamp(px, -kz * r, kz * r), py - r) * _sign(py - r)
}

#let sd-octogon(r: 1) = (x, y) => {
  let (kx, ky, kz) = (-0.9238795325, 0.3826834323, 0.4142135623)
  let (px, py) = (calc.abs(x), calc.abs(y))
  let d = 2.0 * calc.min(px * kx + py * ky, 0.0)
  let (px, py) = (px - d * kx, py - d * ky)
  let d = 2.0 * calc.min(px * -kx + py * ky, 0.0)
  let (px, py) = (px - d * -kx, py - d * ky)
  _len(px - calc.clamp(px, -kz * r, kz * r), py - r) * _sign(py - r)
}

#let sd-hexagram(r: 1) = (x, y) => {
  let (kx, ky, kz, kw) = (-0.5, 0.8660254038, 0.5773502692, 1.7320508076)
  let (px, py) = (calc.abs(x), calc.abs(y))
  let d = 2.0 * calc.min(px * kx + py * ky, 0.0)
  let (px, py) = (px - d * kx, py - d * ky)
  let d = 2.0 * calc.min(px * ky + py * kx, 0.0)
  let (px, py) = (px - d * ky, py - d * kx)
  _len(px - calc.clamp(px, r * kz, r * kw), py - r) * _sign(py - r)
}

#let sd-pentagram(r: 1) = (x, y) => {
  let (k1x, k1y, k1z) = (0.809016994, 0.587785252, 0.726542528)
  let (k2x, k2y) = (0.309016994, 0.951056516)
  let (v1x, v1y) = (k1x, -k1y)
  let (v2x, v2y) = (-k1x, -k1y)
  let (v3x, v3y) = (k2x, -k2y)
  let (px, py) = (calc.abs(x), y)
  let d = 2.0 * calc.max(px * v1x + py * v1y, 0.0)
  let (px, py) = (px - d * v1x, py - d * v1y)
  let d = 2.0 * calc.max(px * v2x + py * v2y, 0.0)
  let (px, py) = (px - d * v2x, py - d * v2y)
  let (px, py) = (calc.abs(px), py - r)
  let t = calc.clamp(px * v3x + py * v3y, 0.0, k1z * r)
  _len(px - v3x * t, py - v3y * t) * _sign(py * v3x - px * v3y)
}

// n: number of points, m: sharpness, between 2 and n
#let sd-star(r: 1, n: 5, m: 3.0) = {
  let an = _div(calc.pi, n)
  let en = _div(calc.pi, m)
  let (acx, acy) = (calc.cos(an), calc.sin(an))
  let (ecx, ecy) = (calc.cos(en), calc.sin(en))
  (x, y) => {
    let bn = _mod(calc.atan2(y, x).rad(), 2.0 * an) - an
    let l = _len(x, y)
    let (px, py) = (l * calc.cos(bn) - r * acx, l * calc.abs(calc.sin(bn)) - r * acy)
    let t = calc.clamp(-(px * ecx + py * ecy), 0.0, _div(r * acy, ecy))
    _len(px + ecx * t, py + ecy * t) * _sign(px + ecx * t)
  }
}

#let sd-pie(aperture: 45deg, r: 1) = {
  let (cx, cy) = (calc.sin(aperture), calc.cos(aperture))
  (x, y) => {
    let px = calc.abs(x)
    let l = _len(px, y) - r
    let t = calc.clamp(px * cx + y * cy, 0.0, r)
    let m = _len(px - cx * t, y - cy * t)
    calc.max(l, m * _sign(cy * px - cx * y))
  }
}

#let sd-cut-disk(r: 1, h: 0.3) = {
  let w = _sqrt(r * r - h * h)
  (x, y) => {
    let px = calc.abs(x)
    let s = calc.max((h - r) * px * px + w * w * (h + r - 2.0 * y), h * px - w * y)
    if s < 0 { _len(px, y) - r } else if px < w { h - y } else { _len(px - w, y - h) }
  }
}

#let sd-arc(aperture: 60deg, ra: 1, rb: 0.1) = {
  let (scx, scy) = (calc.sin(aperture), calc.cos(aperture))
  (x, y) => {
    let px = calc.abs(x)
    let d = if scy * px > scx * y {
      _len(px - scx * ra, y - scy * ra)
    } else { calc.abs(_len(px, y) - ra) }
    d - rb
  }
}

#let sd-ring(angle: 60deg, r: 1, th: 0.2) = {
  let (nx, ny) = (calc.cos(angle), calc.sin(angle))
  (x, y) => {
    let ax = calc.abs(x)
    let (px, py) = (nx * ax - ny * y, ny * ax + nx * y)
    calc.max(
      calc.abs(_len(px, py) - r) - th * 0.5,
      _len(px, calc.max(0.0, calc.abs(r - py) - th * 0.5)) * _sign(px),
    )
  }
}

#let sd-horseshoe(aperture: 60deg, r: 1, w: 0.3, h: 0.2) = {
  let (cx, cy) = (calc.cos(aperture), calc.sin(aperture))
  (x, y) => {
    let ax = calc.abs(x)
    let l = _len(ax, y)
    let (mx, my) = (-cx * ax + cy * y, cy * ax + cx * y)
    let px = if my > 0 or mx > 0 { mx } else { l * _sign(-cx) }
    let py = if mx > 0 { my } else { l }
    let (qx, qy) = (px - w, calc.abs(py - r) - h)
    _len(calc.max(qx, 0.0), calc.max(qy, 0.0)) + calc.min(0.0, calc.max(qx, qy))
  }
}

#let sd-vesica(w: 1, h: 0.6) = {
  let d = _div(0.5 * (w * w - h * h), h)
  (x, y) => {
    let (px, py) = (calc.abs(x), calc.abs(y))
    if w * py < d * (px - w) { _len(px - w, py) } else { _len(px, py + d) - (d + h) }
  }
}

#let sd-oriented-vesica(a: (0, -1), b: (0, 1), w: 0.5) = {
  let ((ax, ay), (bx, by)) = (a, b)
  let r = 0.5 * _len(bx - ax, by - ay)
  let d = _div(0.5 * (r * r - w * w), w)
  let (vx, vy) = (_div(bx - ax, r), _div(by - ay, r))
  let (cx, cy) = ((bx + ax) * 0.5, (by + ay) * 0.5)
  (x, y) => {
    let (ux, uy) = (x - cx, y - cy)
    let (qx, qy) = (0.5 * calc.abs(vy * ux - vx * uy), 0.5 * calc.abs(vx * ux + vy * uy))
    if r * qx < d * (qy - r) { _len(qx, qy - r) } else { _len(qx + d, qy) - (d + w) }
  }
}

#let sd-moon(d: 0.5, ra: 1, rb: 0.8) = {
  let a = _div(ra * ra - rb * rb + d * d, 2.0 * d)
  let b = _sqrt(ra * ra - a * a)
  (x, y) => {
    let py = calc.abs(y)
    if d * (x * b - py * a) > d * d * calc.max(b - py, 0.0) {
      _len(x - a, py - b)
    } else {
      calc.max(_len(x, py) - ra, -(_len(x - d, py) - rb))
    }
  }
}

#let sd-rounded-cross(h: 0.5) = {
  let k = 0.5 * (h + _div(1.0, h))
  (x, y) => {
    let (px, py) = (calc.abs(x), calc.abs(y))
    if px < 1 and py < px * (k - h) + h {
      k - _sqrt(_dot2(px - 1, py - k))
    } else {
      _sqrt(calc.min(_dot2(px, py - h), _dot2(px - 1, py)))
    }
  }
}

#let sd-egg(he: 0.5, ra: 0.5, rb: 0.2, bu: 1) = {
  let r = _div(0.5 * (he + ra + rb), bu)
  let (da, db) = (r - ra, r - rb)
  let cy = _div(db * db - da * da - he * he, 2.0 * he)
  let cx = _sqrt(da * da - cy * cy)
  (x, y) => {
    let px = calc.abs(x)
    let k = y * cx - px * cy
    if k > 0 and k < he * (px + cx) {
      _len(px + cx, y + cy) - r
    } else {
      calc.min(_len(px, y) - ra, _len(px, y - he) - rb)
    }
  }
}

#let sd-heart() = (x, y) => {
  let px = calc.abs(x)
  if y + px > 1.0 {
    _sqrt(_dot2(px - 0.25, y - 0.75)) - calc.sqrt(2.0) / 4.0
  } else {
    let s = 0.5 * calc.max(px + y, 0.0)
    _sqrt(calc.min(_dot2(px, y - 1.0), _dot2(px - s, y - s))) * _sign(px - y)
  }
}

// exact exterior, bound interior
#let sd-cross(w: 1, h: 0.3, r: 0) = (x, y) => {
  let (ax, ay) = (calc.abs(x), calc.abs(y))
  let (px, py) = if ay > ax { (ay, ax) } else { (ax, ay) }
  let (qx, qy) = (px - w, py - h)
  let k = calc.max(qy, qx)
  let (wx, wy) = if k > 0 { (qx, qy) } else { (h - px, -k) }
  _sign(k) * _len(calc.max(wx, 0.0), calc.max(wy, 0.0)) + r
}

#let sd-rounded-x(w: 1, r: 0.2) = (x, y) => {
  let (px, py) = (calc.abs(x), calc.abs(y))
  let s = calc.min(px + py, w) * 0.5
  _len(px - s, py - s) - r
}

#let sd-polygon(v: ((-1, -1), (1, -1), (0, 1))) = (x, y) => {
  let n = v.len()
  let d = _dot2(x - v.at(0).at(0), y - v.at(0).at(1))
  let s = 1.0
  let j = n - 1
  for i in range(n) {
    let ((vix, viy), (vjx, vjy)) = (v.at(i), v.at(j))
    let (ex, ey) = (vjx - vix, vjy - viy)
    let (wx, wy) = (x - vix, y - viy)
    let t = calc.clamp(_div(wx * ex + wy * ey, _dot2(ex, ey)), 0.0, 1.0)
    d = calc.min(d, _dot2(wx - ex * t, wy - ey * t))
    let (c0, c1, c2) = (y >= viy, y < vjy, ex * wy > ey * wx)
    if (c0 and c1 and c2) or not (c0 or c1 or c2) { s *= -1.0 }
    j = i
  }
  s * _sqrt(d)
}

#let sd-ellipse(a: 1, b: 0.6) = (x, y) => {
  let (px, py) = (calc.abs(x), calc.abs(y))
  let (px, py, ax, by) = if px > py { (py, px, b, a) } else { (px, py, a, b) }
  let l = by * by - ax * ax
  let m = _div(ax * px, l)
  let n = _div(by * py, l)
  let (m2, n2) = (m * m, n * n)
  let c = (m2 + n2 - 1.0) / 3.0
  let c3 = c * c * c
  let q = c3 + m2 * n2 * 2.0
  let d = c3 + m2 * n2
  let g = m + m * n2
  let co = if d < 0 {
    let h = _acos(_div(q, c3)) / 3.0
    let s = calc.cos(h)
    let t = calc.sin(h) * calc.sqrt(3.0)
    let rx = _sqrt(-c * (s + t + 2.0) + m2)
    let ry = _sqrt(-c * (s - t + 2.0) + m2)
    (ry + _sign(l) * rx + _div(calc.abs(g), rx * ry) - m) / 2.0
  } else {
    let h = 2.0 * m * n * _sqrt(d)
    let s = _sign(q + h) * _cbrt(calc.abs(q + h))
    let u = _sign(q - h) * _cbrt(calc.abs(q - h))
    let rx = -s - u - c * 4.0 + 2.0 * m2
    let ry = (s - u) * calc.sqrt(3.0)
    let rm = _len(rx, ry)
    (_div(ry, _sqrt(rm - rx)) + _div(2.0 * g, rm) - m) / 2.0
  }
  let (rx, ry) = (ax * co, by * _sqrt(1.0 - co * co))
  _len(rx - px, ry - py) * _sign(py - ry)
}

// y = k x^2
#let sd-parabola(k: 1) = (x, y) => {
  let px = calc.abs(x)
  let ik = _div(1.0, k)
  let p = ik * (y - 0.5 * ik) / 3.0
  let q = 0.25 * ik * ik * px
  let h = q * q - p * p * p
  let t = if h > 0 {
    let r = _cbrt(q + _sqrt(h))
    r + _div(p, r)
  } else {
    let r = _sqrt(p)
    2.0 * r * calc.cos(_acos(_div(q, p * r)) / 3.0)
  }
  _len(px - t, y - k * t * t) * _sign(px - t)
}

#let sd-parabola-segment(wi: 1, he: 1) = (x, y) => {
  let px = calc.abs(x)
  let ik = _div(wi * wi, he)
  let p = ik * (he - y - 0.5 * ik) / 3.0
  let q = px * ik * ik / 4.0
  let h = q * q - p * p * p
  let t = if h > 0 {
    let r = _cbrt(q + _sqrt(h))
    r + _div(p, r)
  } else {
    let r = _sqrt(p)
    2.0 * r * calc.cos(_acos(_div(q, p * r)) / 3.0)
  }
  let t = calc.min(t, wi)
  _len(px - t, y - (he - _div(t * t, ik))) * _sign(ik * (y - he) + px * px)
}

#let sd-bezier(A: (-1, 0), B: (0, 1), C: (1, 0)) = {
  let ((Ax, Ay), (Bx, By), (Cx, Cy)) = (A, B, C)
  let (ax, ay) = (Bx - Ax, By - Ay)
  let (bx, by) = (Ax - 2.0 * Bx + Cx, Ay - 2.0 * By + Cy)
  let (cx, cy) = (ax * 2.0, ay * 2.0)
  let kk = _div(1.0, _dot2(bx, by))
  (x, y) => {
    let (dx, dy) = (Ax - x, Ay - y)
    let kx = kk * (ax * bx + ay * by)
    let ky = kk * (2.0 * _dot2(ax, ay) + (dx * bx + dy * by)) / 3.0
    let kz = kk * (dx * ax + dy * ay)
    let p = ky - kx * kx
    let q = kx * (2.0 * kx * kx - 3.0 * ky) + kz
    let h = q * q + 4.0 * p * p * p
    let at = (t) => _dot2(dx + (cx + bx * t) * t, dy + (cy + by * t) * t)
    let res = if h >= 0 {
      let h = calc.sqrt(h)
      let u = _sign((h - q) / 2.0) * _cbrt(calc.abs((h - q) / 2.0))
      let v = _sign((-h - q) / 2.0) * _cbrt(calc.abs((-h - q) / 2.0))
      at(calc.clamp(u + v - kx, 0.0, 1.0))
    } else {
      let z = _sqrt(-p)
      let v = _acos(_div(q, p * z * 2.0)) / 3.0
      let m = calc.cos(v)
      let n = calc.sin(v) * 1.732050808
      // the third root can never be the closest
      calc.min(
        at(calc.clamp((m + m) * z - kx, 0.0, 1.0)),
        at(calc.clamp((-n - m) * z - kx, 0.0, 1.0)),
      )
    }
    _sqrt(res)
  }
}

#let sd-blobby-cross(he: 0.3) = (x, y) => {
  let (ax, ay) = (calc.abs(x), calc.abs(y))
  let r2 = calc.sqrt(2.0)
  let (px, py) = (_div(calc.abs(ax - ay), r2), _div(1.0 - ax - ay, r2))
  let p = _div(he - py - _div(0.25, he), 6.0 * he)
  let q = _div(px, he * he * 16.0)
  let h = q * q - p * p * p
  let t = if h > 0 {
    let r = calc.sqrt(h)
    _cbrt(q + r) - _cbrt(calc.abs(q - r)) * _sign(r - q)
  } else {
    let r = _sqrt(p)
    2.0 * r * calc.cos(_acos(_div(q, p * r)) / 3.0)
  }
  let t = calc.min(t, r2 / 2.0)
  let (zx, zy) = (t - px, he * (1.0 - 2.0 * t * t) - py)
  _len(zx, zy) * _sign(zy)
}

#let sd-tunnel(w: 0.6, h: 0.8) = (x, y) => {
  let (px, py) = (calc.abs(x), -y)
  let (qx, qy) = (px - w, py - h)
  let d1 = _dot2(calc.max(qx, 0.0), qy)
  let qx = if py > 0 { qx } else { _len(px, py) - w }
  let d2 = _dot2(qx, calc.max(qy, 0.0))
  let d = _sqrt(calc.min(d1, d2))
  if calc.max(qx, qy) < 0 { -d } else { d }
}

#let sd-stairs(w: 0.3, h: 0.3, n: 4) = (x, y) => {
  let (bax, bay) = (w * n, h * n)
  let d = calc.min(
    _dot2(x - calc.clamp(x, 0.0, bax), y),
    _dot2(x - bax, y - calc.clamp(y, 0.0, bay)),
  )
  let s = _sign(calc.max(-y, x - bax))
  let dia = _len(w, h)
  let (px, py) = (_div(w * x + h * y, dia), _div(-h * x + w * y, dia))
  let id = calc.clamp(calc.round(_div(px, dia)), 0.0, n - 1.0)
  let px = px - id * dia
  let (px, py) = (_div(w * px - h * py, dia), _div(h * px + w * py, dia))
  let hh = h / 2.0
  let py = py - hh
  let s = if py > hh * _sign(px) { 1.0 } else { s }
  let (px, py) = if id < 0.5 or px > 0 { (px, py) } else { (-px, -py) }
  let d = calc.min(d, _dot2(px, py - calc.clamp(py, -hh, hh)))
  let d = calc.min(d, _dot2(px - calc.clamp(px, 0.0, w), py - hh))
  _sqrt(d) * s
}

#let sd-quadratic-circle() = (x, y) => {
  let (ax, ay) = (calc.abs(x), calc.abs(y))
  let (px, py) = if ay > ax { (ay, ax) } else { (ax, ay) }
  let a = px - py
  let b = px + py
  let c = (2.0 * b - 1.0) / 3.0
  let h = a * a + c * c * c
  let t = if h >= 0 {
    let h = calc.sqrt(h)
    _sign(h - a) * _cbrt(calc.abs(h - a)) - _cbrt(h + a)
  } else {
    let z = _sqrt(-c)
    let v = _acos(_div(a, c * z)) / 3.0
    -z * (calc.cos(v) + calc.sin(v) * 1.732050808)
  }
  let t = t * 0.5
  let k = 0.75 - t * t
  _len(-t + k - px, t + k - py) * _sign(a * a * 0.5 + b - 1.5)
}

#let sd-hyperbola(k: 0.2, he: 1) = (x, y) => {
  let (ax, ay) = (calc.abs(x), calc.abs(y))
  let r2 = calc.sqrt(2.0)
  let (px, py) = ((ax - ay) / r2, (ax + ay) / r2)
  let x2 = px * px / 16.0
  let y2 = py * py / 16.0
  let r = k * (4.0 * k - px * py) / 12.0
  let q = (x2 - y2) * k * k
  let h = q * q + r * r * r
  let u = if h < 0 {
    let m = _sqrt(-r)
    m * calc.cos(_acos(_div(q, r * m)) / 3.0)
  } else {
    let m = _cbrt(calc.sqrt(h) - q)
    (m - _div(r, m)) / 2.0
  }
  let w = _sqrt(u + x2)
  let b = k * py - x2 * px * 2.0
  let t = px / 4.0 - w + _sqrt(2.0 * x2 - u + _div(b, w) / 4.0)
  let t = calc.max(t, _sqrt(he * he * 0.5 + k) - he / r2)
  let d = _len(px - t, py - _div(k, t))
  if px * py < k { d } else { -d }
}

#let sd-cool-s() = (x, y) => {
  let six = if y < 0 { -x } else { x }
  let px = calc.abs(x)
  let py = calc.abs(y) - 0.2
  let rex = px - calc.min(calc.round(_div(px, 0.4)), 0.4)
  let aby = calc.abs(py - 0.2) - 0.6
  let c1 = calc.clamp(0.5 * (six - py), 0.0, 0.2)
  let d = _dot2(six - c1, -py - c1)
  let c2 = calc.clamp(0.5 * (px - aby), 0.0, 0.4)
  let d = calc.min(d, _dot2(px - c2, -aby - c2))
  let d = calc.min(d, _dot2(rex, py - calc.clamp(py, 0.0, 0.4)))
  let s = 2.0 * px + aby + calc.abs(aby + 0.4) - 0.4
  _sqrt(d) * _sign(s)
}

#let sd-circle-wave(tb: 0.5, ra: 0.5) = {
  let tb = calc.pi * 5.0 / 6.0 * calc.max(tb, 0.0001)
  let (cox, coy) = (ra * calc.sin(tb), ra * calc.cos(tb))
  (x, y) => {
    let px = calc.abs(_mod(x, cox * 4.0) - cox * 2.0)
    let d1 = if coy * px > cox * y {
      _len(px - cox, y - coy)
    } else { calc.abs(_len(px, y) - ra) }
    let (p2x, p2y) = (calc.abs(px - 2.0 * cox), -y + 2.0 * coy)
    let d2 = if coy * p2x > cox * p2y {
      _len(p2x - cox, p2y - coy)
    } else { calc.abs(_len(p2x, p2y) - ra) }
    calc.min(d1, d2)
  }
}

// --- operators -------------------------------------------------------------

#let op-union(..fs) = (x, y) => calc.min(..fs.pos().map(f => f(x, y)))
#let op-intersect(..fs) = (x, y) => calc.max(..fs.pos().map(f => f(x, y)))
#let op-subtract(a, b) = (x, y) => calc.max(a(x, y), -b(x, y))

#let op-smooth-union(a, b, k: 0.1) = (x, y) => {
  let (da, db) = (a(x, y), b(x, y))
  let h = calc.clamp(0.5 + 0.5 * _div(db - da, k), 0.0, 1.0)
  db * (1 - h) + da * h - k * h * (1 - h)
}

#let op-translate(f, dx: 0, dy: 0) = (x, y) => f(x - dx, y - dy)
#let op-rotate(f, angle) = {
  let (c, s) = (calc.cos(angle), calc.sin(angle))
  (x, y) => f(c * x + s * y, -s * x + c * y)
}
#let op-scale(f, k) = (x, y) => f(_div(x, k), _div(y, k)) * k
#let op-round(f, r) = (x, y) => f(x, y) - r
#let op-onion(f, r) = (x, y) => calc.abs(f(x, y)) - r

// --- colouring -------------------------------------------------------------

// The iq palette: warm outside, cool inside, exponential falloff,
// iso-distance ripples, white zero-contour.
#let iq-palette(band: 150, line: 0.01) = d => {
  let base = if d > 0 { (0.9, 0.6, 0.3) } else { (0.65, 0.85, 1.0) }
  let m = (1 - calc.exp(-6 * calc.abs(d))) * (0.8 + 0.2 * calc.cos(band * d))
  let w = 1 - smoothstep(0, line, calc.abs(d))
  base.map(c => c * m * (1 - w) + w)
}

// --- render ----------------------------------------------------------------

#let sdf-image(
  f,
  res: 256,
  bounds: (-1.5, -1.5, 1.5, 1.5),
  palette: iq-palette(),
  ..args,
) = {
  let (x0, y0, x1, y1) = bounds
  let w = res
  let h = int(calc.round(res * (y1 - y0) / (x1 - x0)))
  let px = ()
  for j in range(h) {
    let y = y1 - (y1 - y0) * (j + 0.5) / h
    for i in range(w) {
      let x = x0 + (x1 - x0) * (i + 0.5) / w
      for c in palette(f(x, y)) {
        px.push(calc.clamp(int(c * 255 + 0.5), 0, 255))
      }
    }
  }
  image(bytes(px), format: (encoding: "rgb8", width: w, height: h), ..args)
}
