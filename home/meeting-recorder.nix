{ lib, ... }:

{
  options.services.kaden.meetingRecorder.notionParentPageId = lib.mkOption {
    type = lib.types.nullOr lib.types.nonEmptyStr;
    default = null;
    example = "0123456789abcdef0123456789abcdef";
    description = "Notion page that receives uploaded AI meeting-note blocks.";
  };
}
