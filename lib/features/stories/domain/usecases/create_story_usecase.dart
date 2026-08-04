import 'dart:io';

import '../entities/story.dart';
import '../repositories/story_repository.dart';

/// Video-length validation (the 60s cap) happens in the presentation
/// layer right after the file is picked, via `video_player` — a
/// platform plugin, deliberately kept out of this pure-Dart domain
/// usecase. The only business rule enforced here is "a visibility
/// choice is required".
enum StoryFieldError { visibilityRequired }

class StoryValidationException implements Exception {
  final StoryFieldError error;
  const StoryValidationException(this.error);
}

class CreateStoryUseCase {
  const CreateStoryUseCase(this._repository);

  final StoryRepository _repository;

  Future<String> call({
    required String creatorId,
    required File media,
    required StoryMediaType mediaType,
    required StoryVisibility? visibility,
  }) {
    if (visibility == null) {
      throw const StoryValidationException(StoryFieldError.visibilityRequired);
    }
    return _repository.createStory(
      creatorId: creatorId,
      media: media,
      mediaType: mediaType,
      visibility: visibility,
    );
  }
}
