/// Một trang kết quả phân trang của DRF (`count` + `results`).
class PageResult<T> {
  const PageResult({required this.count, required this.items});

  final int count;
  final List<T> items;

  int pages(int pageSize) => count == 0 ? 1 : (count / pageSize).ceil();
}
