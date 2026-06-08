import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_scene/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;

import '../models/nexus_image.dart';
import '../services/gpu_texture_loader.dart';
import '../theme.dart';

/// A "planetarium" image browser: the viewer sits at the centre of a sphere and
/// looks at image tiles covering its interior. Drag to rotate your view in any
/// direction — there is a full sphere of images all around you.
///
/// ## A Goldberg polyhedron, not a lat/long grid
///
/// A lat/long grid laid out around a single vertical (polar) axis, like a
/// globe's lines of latitude and longitude, has a singularity at the poles and
/// tessellates very unevenly — cells pinch to nothing toward the poles. It also
/// makes vertical movement awkward: a vertical pan is a rotation about a
/// *horizontal* axis, which only lines up with the grid on the central meridian,
/// so cells away from it don't move cleanly.
///
/// Instead the sphere is tiled with a Goldberg polyhedron: mostly hexagons with
/// exactly 12 pentagons spread evenly around it (the shape of a football). It is
/// built as the *dual* of a geodesic icosphere — an icosahedron subdivided
/// [_subdivisions] times with its vertices projected onto the sphere. Each
/// icosphere vertex becomes one polygon face whose corners are the centroids of
/// the triangles around it: the 12 original valence-5 vertices give pentagons,
/// all the valence-6 vertices give hexagons. The result is `10·4^subdivisions +
/// 2` near-uniform faces with no special axis and no pole. Every face is drawn
/// in two layers — a line-coloured backing and a slightly inset image on top —
/// so a fine grid line shows around every tile.
///
/// ## Recycling viewport
///
/// The geometry is fixed; only the *content* recycles as you look around. A face
/// is filled with the next feed image when it rotates into view and has its
/// texture freed when it rotates out, so panning continuously pulls fresh images
/// (and pages the feed) while keeping only the visible tiles resident. When the
/// feed is exhausted the cursor wraps back to the first page and cycles.
///
/// Built on Flutter's native 3D stack (flutter_scene + flutter_gpu).
class PlanetariumView extends StatefulWidget {
  final List<NexusImage> images;
  final ValueChanged<NexusImage> onImageTap;

  /// Called when in-view faces need images the feed hasn't supplied yet. The
  /// host should load the next page; the new images get picked up as faces come
  /// into view. Only invoked while [canLoadMore] is true.
  final VoidCallback? onRequestMore;
  final bool canLoadMore;

  /// Whether this view is currently on screen. The render loop only runs while
  /// active, so the GPU isn't driven when the feed is showing list/grid or the
  /// search tab is open.
  final bool active;

  const PlanetariumView({
    super.key,
    required this.images,
    required this.onImageTap,
    this.onRequestMore,
    this.canLoadMore = false,
    this.active = true,
  });

  @override
  State<PlanetariumView> createState() => _PlanetariumViewState();
}

/// One fixed face of the Goldberg polyhedron (a hexagon, or one of the 12
/// pentagons). The geometry never moves; its content recycles based on whether
/// the face is in view. [center] is the unit world direction to the face centre
/// (tap hit-testing / view tests). [texAngles] are the per-corner angles around
/// the centre, used to lay the image out radially over the triangle fan. Only
/// the image layer is tracked here; the backing line layer never changes.
class _Cell {
  _Cell(this.geometry, this.material, this.center, this.texAngles);
  final MeshGeometry geometry; // the (inset) image layer
  final UnlitMaterial material;
  final vm.Vector3 center;
  final List<double> texAngles;

  NexusImage? image;
  gpu.Texture? texture;
  double imageAspect = 1;
  bool assigned = false;
  bool loading = false;
  bool failed = false;
  double? fadeStartMs; // when the texture was applied, for the fade-in
}

class _PlanetariumViewState extends State<PlanetariumView>
    with SingleTickerProviderStateMixin {
  // Icosphere subdivision level behind the dual. The sphere holds
  // 10·4^_subdivisions + 2 faces (always 12 pentagons, the rest hexagons):
  // 1 → 42 (classic football), 2 → 162 (default), 3 → 642 (dense). Higher means
  // smaller tiles and more on screen, at the cost of more textures/draw calls.
  static const int _subdivisions = 2;
  static const double _radius = 6.0;
  static const double _fovRadians = 80 * pi / 180;
  static const double _dragSensitivity = 0.005;
  // Look up/down is clamped just short of straight up/down so the look-at's
  // fixed up-vector never becomes parallel to the view direction.
  static const double _maxPitch = 80 * pi / 180;
  // How far each tile's image is pulled in from its face edge (fraction of the
  // way to the centre), revealing the backing layer as a fine grid line; and how
  // much the image layer is lifted toward the viewer so it sits in front of the
  // line layer without z-fighting. Kept small so the lines stay hairline.
  static const double _tileInset = 0.02;
  static const double _tileLift = 0.01;
  // Loading feedback: a face waiting for its texture pulses its fill toward the
  // highlight colour over this period (by this fraction); once the texture
  // arrives it fades in (brightness ramp) over this duration.
  static const double _pulsePeriodMs = 900;
  static const double _pulseAmount = 0.5;
  static const Duration _fadeIn = Duration(milliseconds: 350);
  // A face is filled once its centre comes within _loadAngle of the look
  // direction, and cleared once it passes _clearAngle. The gap between them is
  // hysteresis, so a face near the edge of view doesn't flicker load/clear.
  static final double _loadCos = cos(70 * pi / 180);
  static final double _clearCos = cos(95 * pi / 180);

  late final PerspectiveCamera _camera;
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  // Set whenever something that affects the rendered frame changes (camera pan
  // or a texture/fill swap). The ticker keeps running so it can read pan input
  // and recycle tiles, but it only re-renders the scene when this is set —
  // otherwise an idle view would drive the GPU every frame for nothing. Starts
  // true so the first frame paints.
  bool _dirty = true;
  Ticker? _ticker;
  Scene? _scene;
  bool _ready = false;

  final List<_Cell> _cells = []; // every face, for iteration
  int _nextImage = 0; // next feed image to hand to a face rotating into view
  Duration _elapsed = Duration.zero; // ticker time, drives pulse / fade
  gpu.Texture? _blankTexture; // overwrites an image when a tile is cleared
  String? _lastFirstId;
  int _lastLen = 0;

  // Camera orientation. Yaw is unbounded (it wraps naturally through sin/cos);
  // pitch is clamped to ±_maxPitch.
  double _yaw = 0; // look left / right (around the vertical axis)
  double _pitch = 0; // look up / down

  @override
  void initState() {
    super.initState();
    _camera = PerspectiveCamera(
      fovRadiansY: _fovRadians,
      position: vm.Vector3.zero(),
      target: _lookDirection(),
      up: vm.Vector3(0, 1, 0),
    );
    _ticker = createTicker(_onTick);
    _buildGrid();
    _lastFirstId = widget.images.isEmpty ? null : widget.images.first.id;
    _lastLen = widget.images.length;
    _buildBlankTexture();
    Scene.initializeStaticResources().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _updateTicker();
    });
  }

  @override
  void didUpdateWidget(PlanetariumView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset content only when the feed is replaced (search / refresh), detected
    // by the first id changing or the list shrinking. Plain pagination (the list
    // growing) just feeds the recycler more images, picked up as tiles recycle.
    final firstId = widget.images.isEmpty ? null : widget.images.first.id;
    if (firstId != _lastFirstId || widget.images.length < _lastLen) {
      _nextImage = 0;
      for (final cell in _cells) {
        _clear(cell);
      }
    }
    _lastFirstId = firstId;
    _lastLen = widget.images.length;
    if (widget.active != oldWidget.active) _updateTicker();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _repaint.dispose();
    // Dropping references lets the native finalizer reclaim the GPU textures.
    _cells.clear();
    _scene = null;
    _blankTexture = null;
    super.dispose();
  }

  /// Unit world direction for a given elevation [phi] (0 at the equator, + up)
  /// and azimuth [az] (0 straight ahead, +z).
  vm.Vector3 _dir(double phi, double az) {
    final cp = cos(phi);
    return vm.Vector3(cp * sin(az), sin(phi), cp * cos(az));
  }

  /// Builds the fixed Goldberg sphere once: subdivide an icosahedron into an
  /// icosphere, then take its dual — one polygon face per icosphere vertex,
  /// cornered at the centroids of the triangles around that vertex. Each face is
  /// added as two layers: a full-size line-coloured backing and a slightly inset
  /// image layer in front, so a grid line shows around every tile.
  void _buildGrid() {
    final scene = Scene();
    _cells.clear();

    // 1. Icosphere with shared (indexed) vertices, so we know which triangles
    //    meet at each vertex.
    final t = (1 + sqrt(5)) / 2;
    vm.Vector3 nv(double x, double y, double z) =>
        vm.Vector3(x, y, z).normalized();
    final verts = <vm.Vector3>[
      nv(-1, t, 0), nv(1, t, 0), nv(-1, -t, 0), nv(1, -t, 0), //
      nv(0, -1, t), nv(0, 1, t), nv(0, -1, -t), nv(0, 1, -t), //
      nv(t, 0, -1), nv(t, 0, 1), nv(-t, 0, -1), nv(-t, 0, 1),
    ];
    var faces = <List<int>>[
      [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], //
      [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8], //
      [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], //
      [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
    ];
    for (var s = 0; s < _subdivisions; s++) {
      final cache = <int, int>{};
      int mid(int i, int j) {
        final key = i < j ? i * 1000000 + j : j * 1000000 + i;
        final cached = cache[key];
        if (cached != null) return cached;
        verts.add(((verts[i] + verts[j]) * 0.5).normalized());
        return cache[key] = verts.length - 1;
      }

      final next = <List<int>>[];
      for (final f in faces) {
        final ab = mid(f[0], f[1]), bc = mid(f[1], f[2]), ca = mid(f[2], f[0]);
        next.add([f[0], ab, ca]);
        next.add([f[1], bc, ab]);
        next.add([f[2], ca, bc]);
        next.add([ab, bc, ca]);
      }
      faces = next;
    }

    // 2. Triangle centroids (= dual vertices) and the triangles meeting at each
    //    icosphere vertex.
    final centroids = [
      for (final f in faces)
        ((verts[f[0]] + verts[f[1]] + verts[f[2]]) / 3).normalized(),
    ];
    final incident = List.generate(verts.length, (_) => <int>[]);
    for (var fi = 0; fi < faces.length; fi++) {
      for (final vi in faces[fi]) {
        incident[vi].add(fi);
      }
    }

    // 3. One dual face per icosphere vertex.
    for (var vi = 0; vi < verts.length; vi++) {
      final n = verts[vi];
      // Tangent basis at the face centre, with tx pointing "up" (world +Y
      // projected onto the tangent plane) so images sit roughly upright. Near
      // the poles +Y is parallel to n, so fall back to +X.
      final ref = n.y.abs() < 0.99 ? vm.Vector3(0, 1, 0) : vm.Vector3(1, 0, 0);
      final tx = (ref - n * ref.dot(n)).normalized();
      final ty = n.cross(tx).normalized();
      final corners = [
        for (final fi in incident[vi])
          (
            angle: atan2(centroids[fi].dot(ty), centroids[fi].dot(tx)),
            dir: centroids[fi],
          ),
      ]..sort((a, b) => a.angle.compareTo(b.angle));

      final dirs = [for (final c in corners) c.dir];
      final angles = [for (final c in corners) c.angle];

      // Backing line layer: full-size, solid line colour, never changes.
      final lineGeo = _buildFan(
          n, dirs, _radius, 0, Float32List((dirs.length + 1) * 2));
      scene.add(Node(
          mesh: Mesh(lineGeo, UnlitMaterial()..baseColorFactor = _lineColor)));

      // Image layer: inset and lifted toward the viewer, so the line layer peeks
      // around it as a grid line.
      final imgGeo = _buildFan(n, dirs, _radius * (1 - _tileLift), _tileInset,
          _faceTexCoords(1, angles));
      final imgMat = UnlitMaterial()..baseColorFactor = _fillColor;
      scene.add(Node(mesh: Mesh(imgGeo, imgMat)));
      _cells.add(_Cell(imgGeo, imgMat, n, angles));
    }

    _scene = scene;
  }

  /// One polygon face as a triangle fan from its [center] out to its [corners]
  /// (unit directions, ordered), at [radius]. Corners are pulled [inset] of the
  /// way toward the centre (0 = none). Drawn double-sided so it is never
  /// back-face culled — we view every face from inside, i.e. from behind its
  /// outward front.
  MeshGeometry _buildFan(vm.Vector3 center, List<vm.Vector3> corners,
      double radius, double inset, Float32List texCoords) {
    final k = corners.length;
    final positions = Float32List((k + 1) * 3);
    positions[0] = center.x * radius;
    positions[1] = center.y * radius;
    positions[2] = center.z * radius;
    for (var i = 0; i < k; i++) {
      var d = corners[i];
      if (inset > 0) d = (corners[i] + (center - corners[i]) * inset).normalized();
      positions[(i + 1) * 3] = d.x * radius;
      positions[(i + 1) * 3 + 1] = d.y * radius;
      positions[(i + 1) * 3 + 2] = d.z * radius;
    }
    final indices = <int>[];
    for (var i = 0; i < k; i++) {
      final b = 1 + i, c = 1 + (i + 1) % k;
      indices.addAll([0, b, c, 0, c, b]); // fan triangle + reverse
    }
    return MeshGeometry.fromArrays(
      positions: positions,
      texCoords: texCoords,
      indices: indices,
      storage: GeometryStorage.updatable,
    );
  }

  /// A tiny solid-white texture used to overwrite a face's image when it is
  /// cleared (tinted back to the fill colour by [baseColorFactor]).
  Future<void> _buildBlankTexture() async {
    final px = Uint8List(2 * 2 * 4)..fillRange(0, 2 * 2 * 4, 255);
    final image = await _decodeRgba(px, 2, 2);
    final texture = await gpuTextureFromImage(image);
    if (!mounted) return;
    _blankTexture = texture;
    for (final cell in _cells) {
      if (cell.texture == null) _setFill(cell);
    }
  }

  Future<ui.Image> _decodeRgba(Uint8List pixels, int w, int h) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        pixels, w, h, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  /// Radial texture coordinates for a face's fan (centre vertex + one per
  /// corner). The image is cropped to a centred square (so non-square images
  /// aren't stretched) and the polygon is mapped to the inscribed circle, with
  /// each corner placed at its own angle. `u` is mirrored because each face is
  /// viewed from inside the sphere — i.e. from behind its front.
  Float32List _faceTexCoords(double imageAspect, List<double> angles) {
    var halfU = 0.5, halfV = 0.5;
    if (imageAspect >= 1) {
      halfU = 1 / (2 * imageAspect);
    } else {
      halfV = imageAspect / 2;
    }
    final tex = Float32List((angles.length + 1) * 2);
    tex[0] = 0.5; // centre vertex → image centre
    tex[1] = 0.5;
    var k = 2;
    for (final a in angles) {
      // angle 0 is tangent-up → image top; mirror u for the from-behind view.
      tex[k++] = 0.5 - halfU * sin(a);
      tex[k++] = 0.5 - halfV * cos(a);
    }
    return tex;
  }

  /// Shows a face's empty fill (no image): the blank texture tinted to the fill
  /// colour, leaving the grid line visible around it.
  void _setFill(_Cell cell) {
    _dirty = true;
    final blank = _blankTexture;
    if (blank != null) {
      cell.material
        ..baseColorTexture = blank
        ..baseColorFactor = _fillColor;
    } else {
      cell.material.baseColorFactor = _fillColor;
    }
    cell.geometry.updateTexCoords(_faceTexCoords(1, cell.texAngles));
  }

  /// Applies a face's loaded image texture, cropped square so it fills the
  /// polygon undistorted. Starts dim; [_animate] fades it up to full brightness.
  void _applyImage(_Cell cell) {
    _dirty = true;
    final tex = cell.texture;
    if (tex == null) {
      _setFill(cell);
      return;
    }
    cell.material
      ..baseColorTexture = tex
      ..baseColorFactor = vm.Vector4(0.15, 0.15, 0.15, 1);
    cell.fadeStartMs = _elapsed.inMilliseconds.toDouble();
    cell.geometry.updateTexCoords(_faceTexCoords(cell.imageAspect, cell.texAngles));
  }

  /// Each tick: fill faces that have rotated into view (paging / wrapping the
  /// feed as needed) and clear faces that have rotated out.
  void _recycle() {
    final look = _lookDirection();
    final imgs = widget.images;
    var needPage = false;
    for (final cell in _cells) {
      final d = look.dot(cell.center);
      if (d >= _loadCos) {
        if (!cell.assigned) {
          if (imgs.isEmpty) {
            needPage = true;
          } else if (_nextImage >= imgs.length) {
            // Reached the end of the loaded feed: pull the next page if there is
            // one, otherwise wrap back to the first page and cycle.
            if (widget.canLoadMore) {
              needPage = true; // fill on a later tick, once the page arrives
            } else {
              _nextImage = 0;
              _assignTo(cell, imgs[_nextImage++]);
            }
          } else {
            _assignTo(cell, imgs[_nextImage++]);
          }
        }
        if (cell.assigned &&
            cell.texture == null &&
            !cell.loading &&
            !cell.failed) {
          _loadCellTexture(cell);
        }
      } else if (d < _clearCos && cell.assigned) {
        _clear(cell);
      }
    }
    if (needPage && widget.canLoadMore) widget.onRequestMore?.call();
  }

  void _assignTo(_Cell cell, NexusImage image) {
    cell.image = image;
    cell.assigned = true;
    cell.loading = false;
    cell.failed = false;
    cell.fadeStartMs = null;
    _setFill(cell); // pulses (see _animate) until the texture loads
  }

  /// Frees a face's texture and unassigns it, so it pulls a fresh image the next
  /// time it rotates into view.
  void _clear(_Cell cell) {
    cell.assigned = false;
    cell.image = null;
    cell.texture = null;
    cell.loading = false;
    cell.failed = false;
    cell.fadeStartMs = null;
    _setFill(cell);
  }

  Future<void> _loadCellTexture(_Cell cell) async {
    final image = cell.image;
    if (image == null) return;
    cell.loading = true;
    final result = await loadGpuTexture(image.thumbnailUrl, maxWidth: 384);
    if (!mounted) return;
    // Ignore if the face was cleared / reassigned while the texture loaded.
    if (cell.image?.id != image.id) return;
    cell.loading = false;
    if (result == null) {
      cell.failed = true; // don't hammer a broken URL every tick
      _setFill(cell); // stop pulsing; settle on the static fill
      return;
    }
    cell.texture = result.texture;
    cell.imageAspect = result.aspect;
    _applyImage(cell);
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
    _camera.target = _lookDirection();
    _recycle();
    final animating = _animate();
    // Re-render when the frame changed (pan / recycle) or something is still
    // animating; otherwise an idle, fully-loaded view skips the GPU work.
    if (_dirty || animating) _repaint.value++;
    _dirty = false;
  }

  /// Drives per-face loading feedback: faces waiting for a texture pulse toward
  /// the highlight colour, and freshly-loaded faces fade up to full brightness.
  /// Returns whether any face is still animating (so the tick keeps repainting).
  bool _animate() {
    final nowMs = _elapsed.inMilliseconds.toDouble();
    final pulse = (0.5 - 0.5 * cos(nowMs * 2 * pi / _pulsePeriodMs)) *
        _pulseAmount;
    var animating = false;
    for (final cell in _cells) {
      if (cell.assigned && cell.texture == null && !cell.failed) {
        // Waiting for its texture: pulse the fill toward the highlight.
        cell.material.baseColorFactor = _lerpVec(_fillColor, _pulseColor, pulse);
        animating = true;
      } else if (cell.fadeStartMs != null) {
        final t = (nowMs - cell.fadeStartMs!) / _fadeIn.inMilliseconds;
        if (t >= 1) {
          cell.material.baseColorFactor = _white;
          cell.fadeStartMs = null;
        } else {
          final s = 0.15 + 0.85 * (t < 0 ? 0.0 : t);
          cell.material.baseColorFactor = vm.Vector4(s, s, s, 1);
          animating = true;
        }
      }
    }
    return animating;
  }

  void _updateTicker() {
    final ticker = _ticker;
    if (ticker == null) return;
    final shouldRun = _ready && widget.active;
    if (shouldRun && !ticker.isActive) {
      ticker.start();
    } else if (!shouldRun && ticker.isActive) {
      ticker.stop();
    }
  }

  /// World-space direction the camera is looking, from yaw/pitch. The camera
  /// sits at the origin, so this doubles as its `target`.
  vm.Vector3 _lookDirection() => _dir(_pitch, _yaw);

  void _onPanUpdate(DragUpdateDetails details) {
    _yaw -= details.delta.dx * _dragSensitivity;
    _pitch = (_pitch + details.delta.dy * _dragSensitivity)
        .clamp(-_maxPitch, _maxPitch);
    _dirty = true;
  }

  void _onTapUp(TapUpDetails details, Size size) {
    if (_cells.isEmpty) return;
    final dir = _rayDirection(details.localPosition, size);
    // The tapped face is simply the one whose centre the ray points closest to.
    _Cell? best;
    var bestDot = -2.0;
    for (final cell in _cells) {
      final d = dir.dot(cell.center);
      if (d > bestDot) {
        bestDot = d;
        best = cell;
      }
    }
    final image = best?.image;
    if (image != null) widget.onImageTap(image);
  }

  /// World-space ray direction for a tapped pixel, reconstructed from the
  /// camera basis (matches flutter_scene's look-at convention).
  vm.Vector3 _rayDirection(Offset point, Size size) {
    final ndcX = (point.dx / size.width) * 2 - 1;
    final ndcY = 1 - (point.dy / size.height) * 2;
    final tanY = tan(_fovRadians * 0.5);
    final aspect = size.width / size.height;
    final forward = _lookDirection();
    final right = vm.Vector3(0, 1, 0).cross(forward).normalized();
    final up = forward.cross(right).normalized();
    return (forward + right * (ndcX * tanY * aspect) + up * (ndcY * tanY))
        .normalized();
  }

  static vm.Vector4 _toVec4(Color c) => vm.Vector4(c.r, c.g, c.b, 1);
  static vm.Vector4 _lerpVec(vm.Vector4 a, vm.Vector4 b, double t) =>
      vm.Vector4(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t,
          a.z + (b.z - a.z) * t, 1);
  static final vm.Vector4 _fillColor = _toVec4(NexusColors.imagePlaceholder);
  static final vm.Vector4 _lineColor = _toVec4(NexusColors.border);
  static final vm.Vector4 _pulseColor = _toVec4(NexusColors.primary);
  static final vm.Vector4 _white = vm.Vector4(1, 1, 1, 1);

  @override
  Widget build(BuildContext context) {
    final scene = _scene;
    return ColoredBox(
      color: NexusColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: _onPanUpdate,
            onTapUp: (details) => _onTapUp(details, size),
            child: CustomPaint(
              size: Size.infinite,
              painter: scene == null
                  ? null
                  : _ScenePainter(scene, _camera, _repaint),
            ),
          );
        },
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene, this.camera, Listenable repaint)
      : super(repaint: repaint);

  final Scene scene;
  final Camera camera;

  @override
  void paint(Canvas canvas, Size size) {
    scene.render(camera, canvas, viewport: Offset.zero & size);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.scene != scene || oldDelegate.camera != camera;
}
