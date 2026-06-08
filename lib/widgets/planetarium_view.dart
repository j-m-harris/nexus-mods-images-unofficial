import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_scene/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;

import '../models/nexus_image.dart';
import '../services/gpu_texture_loader.dart';
import '../theme.dart';

/// A "planetarium" image browser: the viewer sits at the centre of a sphere
/// with images mounted on the inside surface. Dragging looks around; tapping an
/// image invokes [onImageTap].
///
/// Built on Flutter's native 3D stack (flutter_scene + flutter_gpu). One
/// textured quad ([PlaneGeometry] + [UnlitMaterial]) is created per image and
/// positioned on the sphere interior facing the centre. Textures are loaded
/// lazily from the network and swapped in when ready.
class PlanetariumView extends StatefulWidget {
  final List<NexusImage> images;
  final ValueChanged<NexusImage> onImageTap;

  /// Whether this view is currently on screen. The render loop only runs while
  /// active, so the GPU isn't driven when the feed is showing list/grid or the
  /// search tab is open.
  final bool active;

  const PlanetariumView({
    super.key,
    required this.images,
    required this.onImageTap,
    this.active = true,
  });

  @override
  State<PlanetariumView> createState() => _PlanetariumViewState();
}

/// One image placed on the sphere: its outward direction (unit vector from the
/// centre) and the material whose texture is filled in once loaded.
class _Placed {
  _Placed(this.image, this.direction, this.material);
  final NexusImage image;
  final vm.Vector3 direction;
  final UnlitMaterial material;
}

class _PlanetariumViewState extends State<PlanetariumView>
    with SingleTickerProviderStateMixin {
  // How many images to mount on the sphere at once (bounds GPU texture memory).
  static const int _capacity = 30;
  // Sphere radius and quad dimensions (16:9), in world units.
  static const double _radius = 6.0;
  static const double _quadWidth = 2.4;
  static const double _quadHeight = 2.4 * 9 / 16;
  static const double _fovRadians = 70 * pi / 180;
  static const double _dragSensitivity = 0.005;
  static const double _maxPitch = 85 * pi / 180;

  late final PerspectiveCamera _camera;
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  Ticker? _ticker;
  Scene? _scene;
  bool _ready = false;

  final List<_Placed> _placed = [];
  String _signature = '';

  double _yaw = 0; // rotation around the vertical axis
  double _pitch = 0; // look up / down

  // Cosine of the angular radius of a quad as seen from the centre, used as the
  // tap-selection threshold.
  static final double _selectCosThreshold =
      cos(atan(sqrt(pow(_quadWidth / 2, 2) + pow(_quadHeight / 2, 2)) / _radius));

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
    _buildSphere();
    Scene.initializeStaticResources().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _updateTicker();
    });
  }

  @override
  void didUpdateWidget(PlanetariumView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_signatureOf(widget.images) != _signature) {
      _buildSphere();
    }
    if (widget.active != oldWidget.active) {
      _updateTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _repaint.dispose();
    // Dropping references lets the native finalizer reclaim the GPU textures.
    _placed.clear();
    _scene = null;
    super.dispose();
  }

  String _signatureOf(List<NexusImage> images) {
    final n = min(images.length, _capacity);
    return '$n:${n == 0 ? '' : images.first.id}';
  }

  /// (Re)creates the scene graph from the current image set.
  void _buildSphere() {
    _signature = _signatureOf(widget.images);
    _placed.clear();
    final scene = Scene();
    final imgs = widget.images.take(_capacity).toList();
    for (var i = 0; i < imgs.length; i++) {
      final dir = _fibonacciDirection(i, imgs.length);
      final material = UnlitMaterial()..baseColorFactor = _placeholderColor;
      final mesh =
          Mesh(PlaneGeometry(width: _quadWidth, depth: _quadHeight), material);
      scene.add(Node(
        mesh: mesh,
        localTransform: _quadTransform(dir),
      ));
      _placed.add(_Placed(imgs[i], dir, material));
      _loadTexture(i, imgs[i]);
    }
    _scene = scene;
    if (mounted) setState(() {});
  }

  Future<void> _loadTexture(int index, NexusImage image) async {
    final gpu.Texture? texture = await loadGpuTexture(image.thumbnailUrl);
    if (!mounted || texture == null) return;
    // The sphere may have been rebuilt while loading; ignore stale results.
    if (index >= _placed.length || _placed[index].image.id != image.id) return;
    _placed[index].material
      ..baseColorTexture = texture
      ..baseColorFactor = vm.Vector4(1, 1, 1, 1);
  }

  void _onTick(Duration _) {
    _camera.target = _lookDirection();
    _repaint.value++;
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
  vm.Vector3 _lookDirection() {
    final cp = cos(_pitch);
    return vm.Vector3(cp * sin(_yaw), sin(_pitch), cp * cos(_yaw));
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _yaw -= details.delta.dx * _dragSensitivity;
    _pitch = (_pitch + details.delta.dy * _dragSensitivity)
        .clamp(-_maxPitch, _maxPitch);
  }

  /// Even point distribution over a sphere (Fibonacci lattice).
  vm.Vector3 _fibonacciDirection(int i, int count) {
    final golden = pi * (3 - sqrt(5));
    final y = count == 1 ? 0.0 : 1 - (i / (count - 1)) * 2; // 1 .. -1
    final r = sqrt(max(0.0, 1 - y * y));
    final theta = golden * i;
    return vm.Vector3(cos(theta) * r, y, sin(theta) * r);
  }

  /// Places a quad at `direction * radius`, oriented so it faces the viewer at
  /// the centre and the image reads upright.
  ///
  /// [PlaneGeometry] lies in its local X–Z plane with normal +Y; its texture
  /// `u` runs along +X and `v` (downward in image space) runs along +Z. So we
  /// map local axes as: +X → the viewer's right, +Y → the normal (toward the
  /// centre), and +Z → world-down (so the image's top edge points up). Flutter
  /// Scene flips the winding order for negative-determinant transforms, so the
  /// front face is never culled regardless of this basis's handedness.
  vm.Matrix4 _quadTransform(vm.Vector3 direction) {
    final pos = direction * _radius;
    final normal = -direction; // +Y face points back at the viewer
    final ref = direction.y.abs() > 0.99
        ? vm.Vector3(0, 0, 1)
        : vm.Vector3(0, 1, 0);
    // World "up" projected into the quad's plane.
    final upWorld = (ref - normal * ref.dot(normal)).normalized();
    final right = upWorld.cross(direction).normalized();
    return vm.Matrix4.identity()
      ..setColumn(0, vm.Vector4(right.x, right.y, right.z, 0))
      ..setColumn(1, vm.Vector4(normal.x, normal.y, normal.z, 0))
      ..setColumn(2, vm.Vector4(-upWorld.x, -upWorld.y, -upWorld.z, 0))
      ..setColumn(3, vm.Vector4(pos.x, pos.y, pos.z, 1));
  }

  void _onTapUp(TapUpDetails details, Size size) {
    final dir = _rayDirection(details.localPosition, size);
    var bestDot = -2.0;
    _Placed? best;
    for (final p in _placed) {
      final d = dir.dot(p.direction);
      if (d > bestDot) {
        bestDot = d;
        best = p;
      }
    }
    if (best != null && bestDot >= _selectCosThreshold) {
      widget.onImageTap(best.image);
    }
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
    return (forward +
            right * (ndcX * tanY * aspect) +
            up * (ndcY * tanY))
        .normalized();
  }

  static final vm.Vector4 _placeholderColor = vm.Vector4(
    ((NexusColors.imagePlaceholder.r * 255.0).round() & 0xff) / 255.0,
    ((NexusColors.imagePlaceholder.g * 255.0).round() & 0xff) / 255.0,
    ((NexusColors.imagePlaceholder.b * 255.0).round() & 0xff) / 255.0,
    1,
  );

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
