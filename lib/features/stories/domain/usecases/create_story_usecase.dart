import 'dart:io';

import '../entities/story.dart';
import '../repositories/story_repository.dart';

class CreateStoryUseCase {
  const CreateStoryUseCase(this._repository);

  final StoryRepository _repository;

  Future<String> call({required String creatorId, required File media, required StoryMediaType mediaType}) {
    return _repository.createStory(creatorId: creatorId, media: media, mediaType: mediaType);
  }
}
