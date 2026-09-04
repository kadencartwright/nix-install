{ lib, ... }:

{
  options.services.kaden.meetingRecorder.notionDestinations = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            label = lib.mkOption {
              type = lib.types.nonEmptyStr;
              default = name;
              description = "Label displayed in the meeting recorder destination picker.";
            };
            parentPageId = lib.mkOption {
              type = lib.types.nonEmptyStr;
              example = "0123456789abcdef0123456789abcdef";
              description = "Notion parent page that receives this destination's meeting-note blocks.";
            };
          };
        }
      )
    );
    default = { };
    example = {
      team = {
        label = "Team meetings";
        parentPageId = "0123456789abcdef0123456789abcdef";
      };
      personal = {
        label = "Personal notes";
        parentPageId = "fedcba9876543210fedcba9876543210";
      };
    };
    description = "Named Notion parent pages offered when exporting a meeting recording.";
  };
}
