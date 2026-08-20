/// Public entrypoint for the `fabric_flutter` package.
///
/// Importing `package:fabric_flutter/fabric_flutter.dart` gives access to the
/// package's components, helpers, state containers, and serialized models
/// without deep path imports. Deep imports keep working, so this entrypoint is
/// purely additive for existing consumers.
library;

// Globals
export 'variables.dart';

// Components
export 'component/alert_data.dart';
export 'component/breadcrumbs.dart';
export 'component/card_button.dart';
export 'component/connection_status.dart';
export 'component/content_container.dart';
export 'component/country_picker.dart';
export 'component/drop_region.dart';
export 'component/edit_save_button.dart';
export 'component/expansion_table.dart';
export 'component/filter_menu.dart';
export 'component/flag_chip.dart';
export 'component/google_chart.dart';
export 'component/google_chart_container.dart';
export 'component/google_maps_preview.dart';
export 'component/google_maps_search.dart';
export 'component/iframe_minimal.dart';
export 'component/init_app.dart';
export 'component/input_data.dart';
export 'component/json_explorer_search.dart';
export 'component/language_picker.dart';
export 'component/live_announcer.dart';
export 'component/logs_list.dart';
export 'component/managed_drop_zone.dart';
export 'component/pagination_container.dart';
export 'component/pagination_nav.dart';
export 'component/phone_input.dart';
export 'component/popup_entry.dart';
export 'component/profile_edit.dart';
export 'component/route_page.dart';
export 'component/screen_context.dart';
export 'component/section_title.dart';
export 'component/smart_button.dart';
export 'component/smart_image.dart';
export 'component/status_chip.dart';
export 'component/stepper_extended.dart';
export 'component/tabs.dart';
export 'component/update_password.dart';
export 'component/upload_image_media.dart';
export 'component/user_add_update.dart';
export 'component/user_admin.dart';
export 'component/user_avatar.dart';
export 'component/user_chip.dart';
export 'component/users_dropdown.dart';
export 'component/voice_dictation_button.dart';

// Helpers
export 'helper/app_global.dart';
export 'helper/app_localizations_delegate.dart';
export 'helper/auth_service.dart';
export 'helper/byte_count_transformer.dart';
export 'helper/drop_file_format.dart';
export 'helper/enum_data.dart';
export 'helper/filter_helper.dart';
export 'helper/firebase_storage_helper.dart';
export 'helper/firestore_helper.dart';
export 'helper/format_data.dart';
export 'helper/gsm.dart';
export 'helper/http_request.dart';
export 'helper/input_validation.dart';
export 'helper/iso_countries.dart';
export 'helper/iso_language.dart';
export 'helper/jwt.dart';
export 'helper/log_color.dart';
export 'helper/media_helper.dart';
export 'helper/options.dart';
export 'helper/provider_helper.dart';
export 'helper/redirect_app.dart';
export 'helper/regex_helper.dart';
export 'helper/route_helper.dart';
export 'helper/serialization_error.dart';
export 'helper/user_roles.dart';
export 'helper/user_roles_firebase.dart';
export 'helper/utils.dart';

// Placeholders
export 'placeholder/default_locales.dart';
export 'placeholder/loading_screen.dart';

// Serialized models
export 'serialized/base_db.dart';
export 'serialized/chart_preferences.dart';
export 'serialized/chart_wrapper.dart';
export 'serialized/filter_data.dart';
export 'serialized/gsm_data.dart';
export 'serialized/iso_data.dart';
export 'serialized/logs_data.dart';
export 'serialized/map_data.dart';
export 'serialized/media_data.dart';
export 'serialized/notification_data.dart';
export 'serialized/password_data.dart';
export 'serialized/place_data.dart';
export 'serialized/table_data.dart';
export 'serialized/user_data.dart';
export 'serialized/user_status.dart';

// State containers
export 'state/state_analytics.dart';
export 'state/state_api.dart';
export 'state/state_collection.dart';
export 'state/state_document.dart';
export 'state/state_drop_zone.dart';
export 'state/state_global.dart';
export 'state/state_notifications.dart';
export 'state/state_shared.dart';
export 'state/state_user.dart';
// `db` is a top-level Firestore instance declared in both state_user.dart and
// state_users.dart. It is an implementation detail, so the duplicate is hidden
// here to keep the barrel unambiguous. Deep imports are unaffected.
export 'state/state_users.dart' hide db;
export 'state/state_view_auth.dart';

// Views
export 'view/view_auth_page.dart';
export 'view/view_featured.dart';
export 'view/view_hero.dart';
