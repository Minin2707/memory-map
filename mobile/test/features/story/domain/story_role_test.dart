import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/domain/story_role.dart';

void main() {
  group('StoryRole', () {
    test('shouldExposeBackendRoleVariants', () {
      expect(
        StoryRole.values,
        [
          StoryRole.owner,
          StoryRole.coOwner,
          StoryRole.editor,
          StoryRole.viewer,
        ],
      );
    });

    test('shouldAllowOnlyOwnerAndCoOwnerToUpdateStoryMetadataInUi', () {
      expect(StoryRole.owner.canUpdateStoryMetadata, isTrue);
      expect(StoryRole.coOwner.canUpdateStoryMetadata, isTrue);
      expect(StoryRole.editor.canUpdateStoryMetadata, isFalse);
      expect(StoryRole.viewer.canUpdateStoryMetadata, isFalse);
    });
  });
}
