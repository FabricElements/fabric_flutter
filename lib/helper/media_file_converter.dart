/// Exports the platform-specific media file converter.
///
/// Some photo formats that a drop zone accepts on the platform gallery — most
/// notably Apple's HEIC/HEIF camera containers — are rejected by common upload
/// backends and by consumers that only understand web-standard image types. The
/// converter re-encodes those files to a universally supported format before
/// they are staged, so the rest of the pipeline never sees a container it
/// cannot store or use. On the web the browser's own image decoder performs
/// the conversion through a canvas; on native platforms the engine's platform
/// codec decodes the container and the conversion re-encodes it as JPEG. When
/// the platform decoder cannot decode the container, the conversion is
/// reported as unsupported. Consumers import this file and use
/// [MediaFileConverter] without branching on the platform themselves.
library;

export 'media_file_converter_native.dart'
    show MediaConversionResult, MediaFileConverter, mediaConversionTimeout;
export 'media_file_converter_native.dart'
    if (dart.library.js_interop) 'media_file_converter_web.dart'
    show MediaFileConverterImpl;
