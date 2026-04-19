enum MediaType {
  movie,
  tv,
  book,
  game;
}

enum UnifiedStatus {
  wishlist,
  inProgress,
  done,
  onHold,
  dropped;
}

enum ActivityEvent {
  added,
  statusChanged,
  scoreChanged,
  progressChanged,
  noteEdited,
  completed;
}
