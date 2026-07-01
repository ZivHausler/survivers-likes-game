extends SceneTree
## DEV HARNESS ONLY — headless ENet loopback smoke test for NetworkManager (Task C1).
## Not part of the game; do not wire this into normal gameplay flow.
##
## Run with:
##   godot47 --headless -s res://tools/net_smoke.gd -- host
##   godot47 --headless -s res://tools/net_smoke.gd -- join
##
## Hosts or joins an ENet loopback session, prints the lobby registry every time it
## changes, then quits on its own after ~4 seconds.

var _role: String = ""
var _elapsed: float = 0.0
var _net  # NetworkManager autoload, fetched via get_node (see note below)
var _started := false

func _initialize() -> void:
	# NOTE: can't reference the `NetworkManager` autoload identifier directly here —
	# when a script overrides the main loop via `-s`, it is compiled before Godot
	# registers autoload globals, so the bare identifier fails with "Identifier not
	# found" even though the autoload node exists at runtime. Fetch it dynamically.
	_net = root.get_node("NetworkManager")

	var args := OS.get_cmdline_user_args()
	_role = args[0] if args.size() > 0 else ""

	_net.registry_changed.connect(_on_registry_changed)

func _on_registry_changed() -> void:
	print("SMOKE %s registry: %s" % [_role, JSON.stringify(_net.registry.to_dict())])

func _process(delta: float) -> bool:
	if not _started:
		# Node isn't fully inside the tree (multiplayer API unavailable) until the
		# first process tick, even though it's already a child of root — so the
		# actual host/join call is deferred here rather than done in _initialize().
		_started = true
		if _role == "host":
			_net.host_enet()
		elif _role == "join":
			_net.join_enet("127.0.0.1")
		else:
			push_error("net_smoke: expected 'host' or 'join' arg, got '%s'" % _role)

	_elapsed += delta
	return _elapsed >= 4.0  # returning true tells SceneTree to quit
