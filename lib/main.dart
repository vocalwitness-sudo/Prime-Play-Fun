import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame/collisions.dart';
import 'package:flame/particles.dart';
import 'package:flame/sprite.dart';

void main() {
  runApp(GameWidget(game: MyRunnerGame()));
}

// ==========================================
//                GAME ENGINE CORE
// ==========================================
// FIX 1: Updated to TapCallbacks and HasCollisionDetection
class MyRunnerGame extends FlameGame with TapCallbacks, HasCollisionDetection {
  late Player player;
  final double groundY = 400;
  final Random _random = Random();

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Blue-grey background color for the gameplay area
    add(
      RectangleComponent(size: size, paint: Paint()..color = Colors.blueGrey),
    );

    player = Player(groundY: groundY);
    add(player);

    add(Ground(groundY: groundY));
    add(Spawner());

    // Modern Flame Camera tracking setup
    camera.follow(player);
  }

  // FIX 2: Updated to use TapDownEvent instead of TapDownInfo to match TapCallbacks
  @override
  void onTapDown(TapDownEvent event) {
    player.jump();
  }

  // Camera juice/shake effect when collecting rare items
  void shakeScreen({double intensity = 18.0, double duration = 0.75}) {
    final originalPosition = camera.viewfinder.position.clone();

    final shakeSequence = SequenceEffect(
      List.generate(16, (index) {
        final progress = index / 15;
        final currentIntensity = intensity * (1 - progress * 0.85);

        final offsetX = (_random.nextDouble() - 0.5) * currentIntensity;
        final offsetY = (_random.nextDouble() - 0.5) * currentIntensity * 0.75;

        return MoveEffect.to(
          originalPosition + Vector2(offsetX, offsetY),
          EffectController(duration: duration / 16, curve: Curves.easeOutQuad),
        );
      }),
      onComplete: () {
        camera.viewfinder.add(
          MoveEffect.to(
            originalPosition,
            EffectController(duration: 0.12, curve: Curves.easeOut),
          ),
        );
      },
    );

    camera.viewfinder.add(shakeSequence);
  }
}

// ==========================================
//                PLAYER COMPONENT
// ==========================================
// FIX 3: Replaced deprecated HasGameRef with HasGameReference
class Player extends SpriteAnimationComponent
    with CollisionCallbacks, HasGameReference<MyRunnerGame> {
  final double groundY;
  double velocityY = 0;
  final double gravity = 850;
  final double normalJumpStrength = -520;
  final double phoenixJumpStrength = -680;

  double _currentJumpStrength = -520;
  bool isOnGround = true;
  bool isPhoenix = false;
  double phoenixTimeRemaining = 0;

  late SpriteAnimation runAnimation;
  late SpriteAnimation jumpAnimation;
  late SpriteAnimation phoenixAnimation;

  Player({required this.groundY})
    : super(
        size: Vector2(64, 64),
        position: Vector2(100, 0),
        anchor: Anchor.bottomLeft,
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Loads the multi-row animation sheet from assets/images/dash_spritesheet.png
    // FIX: Using game instead of gameRef
    final image = await game.images.load('dash_spritesheet.png');
    final spriteSheet = SpriteSheet.fromColumnsAndRows(
      image: image,
      columns: 8,
      rows: 3,
    );

    runAnimation = spriteSheet.createAnimation(
      row: 0,
      stepTime: 0.07,
      loop: true,
    );
    jumpAnimation = spriteSheet.createAnimation(
      row: 1,
      stepTime: 0.12,
      loop: false,
    );
    phoenixAnimation = spriteSheet.createAnimation(
      row: 2,
      stepTime: 0.08,
      loop: true,
    );

    animation = runAnimation;

    // Fixed Hitbox configuration syntax matching Flame bounds
    add(
      RectangleHitbox(
        size: Vector2(size.x * 0.65, size.y * 0.85),
        position: Vector2(size.x * 0.175, size.y * 0.075),
      ),
    );
  }

  void jump() {
    if (isOnGround) {
      velocityY = _currentJumpStrength;
      isOnGround = false;
      animation = isPhoenix ? phoenixAnimation : jumpAnimation;
    }
  }

  void activatePhoenix(double duration) {
    isPhoenix = true;
    phoenixTimeRemaining = duration;
    _currentJumpStrength = phoenixJumpStrength;
    animation = phoenixAnimation;

    _spawnPhoenixActivationParticles();
    game.shakeScreen(intensity: 16.0, duration: 0.7);
  }

  void _spawnPhoenixActivationParticles() {
    final rand = Random();
    final particleComponent = ParticleSystemComponent(
      particle: Particle.generate(
        count: 45,
        lifespan: 1.8,
        generator: (i) {
          final speed = rand.nextDouble() * 180 + 80;
          final angle = rand.nextDouble() * pi * 2;

          return AcceleratedParticle(
            position: position + Vector2(width / 2, -height / 3),
            speed: Vector2(cos(angle) * speed, sin(angle) * speed - 60),
            acceleration: Vector2(0, 120),
            child: CircleParticle(
              radius: rand.nextDouble() * 4 + 2.5,
              paint: Paint()
                ..color = [
                  Colors.orange,
                  Colors.deepOrange,
                  Colors.yellow,
                  const Color(0xFFFFA500),
                  Colors.redAccent,
                ][rand.nextInt(5)],
            ),
          );
        },
      ),
    );
    game.add(particleComponent);
  }

  void _deactivatePhoenix() {
    isPhoenix = false;
    phoenixTimeRemaining = 0;
    _currentJumpStrength = normalJumpStrength;
    animation = isOnGround ? runAnimation : jumpAnimation;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isPhoenix) {
      phoenixTimeRemaining -= dt;
      if (phoenixTimeRemaining <= 0) {
        _deactivatePhoenix();
      }
    }

    position.x += 260 * dt;
    velocityY += gravity * dt;
    position.y += velocityY * dt;

    if (position.y >= groundY) {
      position.y = groundY;
      velocityY = 0;

      if (!isOnGround) {
        isOnGround = true;
        animation = isPhoenix ? phoenixAnimation : runAnimation;
      }
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is Obstacle) {
      if (!isPhoenix) {
        game.pauseEngine();
      } else {
        other.removeFromParent();
      }
    } else if (other is Collectible) {
      other.removeFromParent();
    } else if (other is GoldenFeather) {
      other.removeFromParent();
      activatePhoenix(5.0);
    }
  }
}

// ==========================================
//         ENVIRONMENT & INTERACTABLES
// ==========================================
class Ground extends RectangleComponent {
  Ground({required double groundY})
    : super(
        size: Vector2(999999, 40),
        position: Vector2(0, groundY),
        paint: Paint()..color = Colors.green,
      );
}

class Obstacle extends RectangleComponent with CollisionCallbacks {
  Obstacle(Vector2 pos)
    : super(
        size: Vector2(40, 60),
        position: pos,
        paint: Paint()..color = Colors.red,
      ) {
    add(RectangleHitbox());
  }
}

class Collectible extends CircleComponent with CollisionCallbacks {
  Collectible(Vector2 pos)
    : super(radius: 15, position: pos, paint: Paint()..color = Colors.yellow) {
    add(CircleHitbox());
  }
}

// FIX 4: Replaced deprecated HasGameRef with HasGameReference
class GoldenFeather extends SpriteComponent
    with CollisionCallbacks, HasGameReference<MyRunnerGame> {
  GoldenFeather(Vector2 pos) : super(position: pos, size: Vector2(40, 40));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await game.loadSprite('golden_feather.png');
    add(CircleHitbox());
  }
}

// ==========================================
//                GAME SPAWNER
// ==========================================
// FIX 5: Replaced deprecated HasGameRef with HasGameReference
class Spawner extends Component with HasGameReference<MyRunnerGame> {
  double timer = 0;

  @override
  void update(double dt) {
    super.update(dt);
    timer += dt;
    if (timer > 2.2) {
      timer = 0;

      final rand = DateTime.now().millisecondsSinceEpoch % 6;
      final spawnX = game.player.position.x + game.size.x + 50;

      if (rand == 0) {
        game.add(GoldenFeather(Vector2(spawnX, game.groundY - 140)));
      } else if (rand == 1) {
        game.add(Collectible(Vector2(spawnX, game.groundY - 120)));
      } else {
        game.add(Obstacle(Vector2(spawnX, game.groundY - 60)));
      }
    }
  }
}
