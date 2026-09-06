enum StoryRole {
  owner,
  coOwner,
  editor,
  viewer,
}

extension StoryRoleCapabilities on StoryRole {
  bool get canUpdateStoryMetadata {
    return this == StoryRole.owner || this == StoryRole.coOwner;
  }

  bool get canDeleteStory {
    return this == StoryRole.owner;
  }
}
