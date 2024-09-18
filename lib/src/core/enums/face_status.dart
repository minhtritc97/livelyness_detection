enum FaceStatus {
  near('Quá gần'),
  far('Quá xa'),
  normal('Giữ nguyên khoảng cách'),
  inProgress('Đang xử lý...'),
  unknown(''),
  ;

  const FaceStatus(this.text);
  final String text;
}
