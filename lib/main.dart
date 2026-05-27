import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/parallax.dart';
import 'package:flame/collisions.dart'; // FIXED: Added missing import for hitboxes
//import 'package:flame_audio/flame_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const PrimePlayFunApp(),
    ),
  );
}

// ================== PROVIDERS ==================
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final userProfileProvider = StateNotifierProvider<UserNotifier, UserProfile>((
  ref,
) {
  return UserNotifier(ref.watch(sharedPreferencesProvider));
});

class UserProfile {
  final int coins;
  final int totalScore;
  final int streak;
  final int highScore;

  UserProfile({
    this.coins = 150,
    this.totalScore = 0,
    this.streak = 3,
    this.highScore = 0,
  });

  UserProfile copyWith({
    int? coins,
    int? totalScore,
    int? streak,
    int? highScore,
  }) {
    return UserProfile(
      coins: coins ?? this.coins,
      totalScore: totalScore ?? this.totalScore,
      streak: streak ?? this.streak,
      highScore: highScore ?? this.highScore,
    );
  }
}

class UserNotifier extends StateNotifier<UserProfile> {
  final SharedPreferences _prefs;

  UserNotifier(this._prefs) : super(UserProfile()) {
    _loadData();
  }

  void _loadData() {
    state = state.copyWith(
      coins: _prefs.getInt('coins') ?? 150,
      highScore: _prefs.getInt('highScore') ?? 0,
    );
  }

  Future<void> _saveData() async {
    await _prefs.setInt('coins', state.coins);
    await _prefs.setInt('highScore', state.highScore);
  }

  void addCoins(int amount) {
    state = state.copyWith(coins: state.coins + amount);
    _saveData();
  }

  void addScore(int amount) {
    final newTotal = state.totalScore + amount;
    final newHigh = amount > state.highScore ? amount : state.highScore;
    state = state.copyWith(totalScore: newTotal, highScore: newHigh);
    _saveData();
  }
}

// ================== APP & ROUTER ==================
final GoRouter _router = GoRouter(
  initialLocation: '/lobby',
  routes: [
    GoRoute(path: '/lobby', builder: (_, __) => const LobbyScreen()),
    GoRoute(path: '/runner', builder: (_, __) => const RunnerScreen()),
  ],
);

class PrimePlayFunApp extends StatelessWidget {
  const PrimePlayFunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Prime Play Fun',
      theme: ThemeData(primarySwatch: Colors.pink, useMaterial3: true),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

// ================== LOBBY ==================
class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Prime Play Fun"),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () => _showWallet(context, ref),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome back!",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              "${user.streak} day streak",
              style: const TextStyle(fontSize: 19, color: Colors.orange),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${user.coins}",
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(" Coins", style: TextStyle(fontSize: 26)),
                ],
              ),
            ),

            const SizedBox(height: 40),
            const Text(
              "Games",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                leading: const Icon(
                  Icons.directions_run,
                  size: 68,
                  color: Colors.pink,
                ),
                title: const Text(
                  "Endless Runner",
                  style: TextStyle(fontSize: 22),
                ),
                subtitle: Text("Best Score: ${user.highScore}"),
                trailing: const Icon(Icons.play_arrow_rounded, size: 52),
                onTap: () => context.push('/runner'),
              ),
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 62,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => _claimDailyReward(context, ref),
                child: const Text(
                  "Claim Daily Reward (+50)",
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWallet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Shop",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(userProfileProvider.notifier).addCoins(500);
                Navigator.pop(context);
              },
              child: const Text("Buy 500 Coins"),
            ),
            const SizedBox(height: 16),
            const Text("Watch Ad for +50 Free Coins (Coming Soon)"),
          ],
        ),
      ),
    );
  }

  void _claimDailyReward(BuildContext context, WidgetRef ref) {
    ref.read(userProfileProvider.notifier).addCoins(50);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("+50 Coins added!")));
  }
}

// ================== GAME CORE ==================
class EndlessRunnerGame extends FlameGame
    with TapCallbacks, HasCollisionDetection {
  // FIXED: Replaced TapDetector with TapCallbacks
  final VoidCallback onGameOver;

  EndlessRunnerGame({required this.onGameOver});

  late Player player;
  late TextComponent scoreText;
  late TextComponent coinText;

  int score = 0;
  int coins = 0;
  double gameSpeed = 230;
  bool isGameOverFlag = false;
  final Random random = Random();

  @override
  Future<void> onLoad() async {
    //await FlameAudio.bgm.initialize();

    add(ParallaxBackground3D());
    add(Ground());

    player = Player();
    add(player);

    scoreText = TextComponent(
      text: 'Score: 0',
      position: Vector2(16, 16),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 28,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(scoreText);

    coinText = TextComponent(
      text: 'Coins: 0',
      position: Vector2(size.x - 160, 16),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 28,
          color: Colors.amber,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(coinText);

    add(TimerComponent(period: 1.25, repeat: true, onTick: _spawnObjects));
  }

  void _spawnObjects() {
    if (isGameOverFlag) return;
    add(Obstacle(gameSpeed));
    if (random.nextDouble() > 0.45) add(FlyingObstacle(gameSpeed));
    if (random.nextDouble() > 0.4) add(Collectible(gameSpeed));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isGameOverFlag) return;

    score += (dt * 25).toInt();
    gameSpeed += dt * 10;

    scoreText.text = "Score: $score";
  }

  @override
  void onTapDown(TapDownEvent event) {
    // FIXED: Swapped to modern signature from TapCallbacks
    super.onTapDown(event);
    if (!isGameOverFlag) player.jump();
  }

  void gameOver() {
    if (isGameOverFlag) return;
    isGameOverFlag = true;
    onGameOver();
  }

  void collectCoin() {
    coins++;
    coinText.text = "Coins: $coins";
  }

  void reset() {
    score = 0;
    coins = 0;
    gameSpeed = 230;
    isGameOverFlag = false;
    scoreText.text = "Score: 0";
    coinText.text = "Coins: 0";
    children.whereType<PositionComponent>().forEach((c) {
      if (c is Obstacle || c is FlyingObstacle || c is Collectible) {
        c.removeFromParent();
      }
    });
    player.position = Vector2(80, 220);
  }

  @override
  void onRemove() {
    //FlameAudio.bgm.stop();
    super.onRemove();
  }
}

// ================== COMPONENTS ==================

class ParallaxBackground3D extends ParallaxComponent<EndlessRunnerGame> {
  @override
  Future<void> onLoad() async {
    try {
      parallax = await game.loadParallax(
        [
          ParallaxImageData('bg_distant_mountains.png'),
          ParallaxImageData('bg_midground_trees.png'),
        ],
        baseVelocity: Vector2(20, 0),
        velocityMultiplierDelta: Vector2(1.8, 0),
      );
    } catch (_) {}
  }

  @override
  void render(Canvas canvas) {
    if (parallax == null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, game.size.x, game.size.y),
        Paint()..color = const Color(0xFF87CEEB),
      );
    } else {
      super.render(canvas);
    }
  }
}

class Ground extends PositionComponent
    with HasGameReference<EndlessRunnerGame> {
  @override
  Future<void> onLoad() async {
    size = Vector2(game.size.x, 120);
    position = Vector2(0, game.size.y - 120);
  }

  @override
  void render(Canvas canvas) =>
      canvas.drawRect(size.toRect(), Paint()..color = const Color(0xFF4CAF50));
}

class Player extends SpriteAnimationComponent
    with CollisionCallbacks, HasGameReference<EndlessRunnerGame> {
  double velocityY = 0;
  final double gravity = 1450;
  final double jumpForce = -590;
  bool isOnGround = true;

  Player() : super(size: Vector2(72, 72), position: Vector2(80, 220));

  void jump() {
    if (isOnGround) {
      velocityY = jumpForce;
      isOnGround = false;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    velocityY += gravity * dt;
    position.y += velocityY * dt;

    double groundY = game.size.y - 120 - size.y;
    if (position.y >= groundY) {
      position.y = groundY;
      velocityY = 0;
      isOnGround = true;
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    // FIXED: Renamed points -> intersectionPoints
    super.onCollision(intersectionPoints, other);
    if (other is Obstacle || other is FlyingObstacle) game.gameOver();
    if (other is Collectible) {
      if (!other.isRemoving) {
        other.removeFromParent();
        game.collectCoin();
      }
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }
}

class Obstacle extends PositionComponent
    with CollisionCallbacks, HasGameReference<EndlessRunnerGame> {
  final double speed;
  Obstacle(this.speed) : super(size: Vector2(52, 78));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2(game.size.x, game.size.y - 120 - size.y);
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    position.x -= speed * dt;
    if (position.x < -60) removeFromParent();
  }

  @override
  void render(Canvas canvas) =>
      canvas.drawRect(size.toRect(), Paint()..color = Colors.red[700]!);
}

class FlyingObstacle extends PositionComponent
    with CollisionCallbacks, HasGameReference<EndlessRunnerGame> {
  final double speed;
  FlyingObstacle(this.speed) : super(size: Vector2(58, 48));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2(
      game.size.x,
      (game.size.y - 240) + Random().nextDouble() * 90,
    );
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    position.x -= speed * dt * 1.15;
    if (position.x < -60) removeFromParent();
  }

  @override
  void render(Canvas canvas) =>
      canvas.drawRect(size.toRect(), Paint()..color = Colors.deepPurple);
}

class Collectible extends PositionComponent
    with CollisionCallbacks, HasGameReference<EndlessRunnerGame> {
  final double speed;
  Collectible(this.speed) : super(size: Vector2(42, 42));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2(
      game.size.x,
      (game.size.y - 260) + Random().nextDouble() * 120,
    );
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    position.x -= speed * dt * 0.9;
    if (position.x < -50) removeFromParent();
  }

  @override
  void render(Canvas canvas) => canvas.drawCircle(
    Offset(size.x / 2, size.y / 2),
    size.x / 2,
    Paint()..color = Colors.amber,
  );
}

// ================== RUNNER SCREEN ==================
class RunnerScreen extends ConsumerStatefulWidget {
  const RunnerScreen({super.key});
  @override
  ConsumerState<RunnerScreen> createState() => _RunnerScreenState();
}

class _RunnerScreenState extends ConsumerState<RunnerScreen> {
  late EndlessRunnerGame game;

  @override
  void initState() {
    super.initState();
    game = EndlessRunnerGame(
      onGameOver: () {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showGameOver());
      },
    );
  }

  void _showGameOver() {
    final notifier = ref.read(userProfileProvider.notifier);
    notifier.addScore(game.score);
    notifier.addCoins(game.coins);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Great Run! 🎮"),
        content: Text(
          "Score: ${game.score}\nCoins: ${game.coins}\nHigh Score: ${ref.watch(userProfileProvider).highScore}",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            child: const Text("Lobby"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              game.reset();
            },
            child: const Text("Play Again"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: GameWidget(game: game));
  }
}
