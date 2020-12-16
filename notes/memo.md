# Camera2D following

### シンプルな方法 (問題点あり)

Player Node の子要素にする。
ただし、ゲームオーバーになったりして `exit_tree()` とか `queue_free()`したら、カメラも一緒に消えて
デフォルトカメラに切り替わってしまう

### スマートな方法

代わりに、 `RemoteTransform` を Player の子にする
position だけ適用する。
Camera2D 自体は World 直下に置く。

Player が消えたあとも、Camera2Dは残って、
位置はそのまま


# move_and_slide_with_snap()

`move_and_slide`でスロープの CollisionShape などを移動しようとすると、
滑ったり、最高点で飛び出してしまったり、スロープの途中で設置判定が消えたりする。

`move_and_slide_with_snap()`を使うことで、
伸ばした `snap_vector` の方向に Collision があれば
その衝突点まで body をスナップしたり、設置判定したりする。

この、`snap_vector` の照射開始点は、KinematicBody の position から
プレイヤーの足元を原点としておくと地面との距離計算がわかりやすい
例. `Vector.DOWN * 4 = 4px`

引数
- velocity
- snap_vector
- up_direction
- stop_on_slope: bool
- max_slide
- floor_max_angle : float (radian)
- infinite_inertia


### move_and_slide_with_snap でジャンプするときの注意点

`snap_vector` が 地面の `StaticBody` と衝突し続ける限り、その衝突点に `KinematicBody` が snap される。

つまり、ジャンプを行うには snap を無効にしないと行けない。
(飛び始めの時点で地面に snap され続けて上昇できない)

方法は2つ
- ジャンプしたフレームで、 snap_vector を `Vector2(0, 0)` にする。
  - 着地したときに`Vector2.DOWN`に戻す
- ジャンプ中だけ普通の `move_and_slide()` を使う。

前者で良さげ

### 坂で滑らないために

```gd
func apply_gravity(delta: float):
# Although not on floor, run properly
  if not self.is_on_floor():
    motion.y += GRAVITY * delta
    motion.y = min(motion.y, JUMP_FORCE)
```

床にいるときは重力を加算しないようにする。
これをしないと坂で滑る


# その他問題点
1. `stop_on_slope = true` にしても、 slope で止まらずに若干滑る
2. slope を登ると上方向の`motion.y`が蓄積されたままになる。
  - clif 崖から空中に行くと、少しジャンプする。
3. 下り坂を走ると、途中で坂からスナップが外れて空中判定になる
  - 坂を降りるときに `motion.x` が加算されて、snap_vector から坂が外れる


## 解決策



## 2: 空中に出る瞬間(snap_vector をゼロにするとき) に、ジャンプボタンを押したのかそうでないのかを判別する
  - `var just_jumped: bool` を用意
    - 毎フレーム
    - ジャンプボタンを押した瞬間に true
  - 崖から出た場合などは、`motion.y = 0` にする


```gd
func update_snap_vector():
  if is_on_floor():
    snap_vector = Vector2.DOWN

func move() -> void:
  var was_on_floor = self.is_on_floor()
  motion = move_and_slide_with_snap(motion, snap_vector * 4, Vector2.UP, true, 4, deg2rad(MAX_SLOPE_ANGLE))
  if was_on_floor and not is_on_floor() and not just_jumped:
    motion.y = 0

func _physics_process(delta: float):
  just_jumped = false
```

`move_and_slide/move_and_slide_with_snap` の実行前 / 実行後 で 
`KinematicBody.is_on_floor()`の実行結果が変わる。

実行前の設置判定を、 `var was_on_floor : bool` に取っておいて、
`was_on_floor and not is_on_floor()` が true なら、このフレームの移動で空中に出たと判定できる。

更に、 `not just_jumped` でこのフレームでジャンプボタンを押していないと判断できるので、
ジャンプにより空中判定になったわけではないとわかるので、`motion.y` を `0` にする。

## 3: 移動後の Landing 判定を行い、接地していたら最後の `motion.x` を継続する

エイリアスで `was_on_air: bool` とかがあるが気にしない。
`was_in_air and is_on_floor()` が true なら、このフレームの移動で着陸したと言える。
その場合は、`motion.x = last_motion.x` にする。
下り坂による加算がされないので、一定速度で坂を降りれる。


## 1: x方向の速度が限りなく小さい時、position.x を move_and_slide 前に戻す

少し hack の領域
`is_on_floor() and get_floor_velocity().length() == 0 and abs(motion.x) < 1`
- 設置している
- 床が移動してない
- 移動後の `motion.x` が限りなく小さい

この場合に、`position.x = last_position.x` に戻す。
slope の上に乗ってるときの微妙なスライドをなかったことにする。


```gd
func move() -> void:
  var was_in_air = not is_on_floor()
  var was_on_floor = is_on_floor()
  var last_position = position
  var last_motion = motion
  
  motion = move_and_slide_with_snap(motion, snap_vector * 4, Vector2.UP, true, 4, deg2rad(MAX_SLOPE_ANGLE))

  # Landing
  if was_in_air and is_on_floor():
    motion.x = last_motion.x
  
  # Just left ground
  if was_on_floor and not is_on_floor() and not just_jumped:
    motion.y = 0
    position.y = last_position.y
  
  # Prevent Sliding (hack)
  if is_on_floor() and get_floor_velocity().length() == 0 and abs(motion.x) < 1:
    position.x = last_position.x
```

# ポイント！

- `move_and_slide[_with_snap]()`の実行前/実行後で結果が変わる関数がある。
- 実行前の `position`, `motion`, `is_on_floor()` を変数に取っておいて、実行後と値が違うときに動作するコードを書こう！
  - その移動でちょうど 地上/空中 判定になった
  - `move_and_slide[_with_snap]`のせいで 微妙なフリッカーが発生する
    - 前の velocity / position に戻すことで、フリッカーをなかったコトにする。


