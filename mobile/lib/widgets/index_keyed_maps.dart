/// Shifts the keys of an index-keyed [map] down by one for every index after
/// [removedIndex], to follow the removal of that index from a list.
void shiftIndexKeysAfter<V>(Map<int, V> map, int removedIndex) {
  final shifted = {
    for (final entry in map.entries)
      entry.key > removedIndex ? entry.key - 1 : entry.key: entry.value,
  };
  map
    ..clear()
    ..addAll(shifted);
}
