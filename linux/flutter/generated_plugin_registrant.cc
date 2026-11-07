//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <audiotags/audiotags_plugin.h>
#include <fc_native_video_thumbnail/fc_native_video_thumbnail_plugin.h>
#include <flutter_media_metadata/flutter_media_metadata_plugin.h>
#include <media_kit_video/media_kit_video_plugin.h>
#include <url_launcher_linux/url_launcher_plugin.h>
#include <volume_controller/volume_controller_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) audiotags_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "AudiotagsPlugin");
  audiotags_plugin_register_with_registrar(audiotags_registrar);
  g_autoptr(FlPluginRegistrar) fc_native_video_thumbnail_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FcNativeVideoThumbnailPlugin");
  fc_native_video_thumbnail_plugin_register_with_registrar(fc_native_video_thumbnail_registrar);
  g_autoptr(FlPluginRegistrar) flutter_media_metadata_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FlutterMediaMetadataPlugin");
  flutter_media_metadata_plugin_register_with_registrar(flutter_media_metadata_registrar);
  g_autoptr(FlPluginRegistrar) media_kit_video_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "MediaKitVideoPlugin");
  media_kit_video_plugin_register_with_registrar(media_kit_video_registrar);
  g_autoptr(FlPluginRegistrar) url_launcher_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "UrlLauncherPlugin");
  url_launcher_plugin_register_with_registrar(url_launcher_linux_registrar);
  g_autoptr(FlPluginRegistrar) volume_controller_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "VolumeControllerPlugin");
  volume_controller_plugin_register_with_registrar(volume_controller_registrar);
}
