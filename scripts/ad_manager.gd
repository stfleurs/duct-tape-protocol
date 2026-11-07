extends Node

## AdMob wrapper for Duct Tape Protocol.
##
## Rewarded ad   : DTP_Rewarded      (the "WATCH AD: 2X SCRAP" button on the results screen)
## Interstitial  : DTP_Interstitial  (only between shifts, every 3 finished shifts, never mid-game)
## App open ad   : DTP_AppOpen       (cold start / return to foreground, never mid-shift, max 1/4 h)
## Banner        : DTP_Banner        (menu only; disabled by default because it pays very little)
##
## The real SDK only exists in an Android build made with "Use Gradle Build" and the plugin in
## res://addons/admob. In the editor, on desktop and on Web this falls back to a short simulation so
## the game and its tests keep working. On Android, if the plugin is missing, ads are simply
## unavailable: the game never hands out a free reward for a missing ad.
##
## Before loading ads, the EU/UK/CH consent flow uses Google's User Messaging Platform (UMP). If the
## consent status cannot be obtained, no ads are requested.

signal ad_started(placement_id: String, is_dev_simulation: bool)
signal ad_completed(placement_id: String, reward_granted: bool, is_dev_simulation: bool)
## Emitted when the SDK is ready (or when consent says ads may not be requested).
signal ads_ready_changed(is_ready: bool)
signal consent_status_changed(can_request_ads: bool)

# --- AdMob console: Duct Tape Protocol ---------------------------------------------------------
const ADMOB_APP_ID: String = "ca-app-pub-7279753852255468~6806201948"
const REWARDED_UNIT_ID: String = "ca-app-pub-7279753852255468/8204090272" # DTP_Rewarded
const INTERSTITIAL_UNIT_ID: String = "ca-app-pub-7279753852255468/6891008607" # DTP_Interstitial
const APP_OPEN_UNIT_ID: String = "ca-app-pub-7279753852255468/6821504651" # DTP_AppOpen
const BANNER_UNIT_ID: String = "ca-app-pub-7279753852255468/9599886240" # DTP_Banner

# Google's official sample units, used in debug builds so nobody clicks a live ad while testing.
const TEST_REWARDED_UNIT_ID: String = "ca-app-pub-3940256099942544/5224354917"
const TEST_INTERSTITIAL_UNIT_ID: String = "ca-app-pub-3940256099942544/1033173712"
const TEST_APP_OPEN_UNIT_ID: String = "ca-app-pub-3940256099942544/9257395921"
const TEST_BANNER_UNIT_ID: String = "ca-app-pub-3940256099942544/9214589741"
const USE_TEST_ADS_IN_DEBUG: bool = true

# --- Product rules ------------------------------------------------------------------------------
## The banner was deliberately left off: it pays very little and the menu is already busy.
## Flip this to true only after moving the bottom menu row up (main_menu.gd reserves space when on).
const ENABLE_BANNER: bool = false
## Interstitial cadence: first one after 3 finished shifts, then at most once per 3 shifts...
const INTERSTITIAL_EVERY_N_SHIFTS: int = 3
## ...and never more often than this, even if the player retries a lot.
const INTERSTITIAL_MIN_GAP_SEC: int = 180
## App-open ads are shown at most once every 4 hours, never on the very first launch, and never
## during a shift. Any other full-screen ad also resets this gap.
const ENABLE_APP_OPEN: bool = true
const APP_OPEN_MIN_GAP_SEC: int = 4 * 60 * 60
## After an ad click we leave the app; do not greet the player with another ad on return.
const APP_OPEN_CLICK_SUPPRESS_SEC: int = 300
const APP_OPEN_RETRY_SEC: float = 60.0
const REWARDED_RETRY_SEC: float = 30.0
const INTERSTITIAL_RETRY_SEC: float = 60.0
const SDK_INIT_FALLBACK_SEC: float = 8.0
const CONSENT_FALLBACK_SEC: float = 6.0

## Desktop/editor/Web may simulate ads (tests, UI work). Android/iOS never simulate.
const ALLOW_DEV_SIMULATION: bool = true
## Consent debug tools (EEA form testing). Leave off for release builds.
const DEBUG_EEA_CONSENT: bool = false
const CONSENT_TEST_DEVICE_IDS: Array[String] = []

const ADS_STATE_PATH: String = "user://ads_state.json"

var state_path: String = ADS_STATE_PATH

var _is_dev_simulation: bool = false
var _native_available: bool = false
var _ads_ready: bool = false
var _can_request_ads: bool = false
var _consent_resolved: bool = false
var _sdk_init_requested: bool = false
var _ad_in_progress: bool = false

var _rewarded_ad: RewardedAd = null
var _rewarded_loading: bool = false
var _rewarded_retry_scheduled: bool = false
var _rewarded_placement: String = "results_double_scrap"
var _rewarded_granted: bool = false
var _rewarded_pending_reward: Callable = Callable()
var _rewarded_pending_cancel: Callable = Callable()
var _reward_listener: OnUserEarnedRewardListener = null
var _rewarded_content_callback: FullScreenContentCallback = null

var _interstitial_ad: InterstitialAd = null
var _interstitial_loading: bool = false
var _interstitial_retry_scheduled: bool = false
var _interstitial_pending_done: Callable = Callable()

var _app_open_ad: AppOpenAd = null
var _app_open_loading: bool = false
var _app_open_retry_scheduled: bool = false
var _app_open_show_requested: bool = false
var _app_open_launch_count: int = 0
var _suppress_app_open_until_unix: int = 0

var _banner_ad: AdView = null
var _banner_listener: AdListener = null
var _banner_wanted: bool = false

var _init_listener: OnInitializationCompleteListener = null
var _init_fallback_started: bool = false
var _consent_fallback_started: bool = false

var _shifts_since_interstitial: int = 0
var _last_full_screen_ad_unix: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_state()

	# Only a real Android build with the plugin enabled can show live ads.
	_native_available = Engine.has_singleton("PoingGodotAdMob")
	_is_dev_simulation = (
		ALLOW_DEV_SIMULATION
		and not _native_available
		and OS.get_name() != "Android"
		and OS.get_name() != "iOS"
	)

	if _native_available:
		# Count real launches only. The first launch never shows an app-open ad (store policy).
		_app_open_launch_count += 1
		_save_state()
		call_deferred("_initialize_native_ads")
	else:
		# Editor / desktop / Web: no consent popup, no SDK, just the local simulation.
		_ads_ready = true
		_can_request_ads = true
		_consent_resolved = true
		ads_ready_changed.emit(true)
		consent_status_changed.emit(true)

func _notification(what: int) -> void:
	# Android sends this when the player returns from the launcher, another app or an ad click.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_inside_tree():
		call_deferred("maybe_show_app_open")

func _exit_tree() -> void:
	_destroy_banner()
	_destroy_app_open()
	if _rewarded_ad != null:
		_rewarded_ad.destroy()
		_rewarded_ad = null
	if _interstitial_ad != null:
		_interstitial_ad.destroy()
		_interstitial_ad = null

# ------------------------------------------------------------------ public API

## True when the player can be offered an ad right now (or a dev simulation is allowed).
func is_ad_available(_placement_id: String = "results_double_scrap") -> bool:
	if _ad_in_progress:
		return false
	return is_ads_ready()

func is_ads_ready() -> bool:
	if _is_dev_simulation:
		return true
	return _native_available and _ads_ready and _can_request_ads

func is_dev_simulation() -> bool:
	return _is_dev_simulation

func is_banner_enabled() -> bool:
	return ENABLE_BANNER

## The results screen uses this instead of a hard-coded "[DEV SIM]" label.
func rewarded_button_text(base_text: String) -> String:
	if _is_dev_simulation:
		return "%s [DEV SIM]" % base_text
	return base_text

## Rewarded ad. on_reward_granted fires only when Google says the reward was earned.
## on_ad_cancelled fires when the player closed early, the ad failed, or ads are unavailable.
func request_rewarded_ad(
	placement_id: String,
	on_reward_granted: Callable,
	on_ad_cancelled: Callable = Callable(),
	simulation_duration_sec: float = 1.2
) -> void:
	if _ad_in_progress:
		_cancel_callable(on_ad_cancelled)
		return

	_ad_in_progress = true
	_rewarded_granted = false
	_rewarded_placement = placement_id
	_rewarded_pending_reward = on_reward_granted
	_rewarded_pending_cancel = on_ad_cancelled
	ad_started.emit(placement_id, _is_dev_simulation)

	if _is_dev_simulation:
		if simulation_duration_sec <= 0.0 or not is_inside_tree():
			_complete_simulated_reward()
		else:
			var timer := get_tree().create_timer(simulation_duration_sec)
			timer.timeout.connect(_complete_simulated_reward, CONNECT_ONE_SHOT)
		return

	if not _native_available or not _ads_ready or not _can_request_ads:
		push_warning("AdManager: rewarded ad requested before ads were ready.")
		_finish_rewarded(false)
		return

	if _rewarded_ad != null:
		_show_rewarded()
	else:
		_load_rewarded(true)

## Natural-break interstitial. on_done() always runs (immediately when no ad is shown), so callers
## can safely navigate after it. Never call this during a shift.
func show_interstitial_then(on_done: Callable) -> void:
	if not _should_show_interstitial():
		on_done.call_deferred()
		return

	if _interstitial_ad == null:
		_load_interstitial()
		on_done.call_deferred()
		return

	_interstitial_pending_done = on_done
	_ad_in_progress = true
	_note_full_screen_ad_shown()
	ad_started.emit("between_shifts", false)
	_interstitial_ad.show()

## Count one finished shift and persist the cadence across launches.
func note_shift_finished() -> void:
	_shifts_since_interstitial += 1
	_save_state()

func is_app_open_enabled() -> bool:
	return ENABLE_APP_OPEN

## Called when the menu is ready and when the app returns to the foreground. The actual decision is
## deferred until consent/SDK are ready so a cold start can still show the app-open ad.
func maybe_show_app_open() -> void:
	if not ENABLE_APP_OPEN:
		return
	if _is_dev_simulation or not _native_available:
		return
	_app_open_show_requested = true
	_try_show_app_open()

## Pure policy helper (also used by the tests). `launch_count` is 1 on the very first launch.
static func app_open_due(
	seconds_since_last_full_screen_ad: int, in_active_shift: bool, launch_count: int
) -> bool:
	if in_active_shift or launch_count <= 1:
		return false
	return seconds_since_last_full_screen_ad >= APP_OPEN_MIN_GAP_SEC

func _try_show_app_open() -> void:
	if not _app_open_show_requested:
		return
	if (
		not ENABLE_APP_OPEN
		or _is_dev_simulation
		or not _native_available
		or not _ads_ready
		or not _can_request_ads
	):
		return
	if _ad_in_progress:
		return
	if not _in_safe_app_open_scene():
		_app_open_show_requested = false
		return

	var now := int(Time.get_unix_time_from_system())
	var in_shift: bool = GameManager.is_in_active_shift
	if not app_open_due(now - _last_full_screen_ad_unix, in_shift, _app_open_launch_count):
		_app_open_show_requested = false
		return
	if now < _suppress_app_open_until_unix:
		_app_open_show_requested = false
		return

	if _app_open_ad == null:
		_load_app_open()
		return
	_show_app_open()

## Pure policy helper (also used by the tests).
static func interstitial_due(
	shifts_since_last: int, seconds_since_last: int, in_active_shift: bool
) -> bool:
	if in_active_shift:
		return false
	if shifts_since_last < INTERSTITIAL_EVERY_N_SHIFTS:
		return false
	return seconds_since_last >= INTERSTITIAL_MIN_GAP_SEC

## GDPR/CCPA "Privacy options" entry point, shown in Settings only when UMP says it is required.
func has_privacy_options() -> bool:
	if _is_dev_simulation or not _native_available:
		return false
	return (
		UserMessagingPlatform.consent_information.get_privacy_options_requirement_status()
		== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
	)

func show_privacy_options() -> void:
	if _is_dev_simulation or not _native_available:
		return
	UserMessagingPlatform.show_privacy_options_form(_on_privacy_options_dismissed)

## Move the menu banner in/out. No-op unless ENABLE_BANNER is true and Android ads are ready.
func show_banner() -> void:
	_banner_wanted = true
	_show_banner_if_ready()

func hide_banner() -> void:
	_banner_wanted = false
	_destroy_banner()

# ------------------------------------------------------------------ consent + SDK init

func _initialize_native_ads() -> void:
	# Ask UMP for the latest consent state on every launch, before any ad request.
	var params := ConsentRequestParameters.new()
	if DEBUG_EEA_CONSENT && OS.is_debug_build():
		var debug_settings := ConsentDebugSettings.new()
		debug_settings.debug_geography = DebugGeography.Values.EEA
		for device_id in CONSENT_TEST_DEVICE_IDS:
			debug_settings.test_device_hashed_ids.append(device_id)
		params.consent_debug_settings = debug_settings

	_start_consent_fallback_timer()
	UserMessagingPlatform.consent_information.update(
		params, _on_consent_updated, _on_consent_update_failed
	)

func _on_consent_updated() -> void:
	_consent_resolved = true
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(
			_on_consent_form_loaded, _on_consent_form_load_failed
		)
	else:
		_on_consent_flow_finished()

func _on_consent_update_failed(error: FormError) -> void:
	_consent_resolved = true
	push_warning(
		"AdManager: consent update failed (%d): %s" % [error.error_code, error.message]
	)
	# UMP can still have a valid status from a previous session; _on_consent_flow_finished checks it.
	_on_consent_flow_finished()

func _on_consent_form_loaded(form: ConsentForm) -> void:
	var status: int = UserMessagingPlatform.consent_information.get_consent_status()
	if status == ConsentInformation.ConsentStatus.REQUIRED:
		form.show(_on_consent_form_dismissed)
	else:
		_on_consent_flow_finished()

func _on_consent_form_load_failed(error: FormError) -> void:
	push_warning(
		"AdManager: consent form failed to load (%d): %s" % [error.error_code, error.message]
	)
	_on_consent_flow_finished()

func _on_consent_form_dismissed(error: FormError) -> void:
	if error != null:
		push_warning("AdManager: consent form dismissed with an error: " + error.message)
	_on_consent_flow_finished()

func _on_privacy_options_dismissed(error: FormError) -> void:
	if error != null:
		push_warning("AdManager: privacy options dismissed with an error: " + error.message)
	_on_consent_flow_finished()

func _on_consent_flow_finished() -> void:
	var status: int = UserMessagingPlatform.consent_information.get_consent_status()
	var allowed: bool = (
		status == ConsentInformation.ConsentStatus.OBTAINED
		or status == ConsentInformation.ConsentStatus.NOT_REQUIRED
	)
	if allowed != _can_request_ads:
		_can_request_ads = allowed
		consent_status_changed.emit(allowed)
		if not allowed:
			# Consent was withdrawn/changed: stop showing ads immediately.
			_destroy_banner()
			_destroy_app_open()
			_app_open_show_requested = false
			_ads_ready = false
			ads_ready_changed.emit(false)

	if _can_request_ads:
		_init_sdk()
	else:
		push_warning("AdManager: ads are paused until consent is obtained.")

func _start_consent_fallback_timer() -> void:
	if _consent_fallback_started or not is_inside_tree():
		return
	_consent_fallback_started = true
	var timer := get_tree().create_timer(CONSENT_FALLBACK_SEC)
	timer.timeout.connect(func() -> void:
		if not _consent_resolved:
			push_warning("AdManager: consent flow timed out; ads stay off this session.")
			_consent_resolved = true
			_on_consent_flow_finished()
	)

func _init_sdk() -> void:
	if _sdk_init_requested:
		return
	_sdk_init_requested = true
	_init_listener = OnInitializationCompleteListener.new()
	_init_listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		_on_sdk_initialized()
	MobileAds.initialize(_init_listener)
	_start_sdk_init_fallback_timer()

func _start_sdk_init_fallback_timer() -> void:
	if _init_fallback_started or not is_inside_tree():
		return
	_init_fallback_started = true
	var timer := get_tree().create_timer(SDK_INIT_FALLBACK_SEC)
	timer.timeout.connect(func() -> void:
		if not _ads_ready:
			push_warning("AdManager: SDK init callback timed out; trying to preload anyway.")
			_on_sdk_initialized()
	)

func _on_sdk_initialized() -> void:
	if _ads_ready:
		return
	_ads_ready = true
	ads_ready_changed.emit(true)
	_load_rewarded()
	_load_interstitial()
	_load_app_open()
	_show_banner_if_ready()
	if _app_open_show_requested:
		_try_show_app_open()

# ------------------------------------------------------------------ rewarded

func _load_rewarded(for_show: bool = false) -> void:
	if _rewarded_ad != null:
		if for_show and _ad_in_progress:
			_show_rewarded()
		return
	if _rewarded_loading or not _ads_ready:
		return

	_rewarded_loading = true
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		_rewarded_loading = false
		_rewarded_ad = ad
		if _ad_in_progress:
			_show_rewarded()
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_rewarded_loading = false
		push_warning("AdManager: rewarded ad failed to load: " + error.message)
		if _ad_in_progress:
			_finish_rewarded(false)
		else:
			_schedule_rewarded_retry()
	RewardedAdLoader.new().load(_unit_id(REWARDED_UNIT_ID, TEST_REWARDED_UNIT_ID), AdRequest.new(), callback)

func _show_rewarded() -> void:
	if _rewarded_ad == null:
		_finish_rewarded(false)
		return

	_note_full_screen_ad_shown()
	_reward_listener = OnUserEarnedRewardListener.new()
	_reward_listener.on_user_earned_reward = _on_user_earned_reward

	_rewarded_content_callback = FullScreenContentCallback.new()
	_rewarded_content_callback.on_ad_clicked = _suppress_app_open_after_click
	_rewarded_content_callback.on_ad_dismissed_full_screen_content = _on_rewarded_dismissed
	_rewarded_content_callback.on_ad_failed_to_show_full_screen_content = (
		func(error: AdError) -> void:
			push_warning("AdManager: rewarded ad failed to show: " + error.message)
			_finish_rewarded(false)
	)
	_rewarded_ad.full_screen_content_callback = _rewarded_content_callback
	_rewarded_ad.show(_reward_listener)

func _on_user_earned_reward(_item: RewardedItem) -> void:
	if _rewarded_granted:
		return
	_rewarded_granted = true
	var reward := _rewarded_pending_reward
	_rewarded_pending_reward = Callable()
	if reward.is_valid():
		reward.call()

func _on_rewarded_dismissed() -> void:
	_finish_rewarded(_rewarded_granted)

func _complete_simulated_reward() -> void:
	_rewarded_granted = true
	var reward := _rewarded_pending_reward
	_rewarded_pending_reward = Callable()
	if reward.is_valid():
		reward.call()
	_finish_rewarded(true)

func _finish_rewarded(granted: bool) -> void:
	var cancel := _rewarded_pending_cancel
	_rewarded_pending_cancel = Callable()
	_rewarded_pending_reward = Callable()
	_ad_in_progress = false

	if _rewarded_ad != null:
		_rewarded_ad.destroy()
		_rewarded_ad = null
	_rewarded_content_callback = null
	_reward_listener = null
	_rewarded_loading = false

	ad_completed.emit(_rewarded_placement, granted, _is_dev_simulation)
	if not granted:
		_cancel_callable(cancel)
	if not _is_dev_simulation and _ads_ready:
		_load_rewarded()

func _schedule_rewarded_retry() -> void:
	if _rewarded_retry_scheduled or not is_inside_tree():
		return
	_rewarded_retry_scheduled = true
	var timer := get_tree().create_timer(REWARDED_RETRY_SEC)
	timer.timeout.connect(func() -> void:
		_rewarded_retry_scheduled = false
		_load_rewarded()
	)

# ------------------------------------------------------------------ interstitial

func _should_show_interstitial() -> bool:
	if _is_dev_simulation or not _native_available or not _ads_ready or not _can_request_ads:
		return false
	if _ad_in_progress or GameManager.is_in_active_shift:
		return false
	var seconds_since := int(Time.get_unix_time_from_system()) - _last_full_screen_ad_unix
	return interstitial_due(_shifts_since_interstitial, seconds_since, false)

func _load_interstitial() -> void:
	if _interstitial_ad != null or _interstitial_loading or not _ads_ready:
		return
	_interstitial_loading = true
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial_loading = false
		_interstitial_ad = ad
		_attach_interstitial_callbacks(ad)
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_interstitial_loading = false
		push_warning("AdManager: interstitial failed to load: " + error.message)
		_schedule_interstitial_retry()
	InterstitialAdLoader.new().load(
		_unit_id(INTERSTITIAL_UNIT_ID, TEST_INTERSTITIAL_UNIT_ID), AdRequest.new(), callback
	)

func _attach_interstitial_callbacks(ad: InterstitialAd) -> void:
	var callbacks := FullScreenContentCallback.new()
	callbacks.on_ad_clicked = _suppress_app_open_after_click
	callbacks.on_ad_dismissed_full_screen_content = _on_interstitial_dismissed
	callbacks.on_ad_failed_to_show_full_screen_content = (
		func(error: AdError) -> void:
			push_warning("AdManager: interstitial failed to show: " + error.message)
			_finish_interstitial()
	)
	ad.full_screen_content_callback = callbacks

func _on_interstitial_dismissed() -> void:
	_last_full_screen_ad_unix = int(Time.get_unix_time_from_system())
	_shifts_since_interstitial = 0
	_save_state()
	_finish_interstitial()

func _finish_interstitial() -> void:
	_ad_in_progress = false
	if _interstitial_ad != null:
		_interstitial_ad.destroy()
		_interstitial_ad = null
	ad_completed.emit("between_shifts", false, false)

	var done := _interstitial_pending_done
	_interstitial_pending_done = Callable()
	if done.is_valid():
		done.call_deferred()

	if not _is_dev_simulation and _ads_ready:
		_load_interstitial()

func _schedule_interstitial_retry() -> void:
	if _interstitial_retry_scheduled or not is_inside_tree():
		return
	_interstitial_retry_scheduled = true
	var timer := get_tree().create_timer(INTERSTITIAL_RETRY_SEC)
	timer.timeout.connect(func() -> void:
		_interstitial_retry_scheduled = false
		_load_interstitial()
	)

func _in_safe_app_open_scene() -> bool:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene == null:
		return false
	var path: String = scene.scene_file_path
	return path != GameManager.SCENE_GAMEPLAY and path != GameManager.SCENE_RESULTS

# ------------------------------------------------------------------ app open

func _load_app_open() -> void:
	if not ENABLE_APP_OPEN or _app_open_ad != null or _app_open_loading or not _ads_ready:
		return
	_app_open_loading = true
	var callback := AppOpenAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: AppOpenAd) -> void:
		_app_open_loading = false
		if not _ads_ready or not _can_request_ads:
			ad.destroy()
			return
		_app_open_ad = ad
		_attach_app_open_callbacks(ad)
		if _app_open_show_requested:
			_try_show_app_open()
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_app_open_loading = false
		push_warning("AdManager: app-open ad failed to load: " + error.message)
		_app_open_show_requested = false
		_schedule_app_open_retry()
	AppOpenAdLoader.new().load(
		_unit_id(APP_OPEN_UNIT_ID, TEST_APP_OPEN_UNIT_ID), AdRequest.new(), callback
	)

func _attach_app_open_callbacks(ad: AppOpenAd) -> void:
	var callbacks := FullScreenContentCallback.new()
	callbacks.on_ad_clicked = _suppress_app_open_after_click
	callbacks.on_ad_dismissed_full_screen_content = _on_app_open_dismissed
	callbacks.on_ad_failed_to_show_full_screen_content = (
		func(error: AdError) -> void:
			push_warning("AdManager: app-open ad failed to show: " + error.message)
			_finish_app_open()
	)
	ad.full_screen_content_callback = callbacks

func _show_app_open() -> void:
	if _app_open_ad == null:
		_app_open_show_requested = false
		return
	_app_open_show_requested = false
	_ad_in_progress = true
	_note_full_screen_ad_shown()
	ad_started.emit("app_open", false)
	_app_open_ad.show()

func _on_app_open_dismissed() -> void:
	_finish_app_open()

func _finish_app_open() -> void:
	_ad_in_progress = false
	_destroy_app_open()
	ad_completed.emit("app_open", false, false)
	if not _is_dev_simulation and _ads_ready:
		_load_app_open()

func _destroy_app_open() -> void:
	if _app_open_ad != null:
		_app_open_ad.destroy()
		_app_open_ad = null
	_app_open_loading = false

func _schedule_app_open_retry() -> void:
	if _app_open_retry_scheduled or not is_inside_tree():
		return
	_app_open_retry_scheduled = true
	var timer := get_tree().create_timer(APP_OPEN_RETRY_SEC)
	timer.timeout.connect(func() -> void:
		_app_open_retry_scheduled = false
		_load_app_open()
	)

func _note_full_screen_ad_shown() -> void:
	_last_full_screen_ad_unix = int(Time.get_unix_time_from_system())
	_save_state()

func _suppress_app_open_after_click() -> void:
	_suppress_app_open_until_unix = (
		int(Time.get_unix_time_from_system()) + APP_OPEN_CLICK_SUPPRESS_SEC
	)

# ------------------------------------------------------------------ banner

func _show_banner_if_ready() -> void:
	if not ENABLE_BANNER or not _banner_wanted:
		return
	if _is_dev_simulation or not _native_available or not _ads_ready or not _can_request_ads:
		return
	if _banner_ad != null:
		_banner_ad.show()
		return

	var ad_size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	if ad_size == null or ad_size.width <= 0 or ad_size.height <= 0:
		ad_size = AdSize.BANNER

	_banner_ad = AdView.new(
		_unit_id(BANNER_UNIT_ID, TEST_BANNER_UNIT_ID), ad_size, AdPosition.BOTTOM
	)
	_banner_listener = AdListener.new()
	_banner_listener.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		push_warning("AdManager: banner failed to load: " + error.message)
		_destroy_banner()
	_banner_ad.ad_listener = _banner_listener
	_banner_ad.load_ad(AdRequest.new())

func _destroy_banner() -> void:
	if _banner_ad != null:
		_banner_ad.destroy()
		_banner_ad = null
	_banner_listener = null

# ------------------------------------------------------------------ helpers

func _unit_id(release_id: String, test_id: String) -> String:
	if USE_TEST_ADS_IN_DEBUG and OS.is_debug_build():
		return test_id
	return release_id

func _cancel_callable(callback: Callable) -> void:
	if callback.is_valid():
		callback.call_deferred()

func _load_state() -> void:
	if not FileAccess.file_exists(state_path):
		return
	var file := FileAccess.open(state_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_shifts_since_interstitial = maxi(0, int(parsed.get("shifts_since_interstitial", 0)))
	_last_full_screen_ad_unix = maxi(
		0,
		int(parsed.get("last_full_screen_ad_unix", parsed.get("last_interstitial_unix", 0)))
	)
	_app_open_launch_count = maxi(0, int(parsed.get("app_open_launch_count", 0)))

func _save_state() -> void:
	var file := FileAccess.open(state_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"shifts_since_interstitial": _shifts_since_interstitial,
		"last_full_screen_ad_unix": _last_full_screen_ad_unix,
		"app_open_launch_count": _app_open_launch_count
	}))
	file.close()

## Tests / debug only: put the cadence back to a fresh install.
func reset_cadence(persist: bool = true) -> void:
	_shifts_since_interstitial = 0
	_last_full_screen_ad_unix = 0
	if persist:
		_save_state()

func get_shifts_since_interstitial() -> int:
	return _shifts_since_interstitial

func get_last_full_screen_ad_unix() -> int:
	return _last_full_screen_ad_unix

func get_app_open_launch_count() -> int:
	return _app_open_launch_count
